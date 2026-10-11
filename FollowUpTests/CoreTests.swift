import XCTest
@testable import FollowUp

final class CoreTests: XCTestCase {
    func testCSVWithBOMQuotesCommasAndMultilineAnswer() throws {
        let entry = Knowledge(question: "如何保存？", aliases: "储存;保存", answer: "第一行,说明\n第二行\"引用\"", product: "产品A", source: "资料")
        let imported = try CSV.parse(CSV.export([entry]))
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].question, entry.question)
        XCTAssertEqual(imported[0].answer, entry.answer)
        XCTAssertEqual(imported[0].product, entry.product)
    }

    func testCSVRejectsMalformedAndIncompleteData() {
        XCTAssertThrowsError(try CSV.parse("问题,回答\nA,B"))
        XCTAssertThrowsError(try CSV.rows("\"未结束"))
        XCTAssertThrowsError(try CSV.parse(CSV.headers.joined(separator: ",") + "\n问答,问题,,,,,"))
        XCTAssertThrowsError(try CSV.rows("\"A\"B,C"))
    }

    func testCSVHandlesWindowsNewlinesAndEmptyLines() throws {
        let text = CSV.headers.joined(separator: ",") + "\r\n\r\n问答,问题,,回答,,,\r\n"
        XCTAssertEqual(try CSV.parse(text).count, 1)
    }

    func testExactQuestionRanksAboveAnswerAndAliasMatches() {
        let exact = Knowledge(question: "如何保存", answer: "按资料储存")
        let alias = Knowledge(question: "储存方法", aliases: "如何保存", answer: "按资料储存")
        let content = Knowledge(question: "其他问题", answer: "如何保存请看资料")
        XCTAssertGreaterThan(Search.score(exact, query: "如何保存"), Search.score(alias, query: "如何保存"))
        XCTAssertGreaterThan(Search.score(alias, query: "如何保存"), Search.score(content, query: "如何保存"))
        XCTAssertEqual(Search.score(exact, query: "完全无关关键词"), 0)
        XCTAssertGreaterThan(Search.score(alias, query: "如何 保存"), 0)
    }

    func testFingerprintIncludesProductAndKind() {
        let a = Knowledge(question: "保存", answer: "A", product: "产品A")
        let b = Knowledge(question: " 保存 ", answer: "B", product: "产品A")
        let c = Knowledge(question: "保存", answer: "C", product: "产品B")
        XCTAssertEqual(a.fingerprint, b.fingerprint)
        XCTAssertNotEqual(a.fingerprint, c.fingerprint)
    }

    func testArchiveRoundTripIncludesVisitAndReminder() throws {
        var customer = Customer(name: "客户", followUps: [FollowUpTask(date: Date(timeIntervalSince1970: 1800000000))])
        customer.history = [Visit(result: "已回访")]
        let original = Archive(customers: [customer], knowledge: [Knowledge(question: "问题", answer: "答案")])
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(original))
        try restored.validate()
        XCTAssertEqual(restored.customers, original.customers)
        XCTAssertEqual(restored.knowledge, original.knowledge)
    }

    func testArchiveRejectsDuplicateIDsAndUnknownVersion() {
        let customer = Customer(name: "客户")
        XCTAssertThrowsError(try Archive(customers: [customer, customer]).validate())
        XCTAssertThrowsError(try Archive(version: 99).validate())
    }
}
