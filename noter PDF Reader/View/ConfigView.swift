import SwiftUI

struct ConfigView: View {
    // 从 ContentView 转移的状态变量
    @Binding var originalPathInput: String
    @State private var deepSeekApiKey: String = UserDefaults.standard.string(forKey: "DeepSeekApiKey") ?? ""
    @State private var showDirectoryPicker = false

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

                Section(header: Text("日志")) {
                    Button(action: shareLogs) {
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
        }
    }

    private func shareLogs() {
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let logFile = docsDir.appendingPathComponent("noterPDFReaderDebug.log")

        // 创建一个临时文件（如果需要）
        if !FileManager.default.fileExists(atPath: logFile.path) {
            // 创建一个空的日志文件用于演示
            try? "Debug logs will appear here.".write(to: logFile, atomically: true, encoding: .utf8)
        }

        // 使用 UIActivityViewController 来分享文件
        let activityVC = UIActivityViewController(activityItems: [logFile], applicationActivities: nil)

        // 设置完成回调
        activityVC.completionWithItemsHandler = { activityType, completed, _, error in
            if let error = error {
                NSLog("❌ ContentView.swift -> ContentView.shareLog, 分享日志文件时出错: \(error.localizedDescription)")
                return
            }

            if completed {
                NSLog("✅ ContentView.swift -> ContentView.shareLogs, 日志文件分享成功，活动类型: \(String(describing: activityType))")
            } else {
                NSLog("✅ ContentView.swift -> ContentView.shareLogs, 用户取消了日志文件分享")
            }
        }

        // 在 iPad 上设置弹出位置（如果适用）
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = UIApplication.shared.windows.first
            popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        // 显示分享界面
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController
        else {
            return
        }

        rootVC.present(activityVC, animated: true)
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
