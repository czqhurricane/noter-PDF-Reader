import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var accessManager: DirectoryAccessManager

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes = [UTType.folder]

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
        var parent: DocumentPicker
        private var pendingPDFPath: String?

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            if url.hasDirectoryPath {
                parent.accessManager.scanDirectory(at: url) {
                    NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 目录扫描完成")
                }

                NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 用户选择了目录将开始扫描目录并创建书签: \(url.path)")
            }
        }
    }
}

