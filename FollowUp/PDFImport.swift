import Foundation
import PDFKit
import Vision
import UIKit
import SwiftUI

struct PDFImportResult {
    var entries: [Knowledge]
    var pageCount: Int
    var ocrPages: Int
    var skippedPages: [Int]
}

enum PDFText {
    static func entries(text: String, document: String, page: Int, ocr: Bool) -> [Knowledge] {
        let source = "\(document) · 第 \(page) 页" + (ocr ? " · OCR，请核对" : "")
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let questionPattern = "^(?:问题\\s*[:：]|问\\s*[:：]|[Qq]\\s*\\d*\\s*[:：])\\s*(.+)$"
        let answerPattern = "^(?:回答|答案|答|[Aa]\\s*\\d*)\\s*[:：]\\s*"
        let regex = try! NSRegularExpression(pattern: questionPattern)
        var question = "", answer: [String] = [], items: [Knowledge] = []
        func flush() {
            let body = answer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !question.isEmpty && !body.isEmpty {
                items.append(Knowledge(question: question, answer: body, tags: "PDF导入", source: source))
            }
        }
        for line in lines {
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)), let range = Range(match.range(at: 1), in: line) {
                flush(); question = String(line[range]); answer = []
            } else if !question.isEmpty {
                answer.append(line.replacingOccurrences(of: answerPattern, with: "", options: .regularExpression))
            }
        }
        flush()
        if !items.isEmpty { return items }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return [] }
        return [Knowledge(question: "\(document) · 第 \(page) 页资料", answer: body, tags: "PDF资料原文", source: source)]
    }
}

enum PDFImport {
    static func extract(data: Data, name: String, progress: @Sendable (Int, Int) -> Void = { _, _ in }) throws -> PDFImportResult {
        guard let document = PDFDocument(data: data) else { throw DataError.invalid("无法读取 PDF，文件可能已损坏") }
        guard !document.isLocked else { throw DataError.invalid("PDF 已加密，请先解除密码后导入") }
        guard document.pageCount > 0 && document.pageCount <= 100 else { throw DataError.invalid("请导入 1–100 页的 PDF；较长资料请先拆分") }
        var result = PDFImportResult(entries: [], pageCount: document.pageCount, ocrPages: 0, skippedPages: [])
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            progress(index + 1, document.pageCount)
            let parsed: (text: String, ocr: Bool) = try autoreleasepool {
                guard let page = document.page(at: index) else { return ("", false) }
                let embedded = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if embedded.count >= 10 { return (embedded, false) }
                let bounds = page.bounds(for: .mediaBox)
                guard bounds.width > 0 && bounds.height > 0 else { return (embedded, false) }
                let scale = 2000 / max(bounds.width, bounds.height)
                let image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                guard let cgImage = image.cgImage else { return (embedded, false) }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                let supported = try request.supportedRecognitionLanguages()
                let languages = ["zh-Hans", "zh-Hant", "en-US"].filter { supported.contains($0) }
                if !languages.isEmpty { request.recognitionLanguages = languages }
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                return (recognized.isEmpty ? embedded : recognized, true)
            }
            if parsed.ocr { result.ocrPages += 1 }
            let items = PDFText.entries(text: parsed.text, document: name, page: index + 1, ocr: parsed.ocr)
            if items.isEmpty { result.skippedPages.append(index + 1) }
            result.entries.append(contentsOf: items)
        }
        guard !result.entries.isEmpty else { throw DataError.invalid("未识别出文字。请提供清晰的 PDF，或改用手动录入。") }
        return result
    }
}

@MainActor
final class PDFImportSession: ObservableObject {
    @Published var processing = false
    @Published var progress = ""
    @Published var result: PDFImportResult?
    @Published var error: String?
    private var worker: Task<PDFImportResult, Error>?
    private var generation = UUID()

    func start(url: URL) {
        start(name: url.deletingPathExtension().lastPathComponent) {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var contents: Result<Data, Error>?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
                contents = Result {
                    let size = try coordinatedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 20_000_000 else { throw DataError.invalid("文件过大，请拆分为 20 MB 以内的文件") }
                    let data = try Data(contentsOf: coordinatedURL)
                    guard data.count <= 20_000_000 else { throw DataError.invalid("文件过大，请拆分为 20 MB 以内的文件") }
                    return data
                }
            }
            if let coordinationError { throw coordinationError }
            guard let contents else { throw DataError.invalid("未能读取文件，请重新选择 PDF") }
            return try contents.get()
        }
    }

    func start(data: Data, name: String) { start(name: name) { data } }

    private func start(name: String, load: @escaping @Sendable () throws -> Data) {
        cancel()
        let ticket = UUID(); generation = ticket
        result = nil; error = nil; processing = true; progress = "正在读取 PDF…"
        let report: @Sendable (Int, Int) -> Void = { [weak self] page, total in
            Task { @MainActor [weak self] in
                guard self?.generation == ticket else { return }
                self?.progress = "正在处理第 \(page) / \(total) 页"
            }
        }
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let data = try load()
            try Task.checkCancellation()
            return try PDFImport.extract(data: data, name: name, progress: report)
        }
        self.worker = worker
        Task {
            do {
                let imported = try await worker.value
                guard generation == ticket else { return }
                result = imported; processing = false; self.worker = nil
            } catch {
                guard generation == ticket else { return }
                processing = false; self.worker = nil
                if !(error is CancellationError) { self.error = error.localizedDescription }
            }
        }
    }

    func cancel() { generation = UUID(); worker?.cancel(); worker = nil; processing = false }
}

struct ImportReview: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var entries: [Knowledge]
    let summary: String
    @State private var selected = Set<UUID>()
    @State private var initialized = false
    @State private var editing: Knowledge?
    @State private var error: String?
    var invalid: Bool {
        entries.filter { selected.contains($0.id) }.contains {
            $0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(summary).font(.subheadline)
                    Text("已选 \(selected.count) / \(entries.count) 条。相同类型、问题及产品的记录跳过；已有内容保留。")
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack {
                        Button("全选") { selected = Set(entries.map(\.id)) }
                        Spacer()
                        Button("全不选") { selected = [] }
                    }.buttonStyle(.borderless)
                }
                ForEach(entries) { entry in
                    Section {
                        Toggle(isOn: Binding(get: { selected.contains(entry.id) }, set: { if $0 { selected.insert(entry.id) } else { selected.remove(entry.id) } })) {
                            Text(entry.question).font(.headline)
                        }
                        Text(entry.answer).font(.subheadline).lineLimit(5)
                        Text(entry.source).font(.caption).foregroundStyle(.secondary)
                        Button("查看全文 / 编辑") { editing = entry }
                    }
                }
            }
            .navigationTitle("导入预览")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        if store.importEntries(entries.filter { selected.contains($0.id) }) { dismiss() }
                        else { error = store.error; store.error = nil }
                    }.disabled(selected.isEmpty || invalid)
                }
            }
            .onAppear { if !initialized { selected = Set(entries.map(\.id)); initialized = true } }
            .sheet(item: $editing) { draft in
                ImportEntryEditor(entry: draft) { revised in
                    if let index = entries.firstIndex(where: { $0.id == revised.id }) { entries[index] = revised }
                }
            }
            .alert("导入失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

struct ImportEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: Knowledge
    let onSave: (Knowledge) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $entry.kind) { Text("问答").tag("问答"); Text("话术").tag("话术") }
                TextField("问题 / 资料标题", text: $entry.question, axis: .vertical)
                TextField("相似问法", text: $entry.aliases, axis: .vertical)
                Section("回答 / 原文") { TextEditor(text: $entry.answer).frame(minHeight: 260) }
                TextField("关联产品", text: $entry.product)
                TextField("标签", text: $entry.tags)
                TextField("来源", text: $entry.source)
            }
            .navigationTitle("核对导入内容")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { entry.updatedAt = Date(); onSave(entry); dismiss() }
                        .disabled(entry.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || entry.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
