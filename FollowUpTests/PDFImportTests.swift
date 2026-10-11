import XCTest
import PDFKit
import UIKit
@testable import FollowUp

final class PDFImportTests: XCTestCase {
    @MainActor
    func testDocumentSelectionAndCancellationCallbacks() {
        var selection: URL?
        var cancelled = false
        let delegate = DocumentImportPicker.Coordinator(selected: { selection = $0 }, cancelled: { cancelled = true })
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        let url = URL(fileURLWithPath: "/tmp/guide.pdf")
        delegate.documentPicker(picker, didPickDocumentsAt: [url])
        XCTAssertEqual(selection, url)
        XCTAssertFalse(cancelled)
        delegate.documentPickerWasCancelled(picker)
        XCTAssertTrue(cancelled)
    }

    @MainActor
    func testPDFSessionReadsSelectedFileAndReportsFailure() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 800)).pdfData { context in
            context.beginPage()
            ("Q: Where is the guide?\nA: Read the official product guide." as NSString).draw(
                in: CGRect(x: 40, y: 40, width: 500, height: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
        }
        try data.write(to: url)
        let session = PDFImportSession()
        session.start(url: url)
        XCTAssertTrue(session.processing)
        for _ in 0..<200 where session.processing { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertFalse(session.processing)
        XCTAssertNil(session.error)
        XCTAssertEqual(session.result?.entries.count, 1)
        XCTAssertTrue(session.result?.entries.first?.answer.contains("official product guide") == true)
        try Data("invalid pdf".utf8).write(to: url)
        session.start(url: url)
        for _ in 0..<200 where session.processing { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertFalse(session.processing)
        XCTAssertNil(session.result)
        XCTAssertNotNil(session.error)
    }

    func testQuestionAnswerSplittingAndPageSource() {
        let entries = PDFText.entries(text: "问：如何查看资料？\n答：请查看官方说明。\n问题：第二个问题？\n回答：第二个答案。", document: "说明", page: 2, ocr: false)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].question, "如何查看资料？")
        XCTAssertEqual(entries[0].answer, "请查看官方说明。")
        XCTAssertTrue(entries[1].source.contains("第 2 页"))
    }

    func testPlainPDFKeepsOriginalTextAndOCRWarning() {
        let entries = PDFText.entries(text: "产品原文\n储存条件见标签", document: "说明", page: 1, ocr: true)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].answer, "产品原文\n储存条件见标签")
        XCTAssertTrue(entries[0].source.contains("OCR"))
        XCTAssertTrue(PDFText.entries(text: " \n", document: "空页", page: 1, ocr: false).isEmpty)
    }

    func testTextPDFExtractionAndInvalidFile() throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 800))
        let data = renderer.pdfData { context in
            context.beginPage()
            let text = "Q: Where is the product guide?\nA: Read the official product guide before use."
            (text as NSString).draw(in: CGRect(x: 40, y: 40, width: 500, height: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
        }
        let result = try PDFImport.extract(data: data, name: "Guide")
        XCTAssertEqual(result.pageCount, 1)
        XCTAssertEqual(result.ocrPages, 0)
        XCTAssertTrue(result.entries[0].answer.contains("official product guide"))
        XCTAssertThrowsError(try PDFImport.extract(data: Data("invalid".utf8), name: "Invalid"))
    }

    func testScannedPDFUsesOnDeviceOCR() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 500)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 500))
            ("PRODUCT GUIDE\nStorage instructions" as NSString).draw(in: CGRect(x: 60, y: 80, width: 1080, height: 350), withAttributes: [.font: UIFont.systemFont(ofSize: 65), .foregroundColor: UIColor.black])
        }
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 250)).pdfData { context in
            context.beginPage(); image.draw(in: CGRect(x: 0, y: 0, width: 600, height: 250))
        }
        let result = try PDFImport.extract(data: data, name: "Scan")
        XCTAssertEqual(result.ocrPages, 1)
        XCTAssertTrue(result.entries.contains { $0.answer.uppercased().contains("PRODUCT") })
    }
}
