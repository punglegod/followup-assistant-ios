import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum ImportMode { case csv, pdf, backup }

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @StateObject private var pdf = PDFImportSession()
    @State private var importing = false
    @State private var mode = ImportMode.csv
    @State private var exporting = false
    @State private var exportType = UTType.json
    @State private var exportName = "回访备份"
    @State private var document = ExportDocument(data: Data())
    @State private var pendingEntries: [Knowledge] = []
    @State private var pendingArchive: Archive?
    @State private var preview = false
    @State private var summary = ""
    @State private var restoreConfirm = false
    @State private var message: String?
    @State private var cycles = false
    var types: [UTType] {
        switch mode { case .csv: return [.commaSeparatedText, .plainText]; case .pdf: return [.pdf]; case .backup: return [.json] }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("回访设置") {
                    LabeledContent("默认周期", value: store.archive.preferences.followUpDays.map { "\($0)天" }.joined(separator: "、"))
                    Button("修改默认周期和提醒时间") { cycles = true }
                    Text("新客户自动安排默认周期；已建档客户在编辑页面单独调整或重新安排。")
                        .font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("通知状态", value: store.notificationStatus)
                    Button("开启回访通知") { Task { await store.enableNotifications() } }
                    Button("打开系统设置") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    Text(store.reminderSummary).font(.footnote).foregroundStyle(.secondary)
                }
                Section("底部栏外观") {
                    LabeledContent("玻璃透明度", value: "\(Int(store.archive.preferences.dockTransparency * 100))%")
                    Slider(value: Binding(get: { store.archive.preferences.dockTransparency }, set: { value in
                        var next = store.archive.preferences; next.dockTransparency = value; _ = store.savePreferences(next)
                    }), in: 0...1, step: 0.05).accessibilityLabel("玻璃透明度").accessibilityIdentifier("dock-transparency")
                    HStack { Text("更实"); Spacer(); Text("更透") }.font(.caption).foregroundStyle(.secondary)
                    Text("调整玻璃背景，文字保持清晰。iOS 26 及以上采用系统 Liquid Glass，旧系统使用兼容毛玻璃；系统减少透明度设置优先。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("问答与话术资料") {
                    Button("导入 CSV 资料") { mode = .csv; importing = true }.disabled(pdf.processing)
                    Button("导入 PDF 资料（含扫描件）") { mode = .pdf; importing = true }.disabled(pdf.processing)
                        .accessibilityIdentifier("import-pdf")
                    if pdf.processing {
                        ProgressView(pdf.progress)
                        Button("取消 PDF 识别", role: .cancel) { pdf.cancel() }
                    }
                    Button("导出填写模板") { export(Data(CSV.export([]).utf8), type: .commaSeparatedText, name: "问答话术模板") }
                    Button("导出全部问答与话术") { export(Data(CSV.export(store.archive.knowledge).utf8), type: .commaSeparatedText, name: "问答话术") }
                    Text("PDF 在本机提取文字，扫描页自动尝试 OCR；导入前可逐条核对和编辑。带问/答标记的内容拆分为问答，其余按页导入原文。最多 100 页、20 MB。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("备份与恢复") {
                    Button("导出完整备份") {
                        guard !store.loadFailed else { store.error = "原数据读取失败，不能导出空白备份"; return }
                        do { export(try JSONEncoder().encode(store.archive), type: .json, name: "回访备份") }
                        catch { store.error = error.localizedDescription }
                    }
                    Button("从备份恢复") { mode = .backup; importing = true }.disabled(pdf.processing)
                    Text("备份包含客户、全部回访计划、历史、词库及设置。支持恢复旧版备份；恢复会替换当前数据，卸载前请备份。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("关于") {
                    Text("回访小助手 · 0.2.0")
                    Text("数据保存在本机。搜索匹配已有资料，不生成医疗建议。OCR 内容请核对原文。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $cycles) { CycleEditor(preferences: store.archive.preferences) }
            .sheet(isPresented: $preview) { ImportReview(entries: pendingEntries, summary: summary) }
            .fileImporter(isPresented: $importing, allowedContentTypes: types) { result in read(result) }
            .fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportName) { result in
                switch result { case .success: message = "已导出"; case .failure(let error): store.error = error.localizedDescription }
            }
            .onReceive(pdf.$result) { result in
                guard let result else { return }
                pendingEntries = result.entries
                summary = "共 \(result.pageCount) 页，其中 \(result.ocrPages) 页使用 OCR，得到 \(result.entries.count) 条内容。请核对产品、问答和来源。"
                if !result.skippedPages.isEmpty { summary += "未识别出文字的页：" + result.skippedPages.map(String.init).joined(separator: "、") }
                preview = true
            }
            .onReceive(pdf.$error) { error in if let error { store.error = error } }
            .confirmationDialog("恢复备份将替换全部现有数据", isPresented: $restoreConfirm, titleVisibility: .visible) {
                Button("替换并恢复", role: .destructive) {
                    if let archive = pendingArchive, store.commit(archive, restoring: true) { message = "恢复完成" }
                    pendingArchive = nil
                }
                Button("取消", role: .cancel) { pendingArchive = nil }
            } message: { Text("备份含 \(pendingArchive?.customers.count ?? 0) 位客户、\(pendingArchive?.knowledge.count ?? 0) 条词库内容。") }
            .alert("完成", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好") { message = nil }
            } message: { Text(message ?? "") }
        }
    }
    private func read(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 20_000_000 else { throw DataError.invalid("文件过大，请拆分为 20 MB 以内的文件") }
            let data = try Data(contentsOf: url)
            switch mode {
            case .backup:
                let archive = try JSONDecoder().decode(Archive.self, from: data)
                try archive.validate(); pendingArchive = archive; restoreConfirm = true
            case .csv:
                guard let text = String(data: data, encoding: .utf8) else { throw DataError.invalid("请另存为 CSV UTF-8 格式") }
                pendingEntries = try CSV.parse(text); summary = "CSV 共 \(pendingEntries.count) 条，可核对、编辑后导入。"; preview = true
            case .pdf:
                pdf.start(data: data, name: url.deletingPathExtension().lastPathComponent)
            }
        } catch { store.error = error.localizedDescription }
    }
    private func export(_ data: Data, type: UTType, name: String) {
        document = ExportDocument(data: data); exportType = type; exportName = name; exporting = true
    }
}

struct CycleEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var preferences: Preferences
    @State private var days = ""
    @State private var time = Date()
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("咨询后第几天回访") {
                    TextField("例如 3、7、21", text: $days).accessibilityIdentifier("cycle-days")
                    Text("填写多个天数，用逗号或顿号分隔。按日历天计算，不以每次回访完成日重新起算。")
                        .font(.footnote).foregroundStyle(.secondary)
                    DatePicker("默认提醒时间", selection: $time, displayedComponents: .hourAndMinute)
                    Button("恢复 3、7、21 天") { days = "3、7、21" }
                }
                Text("只影响新客户及手动重新安排的计划，已有回访时间保持原样。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("默认回访周期")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do {
                            preferences.followUpDays = try Preferences.parseDays(days)
                            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                            preferences.reminderHour = components.hour ?? 9; preferences.reminderMinute = components.minute ?? 0
                            if store.savePreferences(preferences) { dismiss() }
                            else { error = store.error; store.error = nil }
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
            .onAppear {
                days = preferences.followUpDays.map(String.init).joined(separator: "、")
                time = Calendar.current.date(bySettingHour: preferences.reminderHour, minute: preferences.reminderMinute, second: 0, of: Date())!
            }
            .alert("无法保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}
