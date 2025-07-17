import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var accessManager: DirectoryAccessManager
    var forOrgRoam: Bool = false

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes = [UTType.folder]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)

        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self, for: forOrgRoam)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        private var pendingPDFPath: String?

        init(_ parent: DocumentPicker, for roam: Bool) {
            self.parent = parent
            self.forOrgRoam = roam
        }

        private var forOrgRoam: Bool

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            if url.hasDirectoryPath && !self.forOrgRoam {
                parent.accessManager.scanDirectory(at: url) {
                    NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, PDF 目录扫描完成")
                }

                NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 用户选择了 PDF 目录将开始扫描目录并创建书签: \(url.path)")
            } else if url.hasDirectoryPath && self.forOrgRoam {
                parent.accessManager.scanOrgRoamDirectory(at: url) {
                    NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, Org Roam 目录扫描完成")
                }

                NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 用户选择了 Org 目录将开始扫描目录并创建书签: \(url.path)")
            }
        }
    }
}
