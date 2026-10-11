import SwiftUI

struct Dashboard: View {
    @EnvironmentObject var store: Store
    var due: [PendingFollowUp] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return store.archive.pendingFollowUps.filter { $0.task.date < Calendar.current.startOfDay(for: tomorrow) }
    }
    var body: some View {
        NavigationStack {
            List {
                Section("工作概览") {
                    LabeledContent("客户总数", value: "\(store.archive.customers.count)")
                    LabeledContent("今日及逾期回访任务", value: "\(due.count)")
                    LabeledContent("待回访任务总数", value: "\(store.archive.pendingFollowUps.count)")
                    LabeledContent("已完成回访", value: "\(store.archive.customers.reduce(0) { $0 + $1.history.count })")
                    LabeledContent("已成交客户", value: "\(store.archive.customers.filter { $0.status == "已成交" }.count)")
                }
                Section("今日与逾期") {
                    if due.isEmpty { Text("今天没有待回访任务").foregroundStyle(.secondary) }
                    ForEach(due) { item in
                        NavigationLink { CustomerDetail(id: item.customer.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.customer.name).font(.headline)
                                Text(item.task.title).font(.subheadline)
                                Text(item.task.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundColor(item.task.date < Date() ? .orange : .secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
                Section("产品咨询量") {
                    let groups = Dictionary(grouping: store.archive.customers, by: { $0.product.isEmpty ? "未填写产品" : $0.product })
                    ForEach(groups.keys.sorted(), id: \.self) { product in LabeledContent(product, value: "\(groups[product]?.count ?? 0) 人") }
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
                Text("下次：" + date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(date < Date() ? .orange : .secondary)
            }
            Text("\(customer.pendingFollowUps.count) 项待回访").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

struct CustomersView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var adding = false
    var customers: [Customer] {
        store.archive.customers.filter { query.isEmpty || Search.normalize([$0.name, $0.contact, $0.product, $0.notes].joined()).contains(Search.normalize(query)) }.sorted { $0.createdAt > $1.createdAt }
    }
    var body: some View {
        NavigationStack {
            List {
                if customers.isEmpty { Text("暂无客户，点击右上角添加").foregroundStyle(.secondary) }
                ForEach(customers) { customer in NavigationLink { CustomerDetail(id: customer.id) } label: { CustomerRow(customer: customer) } }
            }
            .searchable(text: $query, prompt: "姓名、联系方式、产品").navigationTitle("客户")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("添加客户").accessibilityIdentifier("add-customer") }
            .sheet(isPresented: $adding) { CustomerEditor(customer: Customer()) }
        }
    }
}

struct CustomerEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var customer: Customer
    @State private var initialized = false
    @State private var replacePlan = false
    var body: some View {
        NavigationStack {
            Form {
                Section("客户信息") {
                    TextField("客户称呼（必填）", text: $customer.name).accessibilityIdentifier("customer-name")
                    TextField("电话 / 微信", text: $customer.contact)
                    TextField("咨询产品", text: $customer.product)
                    DatePicker("咨询日期", selection: $customer.consultedAt, displayedComponents: .date)
                    Picker("客户状态", selection: $customer.status) { ForEach(["咨询中", "试用中", "已成交", "暂不跟进"], id: \.self) { Text($0) } }
                    TextField("关注问题及备注", text: $customer.notes, axis: .vertical).lineLimit(3...8)
                }
                Section {
                    ForEach($customer.followUps) { $task in
                        if task.completedAt == nil {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("回访名称", text: $task.title)
                                DatePicker("回访时间", selection: $task.date)
                                Button("移除此项", role: .destructive) { customer.followUps.removeAll { $0.id == task.id } }.font(.caption)
                            }.padding(.vertical, 4)
                        }
                    }
                    Button("手动添加回访") { customer.followUps.append(FollowUpTask(date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)) }
                    Button("按默认周期重新安排") { replacePlan = true }
                } header: { Text("回访计划 · \(customer.pendingFollowUps.count) 项") } footer: {
                    Text("默认以咨询日期计算第 \(store.archive.preferences.followUpDays.map(String.init).joined(separator: "、")) 天。修改咨询日期后，可点击重新安排；也可逐项修改。已完成回访保留。")
                }
            }
            .navigationTitle("客户资料")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        customer.name = customer.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.save(customer) { dismiss() }
                    }.disabled(customer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("save-customer")
                }
            }
            .onAppear {
                guard !initialized else { return }; initialized = true
                if !store.archive.customers.contains(where: { $0.id == customer.id }) { customer.followUps = store.archive.preferences.makePlan(from: customer.consultedAt) }
            }
            .confirmationDialog("替换所有未完成的回访时间？", isPresented: $replacePlan, titleVisibility: .visible) {
                Button("按默认周期重新安排") { customer.followUps = customer.followUps.filter { $0.completedAt != nil } + store.archive.preferences.makePlan(from: customer.consultedAt) }
            }
        }
    }
}

struct CustomerDetail: View {
    @EnvironmentObject var store: Store
    let id: UUID
    @State private var editing = false
    @State private var visiting = false
    @State private var selectedTask: FollowUpTask?
    @State private var deleting = false
    var customer: Customer? { store.archive.customers.first { $0.id == id } }
    var body: some View {
        Group {
            if let customer {
                List {
                    Section("客户信息") {
                        LabeledContent("联系方式", value: customer.contact)
                        LabeledContent("咨询产品", value: customer.product)
                        LabeledContent("咨询日期", value: customer.consultedAt.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("状态", value: customer.status)
                        Text(customer.notes.isEmpty ? "暂无备注" : customer.notes)
                        Button("记录临时回访") { visiting = true }
                        NavigationLink("查找问答 / 回访话术") { LibraryView(initialQuery: customer.product) }
                    }
                    Section("回访计划") {
                        if customer.pendingFollowUps.isEmpty { Text("暂无待回访计划，可点击编辑添加").foregroundStyle(.secondary) }
                        ForEach(customer.pendingFollowUps) { task in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(task.title).font(.headline)
                                Text(task.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundColor(task.date < Date() ? .orange : .secondary)
                                Button("记录并完成这项回访") { selectedTask = task }
                            }.padding(.vertical, 4)
                        }
                    }
                    Section("回访历史") {
                        if customer.history.isEmpty { Text("暂无回访记录").foregroundStyle(.secondary) }
                        ForEach(customer.history.sorted { $0.date > $1.date }) { visit in
                            VStack(alignment: .leading, spacing: 8) {
                                if let task = customer.followUps.first(where: { $0.id == visit.followUpID }) { Text(task.title).font(.caption).foregroundStyle(.teal) }
                                Text(visit.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                Text(visit.result).textSelection(.enabled)
                            }
                        }
                    }
                    Section { Button("删除客户", role: .destructive) { deleting = true } }
                }
                .navigationTitle(customer.name).toolbar { Button("编辑") { editing = true } }
                .sheet(isPresented: $editing) { CustomerEditor(customer: customer) }
                .sheet(isPresented: $visiting) { VisitEditor(customerID: id, task: nil) }
                .sheet(item: $selectedTask) { task in VisitEditor(customerID: id, task: task) }
                .confirmationDialog("删除客户及全部回访记录？", isPresented: $deleting, titleVisibility: .visible) { Button("删除", role: .destructive) { store.deleteCustomer(id) } }
            } else { Text("客户已删除") }
        }
    }
}

struct VisitEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let customerID: UUID
    let task: FollowUpTask?
    @State private var result = ""
    @State private var additional = false
    @State private var date = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
    var body: some View {
        NavigationStack {
            Form {
                if let task { Section("本次任务") { Text(task.title) } }
                Section("沟通结果") { TextEditor(text: $result).frame(minHeight: 150) }
                Section {
                    Toggle("额外添加一次回访", isOn: $additional)
                    if additional { DatePicker("时间", selection: $date, in: Date()...) }
                } footer: { Text("只完成所选任务，其余回访时间保持原有安排。临时回访不会完成已有任务。") }
            }
            .navigationTitle("记录回访")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if store.recordVisit(customerID: customerID, taskID: task?.id, result: result.trimmingCharacters(in: .whitespacesAndNewlines), additional: additional ? FollowUpTask(date: date) : nil) { dismiss() }
                    }.disabled(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (additional && date <= Date()))
                }
            }
        }
    }
}
