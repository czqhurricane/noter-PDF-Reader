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

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 用户选择了目录将开始扫描目录并创建书签: \(url.path)")

            // 开始扫描目录并创建书签
            parent.accessManager.scanDirectory(at: url)
        }
    }
}

// 扫描进度视图
struct ScanningProgressView: View {
    @ObservedObject var accessManager: DirectoryAccessManager

    var body: some View {
        VStack {
            if accessManager.isScanning {
                ProgressView("正在扫描目录...", value: accessManager.scanningProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()

                Text(String(format: "进度: %.1f%%", accessManager.scanningProgress * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let error = accessManager.errorMessage {
                Text("错误: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else if accessManager.rootDirectoryURL != nil {
                Text("目录扫描完成")
                    .foregroundColor(.green)
                    .padding()
            }
        }
    }
}
