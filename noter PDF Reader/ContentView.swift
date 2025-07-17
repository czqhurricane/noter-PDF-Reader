import MobileCoreServices
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var rawPdfPath: String = ""
    @State private var convertedPdfPath: String = ""
    @State private var pdfURL: URL? = nil
    @State private var currentPage: Int = 1
    @State private var xRatio: Double = 0.0
    @State private var yRatio: Double = 0.0
    @State private var showAnnotationsSheet = false // 显示保存的注释列表视图
    @State private var showFolderSearchSheet = false
    @State private var showOutlines = false // 显示 PDF 目录
    @State private var showSearchSheet = false // 显示 PDF 全文搜索 sheet
    @State private var showPDFPicker = false
    @State private var showLinkInputSheet = false
    @State private var showChatSheet = false
    @State private var showConfigSheet = false
    @State private var linkText: String = ""
    @State private var rootFolderURL: URL? = UserDefaults.standard.url(forKey: "RootFolder")
    @State private var isPDFLoaded = false
    @State private var viewPoint: CGPoint = .zero // 用于传递箭头图层坐标至 ArrowAnnotationView
    @State private var pdfLoadError: String? = nil
    @State private var originalPathInput: String = UserDefaults.standard.string(forKey: "OriginalPath") ?? ""
    @State private var annotation: String = "" // 存储用户输入的注释
    @State private var isLocationMode = false // 是否添加注释的状态变量
    @State private var forceRender = true
    @State private var pdfDocument: PDFDocument?
    @State private var selectedSearchSelection: String? = nil // 跟踪当前选中的搜索结果
    @State private var textToProcess = ""
    @State private var autoSendMessage = false
    @State private var occlusionImage: UIImage? = nil // State to hold the captured image
    @State private var occlusionSource: String = ""
    @State private var pdfViewCoordinator: PDFKitView.Coordinator? // To call coordinator methods
    @State private var shouldNavigateToOcclusion = false // Occlusion 导航状态
    @State private var toolbarScrollOffset: CGFloat = 0
    @State private var shouldShowArrow = true
    @State private var selectedFolderSearchText: String? = nil // 跟踪文件夹搜索的高亮文本
    @State private var showPlayerSheet = false
    @State private var localVideoUrl: URL? = UserDefaults.standard.url(forKey: "LocalVideoUrl")
    @State private var startTime: Double = 0.0
    @State private var endTime: Double = 0.0

    @StateObject private var directoryManager = DirectoryAccessManager.shared // 目录访问管理器
    @StateObject var annotationListViewModel = AnnotationListViewModel()

    @ViewBuilder
    private var pdfDisplaySection: some View {
        if let url = pdfURL {
            ZStack {
                PDFKitView(
                    url: url,
                    page: currentPage,
                    xRatio: xRatio,
                    yRatio: yRatio,
                    isLocationMode: isLocationMode, // 传递注释模式状态
                    rawPdfPath: rawPdfPath,
                    showOutlines: showOutlines,
                    shouldShowArrow: shouldShowArrow,
                    coordinatorCallback: { coordinator in
                        self.pdfViewCoordinator = coordinator
                    }, // 传递一个回调函数以获取协调器实例
                    isPDFLoaded: $isPDFLoaded,
                    viewPoint: $viewPoint,
                    annotation: $annotation,
                    forceRender: $forceRender,
                    pdfDocument: $pdfDocument,
                    selectedSearchSelection: $selectedSearchSelection,
                    selectedFolderSearchText: $selectedFolderSearchText,
                    showChatSheet: $showChatSheet,
                    textToProcess: $textToProcess,
                    autoSendMessage: $autoSendMessage,
                    source: $occlusionSource
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onAppear {
                    pdfLoadError = nil
                }
                .onChange(of: isPDFLoaded) { loaded in
                    DispatchQueue.main.async {
                        if !loaded {
                            self.pdfLoadError = "PDFKitView 无法加载 PDF 文件，请检查文件路径和权限"
                        }
                    }
                }
                locationModeOverlay
            }
            .frame(minHeight: UIScreen.main.bounds.height * 0.9) // 当显示PDF时，设置一个合适的最小高度
        }
    }

    private var locationModeOverlay: some View {
        Group {
            if isLocationMode {
                VStack {
                    Spacer()
                    Text("请点击PDF上的位置来放置箭头")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private var mainContentSection: some View {
        VStack {
            if pdfURL != nil {
                pdfDisplaySection
            }
        }
    }

    private var errorSection: some View {
        Group {
            if let error = pdfLoadError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private var anySheetBinding: Binding<Bool> {
        Binding<Bool>(
            get: { showConfigSheet || showAnnotationsSheet || showFolderSearchSheet || showChatSheet || showSearchSheet || showPDFPicker || showLinkInputSheet || showPlayerSheet },
            set: {
                if !$0 {
                    showConfigSheet = false
                    showAnnotationsSheet = false
                    showFolderSearchSheet = false
                    showChatSheet = false
                    showSearchSheet = false
                    showPDFPicker = false
                    showLinkInputSheet = false
                    showPlayerSheet = false
                }
            }
        )
    }

    // 创建可滑动的工具栏视图
    private var scrollableToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // 左侧按钮组
                Button(action: {
                    showConfigSheet = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.primary)
                }

                Button(action: {
                    showAnnotationsSheet = true
                }) {
                    Image(systemName: "note.text")
                        .foregroundColor(.primary)
                }

                Button(action: {
                    showFolderSearchSheet = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.primary)
                }

                Button(action: {
                    showChatSheet = true
                }) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(.primary)
                }

                // PDF 相关按钮（仅在 PDF 加载时显示）
                if let _ = pdfURL {
                    Button(action: {
                        showOutlines = true
                    }) {
                        Image(systemName: "list.bullet.indent")
                            .foregroundColor(.primary)
                    }

                    Button(action: {
                        isLocationMode.toggle()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(isLocationMode ? .blue : .primary)
                    }

                    Button(action: {
                        showSearchSheet = true
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.primary)
                    }

                    Button(action: {
                        self.occlusionImage = pdfViewCoordinator?.captureCurrentPageAsImage()
                        if self.occlusionImage != nil {
                            shouldNavigateToOcclusion = true
                        } else {
                            NSLog("❌ ContentView.swift -> ContentView.body, Failed to capture image for OcclusionView")
                        }
                    }) {
                        Image(systemName: "rectangle.slash")
                            .foregroundColor(.primary)
                    }
                }

                Button(action: {
                    showPDFPicker = true
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(.primary)
                }

                Button(action: {
                    showLinkInputSheet = true
                }) {
                    Image(systemName: "link")
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
        .background(Color(UIColor.systemBackground))
        .overlay(
            // 添加左右渐变指示器
            HStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.1), Color.clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)

                Spacer()

                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.1)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
            }
            .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private var configSheetContent: some View {
        ConfigView(
            originalPathInput: $originalPathInput,
            directoryManager: directoryManager
        )
    }

    @ViewBuilder
    private var annotationsSheetContent: some View {
        // 传递同一个 ViewModel 实例到 AnnotationListView
        AnnotationListViewWrapper(viewModel: annotationListViewModel)
    }

    @ViewBuilder
    private var folderSearchSheetContent: some View {
        NavigationView {
            PDFFolderSearchView { filePath, pageNumber, context in
                // 提取搜索的关键词用于高亮
                selectedFolderSearchText = extractSearchKeyword(from: context)
                // 打开指定的PDF文件并跳转到指定页面
                openPDF(at: filePath, page: pageNumber, xRatio: xRatio, yRatio: yRatio, showArrow: false)
                showFolderSearchSheet = false
            }
        }
    }

    @ViewBuilder
    private var chatSheetContent: some View {
        ChatView(initialText: textToProcess, autoSend: autoSendMessage)
    }

    @ViewBuilder
    private var searchSheetContent: some View {
        NavigationView {
            PDFSearchView(pdfDocument: $pdfDocument) { filePath, pageNumber, context in
                // 更新选中的搜索结果
                selectedSearchSelection = extractSearchKeyword(from: context)
                // 打开指定的PDF文件并跳转到指定页面
                openPDF(at: filePath, page: pageNumber, xRatio: xRatio, yRatio: yRatio, showArrow: false)
                // 立即关闭搜索sheet
                showSearchSheet = false
            }
        }
    }

    @ViewBuilder
    private var occlusionSheetContent: some View {
        OcclusionView(image: occlusionImage, source: occlusionSource)
    }

    @ViewBuilder
    private var pdfPickerSheetContent: some View {
        PDFPicker(accessManager: directoryManager)
            .onAppear {
                NSLog("✅ ContentView.swift -> ContentView.body, PDF 选择器 sheet 显示")
            }
    }

    @ViewBuilder
    private var linkInputSheetContent: some View {
        LinkInputView(linkText: $linkText, onSubmit: {
            let shouldDismiss = processMetanoteLink(linkText)
            return shouldDismiss
        })
    }

    @ViewBuilder
    private var videoPlayerSheetContent: some View {
        VideoPlayerView(videoURL: localVideoUrl!, startTime: startTime, endTime: endTime)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 自定义可滑动工具栏
                scrollableToolbar

                ScrollView(.vertical, showsIndicators: true) {
                    mainContentSection
                    errorSection

                    // 添加隐藏的 NavigationLink
                    NavigationLink(
                        destination: OcclusionView(image: occlusionImage, source: occlusionSource),
                        isActive: $shouldNavigateToOcclusion
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                .frame(maxWidth: .infinity) // 确保内容填充整个屏幕宽度
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarHidden(true) // 隐藏原始导航栏
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showConfigSheet = true // 显示配置 sheet
                    }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showAnnotationsSheet = true // 显示保存的注释 sheet
                    }) {
                        Image(systemName: "note.text")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showFolderSearchSheet = true
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showChatSheet = true // 显示 Chat sheet
                    }) {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let _ = pdfURL {
                            Button(action: {
                                showOutlines = true // 显示目录模式
                            }) {
                                Image(systemName: "list.bullet.indent")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let _ = pdfURL {
                            Button(action: {
                                isLocationMode.toggle() // 切换注释模式
                            }) {
                                Image(systemName: "square.and.pencil")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let _ = pdfURL {
                            Button(action: {
                                showSearchSheet = true // 显示 PDF 全文搜索 sheet
                            }) {
                                Image(systemName: "doc.text.magnifyingglass")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let _ = pdfURL {
                            Button(action: {
                                // Capture the image before showing the sheet
                                self.occlusionImage = pdfViewCoordinator?.captureCurrentPageAsImage()
                                if self.occlusionImage != nil {
                                    shouldNavigateToOcclusion = true // 触发导航
                                } else {
                                    NSLog("❌ ContentView.swift -> ContentView.body, Failed to capture image for OcclusionView")
                                }
                            }) {
                                Image(systemName: "rectangle.slash")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showPDFPicker = true // 显示 PDFPicker sheet
                    }) {
                        Image(systemName: "folder")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showLinkInputSheet = true }) { // 显示 LinkInput sheet
                        Image(systemName: "link")
                    }
                }
            }.sheet(isPresented: anySheetBinding) {
                Group {
                    if showConfigSheet {
                        configSheetContent
                    } else if showAnnotationsSheet {
                        annotationsSheetContent
                    } else if showFolderSearchSheet {
                        folderSearchSheetContent
                    } else if showChatSheet {
                        chatSheetContent
                    } else if showSearchSheet {
                        searchSheetContent
                    } else if showPDFPicker {
                        pdfPickerSheetContent
                    } else if showLinkInputSheet {
                        linkInputSheetContent
                    } else if showPlayerSheet {
                        videoPlayerSheetContent
                    }
                }
            }
            .onAppear {
                directoryManager.restoreSavedBookmarks()

                setupNotifications()
                // 检查是否有待处理的 PDF 信息
                if let pendingPDFInfo = SceneDelegate.pendingPDFInfo {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenPDFNotification"),
                        object: nil,
                        userInfo: pendingPDFInfo
                    )

                    SceneDelegate.pendingPDFInfo = nil

                    NSLog("✅ ContentView.swift -> ContentView.body, 应用初始化完成后发送 OpenPDFNotification 通知")
                }

                if let pendingVideoInfo = SceneDelegate.pendingVideoInfo {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenVideoNotification"),
                        object: nil,
                        userInfo: pendingVideoInfo
                    )

                    SceneDelegate.pendingVideoInfo = nil

                    NSLog("✅ ContentView.swift -> ContentView.body, 应用初始化完成后发送 OpenVideoNotification 通知")
                }

                // 初始锁定屏幕方向为竖屏
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")

                // 确保数据库已打开
                if let rootURL = directoryManager.rootDirectoryURL {
                    let dbPath = rootURL.appendingPathComponent("pdf-annotations.db").path
                    let _ = DatabaseManager.shared.openDatabase(with: directoryManager, at: dbPath)
                }
            }.onDisappear {
                // 重置方向锁定
                UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .statusBar(hidden: false)
        .ignoresSafeArea(.all, edges: .all) // 使用全屏空间
    }

    private func setupNotifications() {
        // 使用与 SceneDelegate 和 AnnotationListView 相同的通知名称
        let openPDFNotification = NSNotification.Name("OpenPDFNotification")
        let loadAnnotationsDatabaseNotification = NSNotification.Name("LoadAnnotationsDatabase")
        let openVideoNotification = NSNotification.Name("OpenVideoNotification")

        // 先移除可能存在的旧观察者，避免重复注册
        NotificationCenter.default.removeObserver(self, name: openPDFNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: loadAnnotationsDatabaseNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: openVideoNotification, object: nil)

        NSLog("✅ ContentView.swift -> ContentView.setupNotifications, 正在注册通知观察者: \(openPDFNotification)")
        NSLog("✅ ContentView.swift -> ContentView.setupNotifications, 正在注册通知观察者: \(loadAnnotationsDatabaseNotification)")
        NSLog("✅ ContentView.swift -> ContentView.setupNotifications, 正在注册通知观察者: \(openVideoNotification)")

        // 监听 sceneDelegate 和 AnnotationListView 的打开私有协议链接的通知
        NotificationCenter.default.addObserver(
            forName: openPDFNotification,
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

            self.rawPdfPath = pdfPath
            self.convertedPdfPath = PathConverter.convertNoterPagePath(pdfPath, rootDirectoryURL: self.directoryManager.rootDirectoryURL)
            self.currentPage = page
            self.xRatio = xRatio
            self.yRatio = yRatio

            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenPDFNotification 通知参数 - 转换路径: \(self.convertedPdfPath), 页码: \(self.currentPage), yRatio: \(self.yRatio), xRatio: \(self.xRatio)")
            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenPDFNotification 通知参数 - 文件路径: \(String(describing: self.pdfURL)), 页码: \(self.currentPage), yRatio: \(self.yRatio), xRatio: \(self.xRatio)")

            openPDF(at: self.convertedPdfPath, page: page, xRatio: xRatio, yRatio: yRatio, showArrow: true)
        }

        // 监听数据库加载通知
        NotificationCenter.default.addObserver(
            forName: loadAnnotationsDatabaseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let dataBasePath = userInfo["dataBasePath"] as? String
            else {
                NSLog("❌ ContentView.swift -> ContentView.setupNotifications, LoadAnnotationsDatabase 通知中缺少数据库路径")

                return
            }

            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, LoadAnnotationsDatabase 收到加载数据库通知，数据库路径：\(dataBasePath)")

            annotationListViewModel.loadAnnotationsFromDatabase(dataBasePath)
        }

        // 监听目录视图关闭通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateShowOutlines"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let showOutlinesValue = userInfo["showOutlines"] as? Bool
            {
                NSLog("✅ ContentView.swift -> ContentView.setupNotifications, UpdateShowOutlines 接收到通知")

                self.showOutlines = showOutlinesValue
            }
        }

        // 监听 PDFPicker 的打开选中 PDF 通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OpenSelectedPDF"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let pdfPath = userInfo["pdfPath"] as? String,
                  let currentPage = userInfo["currentPage"] as? Int
            else {
                return
            }

            rawPdfPath = self.convertToRawPath(pdfPath)

            // 查询数据库中的最后访问页面
            let lastVisitedPage = DatabaseManager.shared.getLastVisitedPage(pdfPath: rawPdfPath) ?? currentPage

            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenSelectedPDF 观察者, 接收到打开 PDF 请求，原始路径: \(pdfPath), 反转换路径: \(rawPdfPath)，最后访问页面号：\(lastVisitedPage)")

            openPDF(at: pdfPath, page: lastVisitedPage, xRatio: xRatio, yRatio: yRatio, showArrow: false)
        }

        // 监听 SceneDelegate 的打开 Video 通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OpenVideoNotification"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let localVideoPath = userInfo["localVideoPath"] as? String,
                  let startTime = userInfo["startTime"] as? Double,
                  let endTime = userInfo["endTime"] as? Double
            else {
                NSLog("❌ ContentView.swift -> ContentView.setupNotifications, OpenVideoNotification 获取通知参数失败")

                return
            }

            if let secureURL = directoryManager.startAccessingFile(at: localVideoPath) {
                self.localVideoUrl = secureURL
                // 使用我们的 VideoPlayerView 打开
                let videoPlayerView = VideoPlayerView(videoURL: secureURL, startTime: startTime, endTime: endTime)
                let hostingController = UIHostingController(rootView: videoPlayerView)
                UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)

                NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenVideoNotification 观察者, 接收到打开 Video 请求，本地视频 URL: \(localVideoUrl), 开始时间: \(startTime)秒，结束时间：\(endTime)秒")

                // 在处理视频链接时，创建并保存书签
                do {
                    let bookmark = try localVideoUrl!.bookmarkData(options: .minimalBookmark,
                                                                   includingResourceValuesForKeys: nil,
                                                                   relativeTo: nil)
                    directoryManager.bookmarks[localVideoUrl!.path] = bookmark
                    // 可选：保存到数据库或 UserDefaults
                } catch {
                    NSLog("❌ ContentView.swift -> ContentView.setupNotifications, OpenVideoNotification, 无法为视频文件创建书签: \(error.localizedDescription)")
                }
            } else {
                // 处理无法获取访问权限的情况
                NSLog("❌ ContentView.swift -> ContentView.setupNotifications, OpenVideoNotification, 无法获取视频文件的安全访问权限")
            }
        }
    }

    private func processMetanoteLink(_ link: String) -> Bool {
        var endSeconds: Double = 0.0

        if let idResult = PathConverter.parseIdLink(link) {
            // 获取 org-roam 目录
            guard let orgRoamDirectoryURL = directoryManager.orgRoamDirectoryURL else {
                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, org-roam 目录未设置")

                return false
            }

            // 构建 org-roam.db 路径
            let orgRoamDBPath = orgRoamDirectoryURL.appendingPathComponent("org-roam.db").path

            // 检查数据库文件是否存在
            guard FileManager.default.fileExists(atPath: orgRoamDBPath) else {
                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, org-roam.db 数据库文件不存在: \(orgRoamDBPath)")

                return false
            }

            // 查询文件路径
            guard let filePath = DatabaseManager.shared.getFilePathByNodeId("\"\(idResult)\"", orgRoamDBPath: orgRoamDBPath) else {
                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 未找到节点对应的文件路径: \(idResult)")

                return false
            }

            // 从文件路径中提取文件名（去除双引号）
            let cleanedFilePath = filePath.trimmingCharacters(in: .init(charactersIn: "\""))
            let fileName = URL(fileURLWithPath: cleanedFilePath).lastPathComponent

            NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 提取到文件名: \(fileName)")

            // 在 orgRoamDirectoryURL 中递归搜索文件
            guard let fileURL = directoryManager.findFileInDirectory(fileName: fileName, directory: orgRoamDirectoryURL) else {
                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 在目录中未找到文件: \(fileName)")

                return false
            }

            if let secureURL = directoryManager.startAccessingFile(at: fileURL.path) {
                // 使用 iOS 系统推荐的方式打开文件
                DispatchQueue.main.async {
                    UIApplication.shared.open(fileURL, options: [:]) { success in
                        if success {
                            NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 成功打开文件: \(fileURL.path)")
                        } else {
                            NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无法打开文件: \(fileURL.path)")
                        }
                    }
                }

                return true
            } else {
                // 处理无法获取访问权限的情况
                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无法获取 org 文件的安全访问权限")

                return false
            }
        }

        // 首先，尝试将其解析为视频链接
        if let videoResult = PathConverter.parseVideoLink(link) {
            // 我们有一个视频链接：在外部打开视频网址
            let videoUrlString = videoResult.videoUrlString
            if videoUrlString.hasPrefix("http") {
                if let videoUrl = URL(string: videoUrlString) {
                    UIApplication.shared.open(videoUrl, options: [:], completionHandler: nil)

                    NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 网络视频链接: \(videoUrl)")
                }

                // 关闭当前 sheet
                return true
            } else if videoUrlString.hasPrefix("/") {
                let result = PathConverter.convertNoterPagePath(videoUrlString, rootDirectoryURL: directoryManager.rootDirectoryURL)
                let end = videoResult.end
                if let endTimeString = end?.trimmingCharacters(in: .whitespacesAndNewlines), let endTimeValue = convertTimeToSeconds(endTimeString) {
                    endSeconds = Double(endTimeValue)
                }

                // 解析时间参数
                if result.contains("?t=") {
                    let components = result.components(separatedBy: "?t=")
                    if components.count > 1, let startTimeValue = components.last, let startSeconds = Double(startTimeValue) {
                        // 先关闭当前sheet，然后在下一个UI周期显示视频播放器
                        showLinkInputSheet = false

                        // 使用 DispatchQueue.main.async 确保在当前 sheet 关闭后再显示视频播放器
                        DispatchQueue.main.async {
                            self.startTime = startSeconds
                            self.endTime = endSeconds
                            // 在显示视频播放器前，使用 DirectoryAccessManager 获取安全访问权限
                            if let secureURL = directoryManager.startAccessingFile(at: components[0]) {
                                self.localVideoUrl = secureURL
                                self.showPlayerSheet = true

                                // 在处理视频链接时，创建并保存书签
                                do {
                                    let bookmark = try localVideoUrl!.bookmarkData(options: .minimalBookmark,
                                                                                   includingResourceValuesForKeys: nil,
                                                                                   relativeTo: nil)
                                    directoryManager.bookmarks[localVideoUrl!.path] = bookmark
                                    // 可选：保存到数据库或 UserDefaults
                                } catch {
                                    NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无法为视频文件创建书签: \(error.localizedDescription)")
                                }
                            } else {
                                // 处理无法获取访问权限的情况
                                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无法获取视频文件的安全访问权限")
                            }

                            NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 本地视频 path: \(components[0])，本地视频 URL: \(String(describing: localVideoUrl)), 开始时间: \(String(describing: startSeconds))秒，结束时间: \(String(describing: endSeconds))秒")
                        }

                        // 不在这里关闭 sheet，让系统自动处理
                        return false
                    }
                } else {
                    showLinkInputSheet = false

                    DispatchQueue.main.async {
                        self.startTime = 0
                        self.endTime = 0
                        // 在显示视频播放器前，使用 DirectoryAccessManager 获取安全访问权限
                        if let secureURL = directoryManager.startAccessingFile(at: result.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            self.localVideoUrl = secureURL
                            self.showPlayerSheet = true

                            // 在处理视频链接时，创建并保存书签
                            do {
                                let bookmark = try localVideoUrl!.bookmarkData(options: .minimalBookmark,
                                                                               includingResourceValuesForKeys: nil,
                                                                               relativeTo: nil)
                                directoryManager.bookmarks[localVideoUrl!.path] = bookmark
                                // 可选：保存到数据库或 UserDefaults
                            } catch {
                                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无法为视频文件创建书签: \(error.localizedDescription)")
                            }
                        } else {
                            // 处理无法获取访问权限的情况
                            NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无法获取视频文件的安全访问权限")
                        }
                    }

                    // 不在这里关闭 sheet，让系统自动处理
                    return false
                }

            } else {
                NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无效的视频链接: \(videoUrlString)")
            }

            return true
        }

        guard let result = PathConverter.parseNoterPageLink(link) else {
            NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无效的 Metanote 链接")

            return true
        }

        guard !PathConverter.originalPath.isEmpty else {
            pdfLoadError = "请先保存需要替换的 PDF 原始路径"

            return true
        }

        rawPdfPath = result.pdfPath
        convertedPdfPath = PathConverter.convertNoterPagePath(rawPdfPath, rootDirectoryURL: directoryManager.rootDirectoryURL)
        currentPage = result.page!
        xRatio = result.x!
        yRatio = result.y!

        NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 转换路径: \(convertedPdfPath), 页码: \(currentPage), yRatio: \(yRatio), xRatio: \(xRatio)")
        NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 文件路径: \(String(describing: pdfURL)), 页码: \(currentPage), yRatio: \(yRatio), xRatio: \(xRatio)")

        openPDF(at: convertedPdfPath, page: result.page!, xRatio: result.x!, yRatio: result.y!, showArrow: true)

        return true // 默认关闭当前sheet
    }

    // 将时间格式（如 0:12:15）转换为秒数
    private func convertTimeToSeconds(_ timeString: String) -> Int? {
        let components = timeString.components(separatedBy: ":")
        var seconds = 0

        if components.count == 3 { // 格式为 h:m:s
            if let hours = Int(components[0]),
               let minutes = Int(components[1]),
               let secs = Int(components[2])
            {
                seconds = hours * 3600 + minutes * 60 + secs
            } else {
                return nil
            }
        } else if components.count == 2 { // 格式为 m:s
            if let minutes = Int(components[0]),
               let secs = Int(components[1])
            {
                seconds = minutes * 60 + secs
            } else {
                return nil
            }
        } else if components.count == 1 { // 格式为 s
            if let secs = Int(components[0]) {
                seconds = secs
            } else {
                return nil
            }
        } else {
            return nil
        }

        return seconds
    }

    // 打开PDF文件的方法
    private func openPDF(at convertedPdfPath: String, page: Int, xRatio: Double, yRatio: Double, showArrow: Bool) {
        if let secureURL = directoryManager.startAccessingFile(at: convertedPdfPath) {
            pdfURL = secureURL
            rawPdfPath = convertToRawPath(convertedPdfPath)
            currentPage = page
            self.xRatio = xRatio
            self.yRatio = yRatio
            forceRender = true
            shouldShowArrow = showArrow

            // 保存PDF访问记录到数据库
            let _ = DatabaseManager.shared.saveLastVisitedPage(pdfPath: rawPdfPath, page: page)

            NSLog("✅ ContentView.swift -> ContentView.openPDF, 即将打开 PDF 文件: \(convertedPdfPath)")
        } else {
            pdfURL = nil
            pdfLoadError = "无法访问文件，请在“设置 -> PDF 文件设置”中选择 PDF 根文件夹"

            NSLog("❌ ContentView.swift -> ContentView.openPDF, 无法访问文件: \(convertedPdfPath)")
        }
    }

    private func convertToRawPath(_ path: String) -> String {
        // 获取当前的 rootDirectoryURL
        let rootPath: String

        if let rootURL = directoryManager.rootDirectoryURL {
            rootPath = rootURL.path
        } else if let cachedPath = UserDefaults.standard.string(forKey: "LastSuccessfulRootPath") {
            rootPath = cachedPath
        } else {
            return path // 无法转换，返回原始路径
        }

        // 获取原始路径
        var processedOriginalPath = PathConverter.originalPath
        if processedOriginalPath.hasSuffix("/") {
            processedOriginalPath.removeLast()
        }

        // 执行反向替换
        return path.replacingOccurrences(of: rootPath, with: processedOriginalPath)
    }

    // 提取搜索关键词的辅助方法
    private func extractSearchKeyword(from context: String) -> String {
        // 从 context 中提取页码后的文本作为搜索关键词
        if let colonIndex = context.firstIndex(of: ":") {
            let textAfterColon = String(context[context.index(after: colonIndex)...])
            return textAfterColon.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return context
    }
}

// 包装器视图，用于传递 ViewModel
struct AnnotationListViewWrapper: View {
    @ObservedObject var viewModel: AnnotationListViewModel

    var body: some View {
        AnnotationListView()
            .environmentObject(viewModel)
    }
}
