import FMDB
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

            // 使用 DirectoryAccessManager 的 convertToRawPath 转换路径
            let rawPath = parent.accessManager.convertToRawPath(pendingPDFPath!)

            // 获取文件名（不含扩展名）
            let fileName = url.deletingPathExtension().lastPathComponent

            // 将文件信息写入数据库的 files 表
            insertFileToDatabase(rawPath: rawPath, title: fileName)

            NotificationCenter.default.post(
                name: Notification.Name("OpenSelectedPDF"),
                object: nil,
                userInfo: [
                    "pdfPath": pendingPDFPath!,
                    "currentPage": 1,
                ]
            )

            NSLog("✅ PDFPicker.swift -> PDFPicker.Coordinator.documentPicker, 用户选择了文件将打开: \(url.path)")
        }

        private func insertFileToDatabase(rawPath: String, title: String) {
            // 获取数据库路径
            let rootPath: String

            if let rootURL = parent.accessManager.rootDirectoryURL {
                rootPath = rootURL.path
            } else if let cachedPath = UserDefaults.standard.string(forKey: "LastSuccessfulRootPath") {
                rootPath = cachedPath
            } else {
                NSLog("❌ PDFPicker.swift -> PDFPicker.insertFileToDatabase, 无法获取根目录URL")

                return
            }

            let dbPath = URL(fileURLWithPath: rootPath).appendingPathComponent("pdf-annotations.db").path

            // 检查数据库文件是否存在
            guard FileManager.default.fileExists(atPath: dbPath) else {
                NSLog("❌ PDFPicker.swift -> PDFPicker.insertFileToDatabase, 数据库文件不存在: \(dbPath)")

                return
            }

            // 打开数据库并插入数据
            guard let dbQueue = FMDatabaseQueue(path: dbPath) else {
                NSLog("❌ PDFPicker.swift -> PDFPicker.insertFileToDatabase, 无法打开数据库: \(dbPath)")

                return
            }

            dbQueue.inDatabase { db in
                // 首先检查是否已存在相同的记录
                let checkSQL = "SELECT COUNT(*) FROM files WHERE file = ?"

                if let result = try? db.executeQuery(checkSQL, values: [rawPath]) {
                    if result.next() {
                        let count = result.int(forColumnIndex: 0)
                        result.close()

                        if count > 0 {
                            NSLog("✅ PDFPicker.swift -> PDFPicker.insertFileToDatabase, 文件已存在于数据库 files 表中，跳过插入: \(rawPath)")
                            return
                        }
                    } else {
                        result.close()
                    }
                }

                // 插入新记录
                let insertSQL = "INSERT INTO files (file, title) VALUES (?, ?)"
                if db.executeUpdate(insertSQL, withArgumentsIn: [rawPath, title]) {
                    NSLog("✅ PDFPicker.swift -> PDFPicker.insertFileToDatabase, 成功插入文件记录: title=\(title), file=\(rawPath)")
                } else {
                    NSLog("❌ PDFPicker.swift -> PDFPicker.insertFileToDatabase, 插入文件记录失败: \(db.lastErrorMessage())")
                }
            }

            dbQueue.close()
        }
    }
}
