import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var accessManager: DirectoryAccessManager

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 支持选择文件夹和 PDF 文件
        let contentTypes = [UTType.folder, UTType.pdf]

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
                parent.accessManager.scanDirectory(at: url){
                    NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 目录扫描完成")
                }
                NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 用户选择了目录将开始扫描目录并创建书签: \(url.path)")
            } else {
                NSLog("✅ DocumentPicker.swift -> DocumentPicker.Coordinator.documentPicker, 用户选择了文件将开始扫描所在目录并创建书签: \(url.path)")

                // 保存待打开的PDF路径
                pendingPDFPath = url.path

                // 开始扫描目录
                let directoryURL = url.deletingLastPathComponent()
                parent.accessManager.scanDirectory(at: directoryURL) {
                    // 扫描完成后直接执行打开 PDF 的操作
                    NotificationCenter.default.post(
                        name: Notification.Name("OpenSelectedPDF"),
                        object: nil,
                        userInfo: [
                            "pdfPath": self.pendingPDFPath,
                            "currentPage": 1,
                            "xRatio": 0.5,
                            "yRatio": 0.5,
                        ]
                    )
                }
            }
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
                    .foregroundColor(.primary)
                    .padding()
            }
        }
    }
}
