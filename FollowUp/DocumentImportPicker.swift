import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Import a local copy, and let the owning sheet close before reading it.
struct DocumentImportPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let selected: (URL) -> Void
    let cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(selected: selected, cancelled: cancelled) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        #if DEBUG
        // UI tests supply a local PDF to exercise the real selection delegate and sheet dismissal.
        if ProcessInfo.processInfo.arguments.contains("--test-pdf-selection") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ImportRegression.pdf")
            let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 800)).pdfData { page in
                page.beginPage()
                ("Q: Where is the product guide?\nA: Read the official product guide." as NSString).draw(
                    in: CGRect(x: 40, y: 40, width: 500, height: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
            }
            do {
                try data.write(to: url)
                let delegate = context.coordinator
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { delegate.documentPicker(picker, didPickDocumentsAt: [url]) }
            } catch { context.coordinator.cancelled() }
        }
        #endif
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let selected: (URL) -> Void
        let cancelled: () -> Void
        init(selected: @escaping (URL) -> Void, cancelled: @escaping () -> Void) {
            self.selected = selected; self.cancelled = cancelled
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { cancelled(); return }
            selected(url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { cancelled() }
    }
}
