import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PDFPicker: UIViewControllerRepresentable {
    @ObservedObject var accessManager: DirectoryAccessManager

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes = [UTType.pdf]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)

        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: PDFPicker
        private var pendingPDFPath: String?

        init(_ parent: PDFPicker) {
            self.parent = parent
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // 保存待打开的PDF路径
            pendingPDFPath = url.path

            NotificationCenter.default.post(
                name: Notification.Name("OpenSelectedPDF"),
                object: nil,
                userInfo: [
                    "pdfPath": pendingPDFPath!,
                    "currentPage": 1,
                    "xRatio": 0.5,
                    "yRatio": 0.5,
                ]
            )

            NSLog("✅ PDFPicker.swift -> PDFPicker.Coordinator.documentPicker, 用户选择了文件将打开: \(url.path)")
        }
    }
}
