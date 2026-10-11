import SwiftUI
import UIKit

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
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "输入问题、关键词或产品")
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

