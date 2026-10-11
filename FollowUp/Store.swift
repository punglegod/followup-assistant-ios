import SwiftUI
import UserNotifications

@MainActor
final class Store: ObservableObject {
    @Published private(set) var archive = Archive()
    @Published var error: String?
    @Published var notificationStatus = "尚未开启"
    @Published var reminderSummary = ""
    @Published private(set) var loadFailed = false
    private var reminderTask: Task<Void, Never>?
    private let file: URL

    init() {
        file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("followup.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let saved = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
                try saved.validate()
                archive = saved
            } catch {
                loadFailed = true
                self.error = "本地数据读取失败，已保护原文件。请从设置恢复备份：\(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    func commit(_ next: Archive, restoring: Bool = false) -> Bool {
        guard !loadFailed || restoring else { error = "请先恢复备份，避免覆盖原数据"; return false }
        do {
            try next.validate()
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(next)
            try data.write(to: file, options: [.atomic, .completeFileProtection])
            archive = next
            loadFailed = false
            refreshReminders()
            return true
        } catch {
            self.error = "保存失败：\(error.localizedDescription)"
            return false
        }
    }

    func save(_ customer: Customer) -> Bool {
        var next = archive
        if let index = next.customers.firstIndex(where: { $0.id == customer.id }) { next.customers[index] = customer }
        else { next.customers.append(customer) }
        return commit(next)
    }

    func save(_ entry: Knowledge) -> Bool {
        var next = archive
        if let index = next.knowledge.firstIndex(where: { $0.id == entry.id }) { next.knowledge[index] = entry }
        else { next.knowledge.append(entry) }
        return commit(next)
    }

    func deleteCustomer(_ id: UUID) { var next = archive; next.customers.removeAll { $0.id == id }; _ = commit(next) }
    func deleteEntry(_ id: UUID) { var next = archive; next.knowledge.removeAll { $0.id == id }; _ = commit(next) }

    func importEntries(_ entries: [Knowledge]) -> Bool {
        var next = archive
        var keys = Set(next.knowledge.map(\.fingerprint))
        for entry in entries where keys.insert(entry.fingerprint).inserted { next.knowledge.append(entry) }
        return commit(next)
    }

    func enableNotifications() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            refreshReminders()
        } catch { self.error = "通知授权失败：\(error.localizedDescription)" }
    }

    func refreshReminders() {
        let previous = reminderTask
        reminderTask?.cancel()
        reminderTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await scheduleReminders()
        }
    }

    private func scheduleReminders() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard !Task.isCancelled else { return }
        let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        notificationStatus = allowed ? "已开启" : "未开启，请在系统设置中允许通知"
        center.removeAllPendingNotificationRequests()
        guard allowed else { reminderSummary = "待办列表仍可查看，系统通知未开启"; return }
        let scheduled = archive.customers.filter { $0.nextFollowUp != nil }.sorted { $0.nextFollowUp! < $1.nextFollowUp! }
        // Keep room under system pending-notification limits. Replenish on each foreground/save.
        let upcoming = scheduled.filter { $0.nextFollowUp! > Date() }
        let overdue = scheduled.filter { $0.nextFollowUp! <= Date() }
        var requests: [UNNotificationRequest] = []
        if !overdue.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = "回访小助手"
            content.body = "有 \(overdue.count) 位客户待回访，请打开应用查看。"
            content.sound = .default
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
            requests.append(UNNotificationRequest(identifier: "overdue", content: content, trigger: trigger))
        }
        for customer in upcoming.prefix(59) {
            let content = UNMutableNotificationContent()
            content.title = "回访小助手"
            content.body = "有一项客户回访到期，请打开应用查看。"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: customer.nextFollowUp!), repeats: false)
            requests.append(UNNotificationRequest(identifier: customer.id.uuidString, content: content, trigger: trigger))
        }
        for request in requests {
            guard !Task.isCancelled else { return }
            do { try await center.add(request) }
            catch { self.error = "部分提醒设置失败：\(error.localizedDescription)" }
        }
        reminderSummary = "已安排最近 \(min(upcoming.count, 59)) 项到期提醒；打开应用时更新后续提醒。逾期任务次日上午提醒。"
    }
}
