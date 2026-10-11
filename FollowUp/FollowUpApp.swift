import SwiftUI
import UniformTypeIdentifiers
import UIKit

@main
struct FollowUpApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TabView {
                Dashboard().tabItem { Label("回访", systemImage: "bell.badge") }
                CustomersView().tabItem { Label("客户", systemImage: "person.2") }
                LibraryView().tabItem { Label("问答与话术", systemImage: "text.book.closed") }
                SettingsView().tabItem { Label("设置", systemImage: "gearshape") }
            }
            .tint(Color(red: 0.12, green: 0.47, blue: 0.43))
            .environmentObject(store)
            .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("知道了") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .task { store.refreshReminders() }
            .onChange(of: phase) { phase in if phase == .active { store.refreshReminders() } }
        }
    }
}

struct Dashboard: View {
    @EnvironmentObject var store: Store
    var due: [Customer] {
        store.archive.customers.filter {
            guard let date = $0.nextFollowUp else { return false }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            return date < Calendar.current.startOfDay(for: tomorrow)
        }.sorted { $0.nextFollowUp! < $1.nextFollowUp! }
    }
    var body: some View {
        NavigationStack {
            List {
                Section("工作概览") {
                    LabeledContent("客户总数", value: "\(store.archive.customers.count)")
                    LabeledContent("今日及逾期待回访", value: "\(due.count)")
                    LabeledContent("已完成回访", value: "\(store.archive.customers.reduce(0) { $0 + $1.history.count })")
                    LabeledContent("已成交客户", value: "\(store.archive.customers.filter { $0.status == "已成交" }.count)")
                }
                Section("待回访") {
                    if due.isEmpty { Text("今天没有待回访客户").foregroundStyle(.secondary) }
                    ForEach(due) { customer in
                        NavigationLink { CustomerDetail(id: customer.id) } label: { CustomerRow(customer: customer) }
                    }
                }
                Section("产品咨询量") {
                    let groups = Dictionary(grouping: store.archive.customers, by: { $0.product.isEmpty ? "未填写产品" : $0.product })
                    ForEach(groups.keys.sorted(), id: \.self) { product in
                        LabeledContent(product, value: "\(groups[product]?.count ?? 0) 人")
                    }
                }
            }.navigationTitle("回访小助手")
        }
    }
}

struct CustomerRow: View {
    let customer: Customer
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(customer.name).font(.headline); Spacer(); Text(customer.status).font(.caption).foregroundStyle(.secondary) }
            Text(customer.product.isEmpty ? "未填写咨询产品" : customer.product).font(.subheadline).foregroundStyle(.secondary)
            if let date = customer.nextFollowUp {
                Text("回访：" + date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundColor(date < Date() ? .orange : .secondary)
            }
        }.padding(.vertical, 4)
    }
}

struct CustomersView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var adding = false
    var customers: [Customer] {
        store.archive.customers.filter { query.isEmpty || Search.normalize([$0.name, $0.contact, $0.product, $0.notes].joined()).contains(Search.normalize(query)) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    var body: some View {
        NavigationStack {
            List {
                if customers.isEmpty { Text("暂无客户，点击右上角添加").foregroundStyle(.secondary) }
                ForEach(customers) { customer in
                    NavigationLink { CustomerDetail(id: customer.id) } label: { CustomerRow(customer: customer) }
                }
            }
            .searchable(text: $query, prompt: "姓名、联系方式、产品")
            .navigationTitle("客户")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("添加客户") }
            .sheet(isPresented: $adding) { CustomerEditor(customer: Customer()) }
        }
    }
}

struct CustomerEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var customer: Customer
    @State private var reminder = false
    @State private var date = Date().addingTimeInterval(86400)
    var body: some View {
        NavigationStack {
            Form {
                Section("客户信息") {
                    TextField("客户称呼（必填）", text: $customer.name)
                    TextField("电话 / 微信", text: $customer.contact)
                    TextField("咨询产品", text: $customer.product)
                    Picker("客户状态", selection: $customer.status) {
                        ForEach(["咨询中", "试用中", "已成交", "暂不跟进"], id: \.self) { Text($0) }
                    }
                    TextField("关注问题及备注", text: $customer.notes, axis: .vertical).lineLimit(3...8)
                }
                Section("下次回访") {
                    Toggle("安排回访", isOn: $reminder)
                    if reminder { DatePicker("提醒时间", selection: $date, in: Date()...) }
                }
            }
            .navigationTitle("客户资料")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        customer.name = customer.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        customer.nextFollowUp = reminder ? date : nil
                        if store.save(customer) { dismiss() }
                    }.disabled(customer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (reminder && date <= Date()))
                }
            }
            .onAppear { reminder = customer.nextFollowUp != nil; date = max(customer.nextFollowUp ?? date, Date().addingTimeInterval(60)) }
        }
    }
}

struct CustomerDetail: View {
    @EnvironmentObject var store: Store
    let id: UUID
    @State private var editing = false
    @State private var visiting = false
    @State private var deleting = false
    var customer: Customer? { store.archive.customers.first { $0.id == id } }
    var body: some View {
        Group {
            if let customer {
                List {
                    Section("客户信息") {
                        LabeledContent("联系方式", value: customer.contact)
                        LabeledContent("咨询产品", value: customer.product)
                        LabeledContent("状态", value: customer.status)
                        Text(customer.notes.isEmpty ? "暂无备注" : customer.notes)
                        if let date = customer.nextFollowUp { LabeledContent("下次回访", value: date.formatted(date: .abbreviated, time: .shortened)) }
                        Button("记录本次回访") { visiting = true }
                        NavigationLink("查找问答 / 回访话术") { LibraryView(initialQuery: customer.product) }
                    }
                    Section("回访历史") {
                        if customer.history.isEmpty { Text("暂无回访记录").foregroundStyle(.secondary) }
                        ForEach(customer.history.sorted { $0.date > $1.date }) { visit in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(visit.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                Text(visit.result).textSelection(.enabled)
                            }
                        }
                    }
                    Section { Button("删除客户", role: .destructive) { deleting = true } }
                }
                .navigationTitle(customer.name)
                .toolbar { Button("编辑") { editing = true } }
                .sheet(isPresented: $editing) { CustomerEditor(customer: customer) }
                .sheet(isPresented: $visiting) { VisitEditor(customer: customer) }
                .confirmationDialog("删除客户及全部回访记录？", isPresented: $deleting, titleVisibility: .visible) {
                    Button("删除", role: .destructive) { store.deleteCustomer(id) }
                }
            } else { Text("客户已删除") }
        }
    }
}

struct VisitEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var customer: Customer
    @State private var result = ""
    @State private var again = true
    @State private var date = Date().addingTimeInterval(3 * 86400)
    var body: some View {
        NavigationStack {
            Form {
                Section("沟通结果") { TextEditor(text: $result).frame(minHeight: 150) }
                Section("后续安排") {
                    Toggle("安排下次回访", isOn: $again)
                    if again { DatePicker("时间", selection: $date, in: Date()...) }
                }
            }
            .navigationTitle("记录回访")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        customer.history.append(Visit(result: result.trimmingCharacters(in: .whitespacesAndNewlines)))
                        customer.nextFollowUp = again ? date : nil
                        if store.save(customer) { dismiss() }
                    }.disabled(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (again && date <= Date()))
                }
            }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var store: Store
    @State private var query: String
    @State private var kind = "问答"
    @State private var adding = false
    init(initialQuery: String = "") { _query = State(initialValue: initialQuery) }
    var entries: [Knowledge] {
        store.archive.knowledge.filter { $0.kind == kind && Search.score($0, query: query) > 0 }
            .sorted {
                let a = Search.score($0, query: query), b = Search.score($1, query: query)
                return a == b ? $0.updatedAt > $1.updatedAt : a > b
            }
    }
    var body: some View {
        NavigationStack {
            VStack {
                Picker("内容类型", selection: $kind) { Text("产品问答").tag("问答"); Text("回访话术").tag("话术") }
                    .pickerStyle(.segmented).padding(.horizontal)
                List {
                    if entries.isEmpty {
                        Text(query.isEmpty ? "暂无内容，可手动新增或在设置中导入资料" : "暂无匹配答案，请换个关键词或新增条目")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(entries) { entry in
                        NavigationLink { KnowledgeDetail(id: entry.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.question).font(.headline)
                                Text(entry.answer).font(.subheadline).lineLimit(2).foregroundStyle(.secondary)
                                Text([entry.product, entry.tags].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.teal)
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("问答与话术")
            .searchable(text: $query, prompt: "输入问题、关键词或产品")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("新增问答或话术") }
            .sheet(isPresented: $adding) { KnowledgeEditor(entry: Knowledge(kind: kind)) }
        }
    }
}

struct KnowledgeDetail: View {
    @EnvironmentObject var store: Store
    let id: UUID
    @State private var editing = false
    @State private var deleting = false
    @State private var copied = false
    var entry: Knowledge? { store.archive.knowledge.first { $0.id == id } }
    var body: some View {
        Group {
            if let entry {
                List {
                    Section("问题 / 场景") { Text(entry.question).font(.headline); Text(entry.aliases).foregroundStyle(.secondary) }
                    Section("回答") {
                        Text(entry.answer).textSelection(.enabled)
                        Button(copied ? "已复制" : "复制回答") { UIPasteboard.general.string = entry.answer; copied = true }
                    }
                    Section("资料信息") {
                        LabeledContent("关联产品", value: entry.product.isEmpty ? "通用" : entry.product)
                        LabeledContent("标签", value: entry.tags)
                        LabeledContent("来源", value: entry.source.isEmpty ? "未填写" : entry.source)
                        LabeledContent("更新日期", value: entry.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    Section { Button("删除条目", role: .destructive) { deleting = true } }
                }
                .navigationTitle(entry.kind)
                .toolbar { Button("编辑") { editing = true } }
                .sheet(isPresented: $editing) { KnowledgeEditor(entry: entry) }
                .confirmationDialog("删除这条内容？", isPresented: $deleting, titleVisibility: .visible) {
                    Button("删除", role: .destructive) { store.deleteEntry(id) }
                }
            } else { Text("条目已删除") }
        }
    }
}

struct KnowledgeEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var entry: Knowledge
    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $entry.kind) { Text("问答").tag("问答"); Text("话术").tag("话术") }
                Section("问题 / 场景") {
                    TextField("标准问题或话术名称（必填）", text: $entry.question, axis: .vertical)
                    TextField("相似问法，可用分号分隔", text: $entry.aliases, axis: .vertical)
                }
                Section("回答（必填）") { TextEditor(text: $entry.answer).frame(minHeight: 180) }
                Section("分类和来源") {
                    TextField("关联产品，留空表示通用", text: $entry.product)
                    TextField("标签，例如首次回访、转奶", text: $entry.tags)
                    TextField("来源，例如品牌资料名称及版本", text: $entry.source)
                }
            }
            .navigationTitle("编辑内容")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        entry.question = entry.question.trimmingCharacters(in: .whitespacesAndNewlines)
                        entry.answer = entry.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        entry.updatedAt = Date()
                        if store.save(entry) { dismiss() }
                    }.disabled(entry.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || entry.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var importing = false
    @State private var restoreMode = false
    @State private var exporting = false
    @State private var exportType = UTType.json
    @State private var exportName = "回访备份"
    @State private var document = ExportDocument(data: Data())
    @State private var pendingEntries: [Knowledge] = []
    @State private var pendingArchive: Archive?
    @State private var preview = false
    @State private var restoreConfirm = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("提醒") {
                    LabeledContent("通知状态", value: store.notificationStatus)
                    Button("开启回访通知") { Task { await store.enableNotifications() } }
                    Button("打开系统设置") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    Text(store.reminderSummary).font(.footnote).foregroundStyle(.secondary)
                }
                Section("问答与话术资料") {
                    Button("导入 CSV 资料") { restoreMode = false; importing = true }
                    Button("导出填写模板") {
                        export(Data(CSV.export([]).utf8), type: .commaSeparatedText, name: "问答话术模板")
                    }
                    Button("导出全部问答与话术") {
                        export(Data(CSV.export(store.archive.knowledge).utf8), type: .commaSeparatedText, name: "问答话术")
                    }
                    Text("Excel 按模板填写后另存为 CSV UTF-8。Word、PDF 的内容需先整理为表格。重复的类型、问题及产品组合会跳过，已有回答保留。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("备份与恢复") {
                    Button("导出完整备份") {
                        guard !store.loadFailed else { store.error = "原数据读取失败，不能导出空白备份"; return }
                        do { export(try JSONEncoder().encode(store.archive), type: .json, name: "回访备份") }
                        catch { store.error = error.localizedDescription }
                    }
                    Button("从备份恢复") { restoreMode = true; importing = true }
                    Text("完整备份包含客户、回访历史和词库。恢复将替换当前全部数据。卸载前请导出备份，并保管好包含客户联系方式的文件。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("关于") {
                    Text("回访小助手 · 0.1.0")
                    Text("数据保存在本机。搜索匹配已有资料，不生成医疗建议。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .fileImporter(isPresented: $importing, allowedContentTypes: restoreMode ? [.json] : [.commaSeparatedText, .plainText]) { result in
                do {
                    let url = try result.get()
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? 0) <= 20_000_000 else { throw DataError.invalid("文件过大，请拆分为 20 MB 以内的文件") }
                    let data = try Data(contentsOf: url)
                    if restoreMode {
                        let archive = try JSONDecoder().decode(Archive.self, from: data)
                        try archive.validate()
                        pendingArchive = archive; restoreConfirm = true
                    } else {
                        guard let text = String(data: data, encoding: .utf8) else { throw DataError.invalid("请另存为 CSV UTF-8 格式") }
                        pendingEntries = try CSV.parse(text); preview = true
                    }
                } catch { store.error = error.localizedDescription }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportName) { result in
                switch result {
                case .success: message = "已导出"
                case .failure(let error): store.error = error.localizedDescription
                }
            }
            .sheet(isPresented: $preview) {
                NavigationStack {
                    List {
                        let keys = Set(store.archive.knowledge.map(\.fingerprint))
                        let added = Set(pendingEntries.map(\.fingerprint)).subtracting(keys).count
                        Section { Text("共 \(pendingEntries.count) 条，将新增 \(added) 条，其余重复条目跳过。") }
                        ForEach(pendingEntries) { entry in
                            VStack(alignment: .leading) { Text(entry.question).font(.headline); Text(entry.answer).font(.caption).lineLimit(3) }
                        }
                    }
                    .navigationTitle("导入预览")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { preview = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("导入") { if store.importEntries(pendingEntries) { preview = false; message = "导入完成" } } }
                    }
                }
            }
            .confirmationDialog("恢复备份将替换全部现有数据", isPresented: $restoreConfirm, titleVisibility: .visible) {
                Button("替换并恢复", role: .destructive) {
                    if let archive = pendingArchive, store.commit(archive, restoring: true) { message = "恢复完成" }
                    pendingArchive = nil
                }
                Button("取消", role: .cancel) { pendingArchive = nil }
            } message: {
                Text("备份含 \(pendingArchive?.customers.count ?? 0) 位客户、\(pendingArchive?.knowledge.count ?? 0) 条词库内容。")
            }
            .alert("完成", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好") { message = nil }
            } message: { Text(message ?? "") }
        }
    }
    func export(_ data: Data, type: UTType, name: String) {
        document = ExportDocument(data: data); exportType = type; exportName = name; exporting = true
    }
}
