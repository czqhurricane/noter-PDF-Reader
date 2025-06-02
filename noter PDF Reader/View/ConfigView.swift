import PDFKit
import SwiftUI

struct ConfigView: View {
    // 从 ContentView 转移的状态变量
    @Binding var originalPathInput: String
    @State private var deepSeekApiKey: String = UserDefaults.standard.string(forKey: "DeepSeekApiKey") ?? ""
    @State private var showDirectoryPicker = false
    @State private var isSharePresented: Bool = false
    @State private var logFileURL: URL? = nil
    @State private var isRebuildingIndex = false

    // 目录访问管理器
    @ObservedObject var directoryManager: DirectoryAccessManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PDF 文件设置")) {
                    // 显示根文件夹信息
                    if let rootURL = directoryManager.rootDirectoryURL {
                        HStack {
                            Text("当前根文件夹")
                            Spacer()
                            Text(rootURL.lastPathComponent)
                                .foregroundColor(.gray)
                        }
                    }

                    Button(action: {
                        showDirectoryPicker = true
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("选择 PDF 根文件夹")
                        }
                    }

                    // 显示扫描进度
                    ScanningProgressView(accessManager: directoryManager)
                }

                Section(header: Text("路径设置")) {
                    TextField("请输入原始路径", text: $originalPathInput)

                    Button(action: {
                        PathConverter.originalPath = originalPathInput
                        UserDefaults.standard.set(originalPathInput, forKey: "OriginalPath")
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存路径")
                        }
                    }
                }

                Section(header: Text("AI 设置")) {
                    SecureField("DeepSeek API Key", text: $deepSeekApiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button(action: {
                        UserDefaults.standard.set(deepSeekApiKey, forKey: "DeepSeekApiKey")
                    }) {
                        HStack {
                            Image(systemName: "key")
                            Text("保存 API Key")
                        }
                    }

                    Text("API Key 用于 DeepSeek 模型的访问，请妥善保管")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section(header: Text("PDF 文件夹搜索设置")) {
                    Button(action: {
                        rebuildSearchIndex()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重建索引")
                        }
                    }
                    .disabled(isRebuildingIndex)

                    if isRebuildingIndex {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在重建索引...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("重建索引完成")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("日志")) {
                    Button(action: {
                        prepareLogFile()
                        isSharePresented = true
                    }) {
                        HStack {
                            Image(systemName: "archivebox")
                            Text("导出日志")
                        }
                    }
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationBarTitle("设置", displayMode: .inline)
            .sheet(isPresented: $showDirectoryPicker) {
                DocumentPicker(accessManager: directoryManager)
            }
            // 使用 SwiftUI 的方式集成 UIActivityViewController
            .background(
                ActivityViewController(isPresented: $isSharePresented, activityItems: [logFileURL].compactMap { $0 })
            )
        }
    }

    // 准备日志文件
    private func prepareLogFile() {
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let logFile = docsDir.appendingPathComponent("noterPDFReaderDebug.log")

        // 创建一个临时文件（如果需要）
        if !FileManager.default.fileExists(atPath: logFile.path) {
            // 创建一个空的日志文件用于演示
            try? "Debug logs will appear here.".write(to: logFile, atomically: true, encoding: .utf8)
        }

        logFileURL = logFile
    }

    // 创建一个 UIViewControllerRepresentable 来包装 UIActivityViewController
    struct ActivityViewController: UIViewControllerRepresentable {
        @Binding var isPresented: Bool
        var activityItems: [Any]
        var applicationActivities: [UIActivity]? = nil

        func makeUIViewController(context _: Context) -> UIViewController {
            let controller = UIViewController()
            return controller
        }

        func updateUIViewController(_ uiViewController: UIViewController, context _: Context) {
            if isPresented && uiViewController.presentedViewController == nil {
                let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)

                // 设置完成回调
                activityVC.completionWithItemsHandler = { _, completed, _, error in
                    if let error = error {
                        NSLog("❌ ConfigView.swift -> ConfigView.ActivityViewController.updateUIViewController, 分享日志文件时出错: \(error.localizedDescription)")
                    } else if completed {
                        NSLog("✅ ConfigView.swift -> ConfigView.ActivityViewController.updateUIViewController, 日志文件分享成功")
                    } else {
                        NSLog("✅ ConfigView.swift -> ConfigView.ActivityViewController.updateUIViewController, 用户取消了日志文件分享")
                    }

                    // 关闭分享界面
                    self.isPresented = false
                }

                // 在 iPad 上设置弹出位置（如果适用）
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = uiViewController.view
                    popoverController.sourceRect = CGRect(x: uiViewController.view.bounds.width / 2, y: uiViewController.view.bounds.height / 2, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }

                uiViewController.present(activityVC, animated: true)
            }
        }
    }

    // 重建搜索索引
    private func rebuildSearchIndex() {
        isRebuildingIndex = true

        DispatchQueue.global(qos: .userInitiated).async {
            // 获取FileBookmarks
            guard let fileBookmarks = UserDefaults.standard.dictionary(forKey: "FileBookmarks") as? [String: Data] else {
                DispatchQueue.main.async {
                    self.isRebuildingIndex = false
                }
                return
            }

            // 获取LastSelectedDirectory
            guard let lastSelectedDirectoryString = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
                  let lastSelectedDirectoryURL = URL(string: lastSelectedDirectoryString)
            else {
                DispatchQueue.main.async {
                    self.isRebuildingIndex = false
                }
                return
            }

            // 创建Cache目录
            let cacheDirectory = lastSelectedDirectoryURL.appendingPathComponent("Cache")
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)

            // 遍历所有PDF文件
            for (filePath, bookmarkData) in fileBookmarks {
                if filePath.lowercased().hasSuffix(".pdf") {
                    autoreleasepool {
                        // 检查是否已存在对应的txt文件
                        if !self.txtFileExists(for: filePath, in: cacheDirectory) {
                            self.processPDFFile(filePath: filePath, bookmarkData: bookmarkData, cacheDirectory: cacheDirectory)
                        } else {
                            NSLog("✅ ConfigView.swift -> ConfigView.rebuildSearchIndex, 跳过已存在的索引文件: \(filePath)")
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.isRebuildingIndex = false

                NSLog("✅ ConfigView.swift -> ConfigView.rebuildSearchIndex, 索引重建完成")
            }
        }
    }

    // 处理单个PDF文件
    private func processPDFFile(filePath: String, bookmarkData: Data, cacheDirectory: URL) {
        do {
            // 从书签恢复URL
            var isStale = false
            let fileURL = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)

            // 开始访问安全范围资源
            let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            // 创建PDFDocument
            guard let pdfDocument = PDFDocument(url: fileURL) else {
                NSLog("❌ ConfigView.swift -> processPDFFile, 无法打开PDF文件: \(filePath)")

                return
            }

            var textLines: [String] = []

            // 遍历每一页
            for pageIndex in 0 ..< pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: pageIndex) else { continue }

                let pageText = page.string ?? ""
                let lines = pageText.components(separatedBy: "\n")

                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine.count > 1 {
                        textLines.append("\(pageIndex + 1): \(trimmedLine)")
                    }
                }
            }

            // 保存到txt文件
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let txtFileURL = cacheDirectory.appendingPathComponent("\(fileName).txt")
            let content = textLines.joined(separator: "\n")

            try content.write(to: txtFileURL, atomically: true, encoding: .utf8)

            NSLog("✅ ConfigView.swift -> ConfigView.processPDFFile, 成功创建索引文件: \(txtFileURL.path)")
        } catch {
            NSLog("❌ ConfigView.swift -> ConfigView.processPDFFile, 处理PDF文件失败: \(error.localizedDescription)")
        }
    }

    // 检查txt文件是否已存在的辅助方法
    private func txtFileExists(for pdfFilePath: String, in cacheDirectory: URL) -> Bool {
        let fileName = URL(fileURLWithPath: pdfFilePath).deletingPathExtension().lastPathComponent
        let txtFileURL = cacheDirectory.appendingPathComponent("\(fileName).txt")
        return FileManager.default.fileExists(atPath: txtFileURL.path)
    }
}

// 预览
struct ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigView(
            originalPathInput: .constant("原始路径"),
            directoryManager: DirectoryAccessManager.shared
        )
    }
}
