import MobileCoreServices
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var convertedPdfPath: String = ""
    @State private var pdfURL: URL? = nil
    @State private var currentPage: Int = 1
    @State private var xRatio: Double = 0.0
    @State private var yRatio: Double = 0.0
    @State private var showDirectoryPicker = false
    @State private var showLinkInput = false
    @State private var linkText: String = ""
    @State private var rootFolderURL: URL? = UserDefaults.standard.url(forKey: "RootFolder")
    @State private var isPDFLoaded = false
    @State private var viewPoint: CGPoint = .zero
    @State private var pdfLoadError: String? = nil
    @State private var originalPathInput: String = UserDefaults.standard.string(forKey: "OriginalPath") ?? ""

    // 目录访问管理器
    @StateObject private var directoryManager = DirectoryAccessManager()

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) { VStack {
                if let url = pdfURL {
                    ZStack {
                        PDFKitView(
                            url: url,
                            page: currentPage,
                            xRatio: xRatio,
                            yRatio: yRatio,
                            isPDFLoaded: $isPDFLoaded,
                            viewPoint: $viewPoint
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .onAppear {
                            pdfLoadError = nil
                        }
                        .onChange(of: isPDFLoaded) { loaded in
                            if !loaded {
                                pdfLoadError = "无法加载PDF文件，请检查文件路径和权限"
                            }
                        }

                        // if isPDFLoaded {
                        //     ArrowAnnotationView(
                        //         viewPoint: viewPoint
                        //     )
                        // }
                    }
                    // 当显示PDF时，设置一个合适的最小高度
                    .frame(minHeight: UIScreen.main.bounds.height * 0.9)
                } else {
                    VStack(spacing: 20) {
                        if let rootURL = directoryManager.rootDirectoryURL {
                            Text("已选择根文件夹: \(rootURL.lastPathComponent)")
                                .padding()
                        }

                        Button(action: {
                            showDirectoryPicker = true
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("选择 PDF 根文件夹")
                            }
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }

                        // 显示扫描进度
                        ScanningProgressView(accessManager: directoryManager)

                        Divider()
                            .padding(.vertical, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            TextField("请输入原始路径", text: $originalPathInput)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        Button {
                            PathConverter.originalPath = originalPathInput
                            UserDefaults.standard.set(originalPathInput, forKey: "OriginalPath")
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("保存路径")
                            }
                        }
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        Divider()
                            .padding(.vertical, 8)

                        Button(action: {
                            showLinkInput = true
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("输入 NOTERPAGE 链接")
                            }
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }.padding()
                }

                // 显示错误信息
                if let error = pdfLoadError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            } // 确保内容填充整个屏幕宽度
            .frame(maxWidth: .infinity)
            }
            .navigationBarTitle("PDF 阅读器", displayMode: .inline)
            .navigationBarTitleDisplayMode(.automatic) // Change to automatic
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: shareLogs) {
                        Image(systemName: "archivebox")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showDirectoryPicker = true }) {
                        Image(systemName: "folder")
                          .padding(8) // Add padding
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showLinkInput = true }) {
                        Image(systemName: "link")
                            .padding(8) // Add padding
                    }
                }
            }.sheet(isPresented: Binding<Bool>(
                get: { showLinkInput || showDirectoryPicker },
                set: {
                    if !$0 {
                        showLinkInput = false
                        showDirectoryPicker = false
                    }
                }
            )) {
                Group {
                    if showLinkInput {
                        LinkInputView(linkText: $linkText, onSubmit: {
                            processMetanoteLink(linkText)
                            showLinkInput = false
                        })
                    } else {
                        DocumentPicker(accessManager: directoryManager)
                            .onAppear {
                                // 恢复之前保存的书签
                                NSLog("✅ ContentView.swift -> ContentView.body, 文件选择器 sheet 显示")
                            }
                            .onDisappear {
                                showDirectoryPicker = false

                                NSLog("❌ ContentView.swift -> ContentView.body, 文件选择器 sheet 不显示")
                            }
                    }
                }
            }
            .onAppear {
                directoryManager.restoreSavedBookmarks()
                setupNotifications()

                // 检查是否有待处理的 PDF 信息
                if let info = SceneDelegate.pendingPDFInfo {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenPDFNotification"),
                        object: nil,
                        userInfo: info
                    )

                    SceneDelegate.pendingPDFInfo = nil

                    NSLog("✅ ContentView.swift -> ContentView.body, 应用初始化完成后发送 OpenPDFNotification 通知")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .statusBar(hidden: false) // Force show status bar
        .ignoresSafeArea(.all, edges: .all) // Use full screen space
        .onAppear {
            // Lock orientation to portrait initially
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        .onDisappear {
            // Reset orientation lock
            UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
        }
    }

    private func setupNotifications() {
        // 使用与 SceneDelegate 相同的通知名称
        let notificationName = "OpenPDFNotification"

        // 先移除可能存在的旧观察者，避免重复注册
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(notificationName), object: nil)

        NSLog("✅ ContentView.swift -> ContentView.setupNotifications, 正在注册通知观察者: \(notificationName)")

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(notificationName),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let pdfPath = userInfo["pdfPath"] as? String,
                  let page = userInfo["page"] as? Int,
                  let xRatio = userInfo["xRatio"] as? Double,
                  let yRatio = userInfo["yRatio"] as? Double
            else {
                NSLog("❌ ContentView.swift -> ContentView.setupNotifications, OpenPDFNotification 获取通知参数失败")

                return
            }

            guard !PathConverter.originalPath.isEmpty else {
                pdfLoadError = "请先保存需要替换的 PDF 原始路径"

                return
            }

            self.convertedPdfPath = PathConverter.convertNoterPagePath(pdfPath, rootDirectoryURL: self.directoryManager.rootDirectoryURL)
            // self.pdfURL = URL(fileURLWithPath: self.convertedPdfPath)
            self.currentPage = page
            self.xRatio = xRatio
            self.yRatio = yRatio

            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenPDFNotification 通知参数 - 转换路径: \(self.convertedPdfPath), 页码: \(self.currentPage), Y: \(self.yRatio), X: \(self.xRatio)")
            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenPDFNotification 通知参数 - 文件路径: \(String(describing: self.pdfURL)), 页码: \(self.currentPage), Y: \(self.yRatio), X: \(self.xRatio)")

            openPDF(at: self.convertedPdfPath, currentPage: page, xRatio: xRatio, yRatio: yRatio)
        }
    }

    private func processMetanoteLink(_ link: String) {
        guard let result = PathConverter.parseNoterPageLink(link) else {
            NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无效的 Metanote 链接")

            return
        }

        guard !PathConverter.originalPath.isEmpty else {
            pdfLoadError = "请先保存需要替换的 PDF 原始路径"

            return
        }

        convertedPdfPath = PathConverter.convertNoterPagePath(result.pdfPath, rootDirectoryURL: directoryManager.rootDirectoryURL)
        // self.pdfURL = URL(fileURLWithPath: self.convertedPdfPath)
        currentPage = result.page!
        xRatio = result.x!
        yRatio = result.y!

        NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 转换路径: \(convertedPdfPath), 页码: \(currentPage), Y: \(yRatio), X: \(xRatio)")
        NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 文件路径: \(String(describing: pdfURL)), 页码: \(currentPage), Y: \(yRatio), X: \(xRatio)")

        openPDF(at: convertedPdfPath, currentPage: result.page!, xRatio: result.x!, yRatio: result.y!)
    }

    // 打开PDF文件的方法
    private func openPDF(at convertedPdfPath: String, currentPage: Int, xRatio: Double, yRatio: Double) {
        if let secureURL = directoryManager.startAccessingFile(at: convertedPdfPath) {
            pdfURL = secureURL
            self.currentPage = currentPage
            self.xRatio = xRatio
            self.yRatio = yRatio

            NSLog("✅ ContentView.swift -> ContentView.openPDF, 成功打开PDF文件: \(convertedPdfPath)")
        } else {
            pdfURL = nil
            pdfLoadError = "无法访问文件，请重新选择目录"

            NSLog("❌ ContentView.swift -> ContentView.openPDF, 无法访问文件: \(convertedPdfPath)")
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

// 添加一个新的视图用于输入链接
struct LinkInputView: View {
    @Binding var linkText: String
    var onSubmit: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $linkText)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding()

                Button("确定") {
                    onSubmit()
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .navigationBarTitle("输入链接", displayMode: .inline)
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }.onAppear {
            // 添加通知观察者
            setupURLNotificationObserver()

            // 检查是否有待处理的 PDF 信息
            if let info = SceneDelegate.decodedStringInfo {
                // 使用通知中心发送URL
                NotificationCenter.default.post(
                    name: Notification.Name("ReceivedURLNotification"),
                    object: nil,
                    userInfo: info
                )

                SceneDelegate.decodedStringInfo = nil

                NSLog("✅ ContentView.swift -> ContentView.body, 应用初始化完成后发送 ReceivedURLNotification 通知")
            }
        }
    }

    // 添加这个方法来设置通知观察者
    private func setupURLNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ReceivedURLNotification"),
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.userInfo?["decodedString"] as? String {
                self.linkText = url

                NSLog("✅ ContentView.swift -> LinkInputView.setupURLNotificationObserver, 已更新linkText为: \(url)")
            }
        }
    }
}
