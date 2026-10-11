import XCTest
@testable import FollowUp

final class FollowUpPlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    func testThreeSevenTwentyOneDaysFromConsultation() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 16))!
        let tasks = Preferences().makePlan(from: date, calendar: calendar)
        XCTAssertEqual(tasks.count, 3)
        XCTAssertEqual(tasks.map { calendar.component(.day, from: $0.date) }, [14, 18, 1])
        XCTAssertEqual(tasks.map { calendar.component(.month, from: $0.date) }, [10, 10, 11])
        XCTAssertTrue(tasks.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
        XCTAssertEqual(Set(tasks.map(\.id)).count, 3)
    }

    func testCustomDaysNormalizeAndRejectInvalidInput() throws {
        XCTAssertEqual(try Preferences.parseDays("21、3,7，3"), [3, 7, 21])
        XCTAssertEqual(try Preferences.parseDays("2 9 30"), [2, 9, 30])
        for input in ["", "0,3", "-1", "明天", "3651"] {
            XCTAssertThrowsError(try Preferences.parseDays(input))
        }
    }

    func testCompletingOneTaskPreservesLaterTasks() throws {
        var customer = Customer(name: "测试", followUps: Preferences().makePlan(from: Date(), calendar: calendar))
        let first = customer.followUps[0], later = Array(customer.followUps.dropFirst())
        try customer.recordVisit(result: "完成第3天回访", taskID: first.id)
        XCTAssertEqual(customer.pendingFollowUps, later)
        XCTAssertNotNil(customer.followUps[0].completedAt)
        XCTAssertEqual(customer.history.first?.followUpID, first.id)
        XCTAssertThrowsError(try customer.recordVisit(result: "重复完成", taskID: first.id))
        XCTAssertEqual(customer.history.count, 1)
    }

    func testAdHocVisitDoesNotCompleteScheduledTasks() throws {
        var customer = Customer(name: "测试", followUps: Preferences().makePlan(from: Date()))
        let before = customer.pendingFollowUps
        try customer.recordVisit(result: "临时沟通", taskID: nil)
        XCTAssertEqual(customer.pendingFollowUps, before)
    }

    func testLegacyBackupMigratesWithoutLosingReminderOrHistory() throws {
        let id = UUID()
        let visitID = UUID()
        let raw: [String: Any] = ["version": 1, "knowledge": [], "customers": [[
            "id": id.uuidString, "name": "原客户", "contact": "微信", "product": "A", "notes": "备注", "status": "咨询中",
            "createdAt": 12345, "nextFollowUp": 54321,
            "history": [["id": visitID.uuidString, "date": 23456, "result": "旧记录"]]
        ]]]
        let data = try JSONSerialization.data(withJSONObject: raw)
        let restored = try JSONDecoder().decode(Archive.self, from: data)
        try restored.validate()
        XCTAssertEqual(restored.version, 2)
        XCTAssertEqual(restored.customers[0].id, id)
        XCTAssertEqual(restored.customers[0].consultedAt, Date(timeIntervalSinceReferenceDate: 12345))
        XCTAssertEqual(restored.customers[0].pendingFollowUps[0].date, Date(timeIntervalSinceReferenceDate: 54321))
        XCTAssertEqual(restored.customers[0].history[0].id, visitID)
        XCTAssertEqual(restored.preferences.followUpDays, [3, 7, 21])
        let roundTrip = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(restored))
        XCTAssertEqual(roundTrip.customers, restored.customers)
    }

    func testArchiveCountsTasksAndRejectsDuplicateTaskIDs() throws {
        let task = FollowUpTask(date: Date())
        let a = Customer(name: "A", followUps: [task])
        let b = Customer(name: "B", followUps: [task])
        XCTAssertThrowsError(try Archive(customers: [a, b]).validate())
        var customer = Customer(name: "C", followUps: Preferences().makePlan(from: Date()))
        try customer.recordVisit(result: "完成", taskID: customer.followUps[0].id)
        XCTAssertEqual(Archive(customers: [customer]).pendingFollowUps.count, 2)
    }
}
