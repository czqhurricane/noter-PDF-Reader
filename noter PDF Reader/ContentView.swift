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
    @State private var showOutlines = false // 显示 PDF 目录
    @State private var showSearchSheet = false // 显示 PDF 全文搜索 sheet
    @State private var showPDFPicker = false
    @State private var showLinkInputSheet = false
    @State private var showChatSheet = false
    @State private var showConfigSheet = false
    @State private var showOcclusionSheet = false
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
    // 添加新的状态变量用于跟踪当前选中的搜索结果
    @State private var selectedSearchSelection: PDFSelection? = nil
    @State private var textToProcess = ""
    @State private var autoSendMessage = false
    @State private var occlusionImage: UIImage? = nil // State to hold the captured image
    @State private var pdfViewCoordinator: PDFKitView.Coordinator? // To call coordinator methods


    // 目录访问管理器
    @StateObject private var directoryManager = DirectoryAccessManager.shared
    @StateObject var annotationListViewModel = AnnotationListViewModel()

    // 添加搜索状态管理
    @AppStorage("lastSearchText") private var lastSearchText: String = ""

    // Helper view for displaying the PDF
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
                    // Pass a callback to get the coordinator instance
                    coordinatorCallback: { coordinator in
                        self.pdfViewCoordinator = coordinator
                    },
                    isPDFLoaded: $isPDFLoaded,
                    viewPoint: $viewPoint,
                    annotation: $annotation,
                    forceRender: $forceRender,
                    pdfDocument: $pdfDocument,
                    selectedSearchSelection: $selectedSearchSelection,
                    showChatSheet: $showChatSheet,
                    textToProcess: $textToProcess,
                    autoSendMessage: $autoSendMessage
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
            get: { showConfigSheet || showAnnotationsSheet || showChatSheet || showSearchSheet || showOcclusionSheet || showPDFPicker || showLinkInputSheet },
            set: {
                if !$0 {
                    showConfigSheet = false
                    showAnnotationsSheet = false
                    showChatSheet = false
                    showSearchSheet = false
                    showOcclusionSheet = false
                    showPDFPicker = false
                    showLinkInputSheet = false
                }
            }
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
    private var chatSheetContent: some View {
        ChatView(initialText: textToProcess, autoSend: autoSendMessage)
    }

    @ViewBuilder
    private var searchSheetContent: some View {
        NavigationView {
            PDFSearchView(pdfDocument: $pdfDocument) { result in
                // 更新选中的搜索结果
                selectedSearchSelection = result.selection
                // 保存最后选择的搜索结果页码
                UserDefaults.standard.set(result.page, forKey: "lastSearchPage")
            }
        }
    }

    @ViewBuilder
    private var occlusionSheetContent: some View {
        // OcclusionView() // Assuming OcclusionView handles its own dismissal or this was intended
        // To ensure the sheet dismisses if OcclusionView doesn't handle it:
        // OcclusionView().onDisappear { showOcclusionSheet = false }
        // For now, keeping original logic which might be intentional if OcclusionView is simple
        // Pass the image to OcclusionView
        OcclusionView(image: occlusionImage)
    }

    @ViewBuilder
    private var pdfPickerSheetContent: some View {
        PDFPicker(accessManager: directoryManager)
            .onAppear {
                NSLog("✅ ContentView.swift -> ContentView.body, PDF 选择器 sheet 显示")
            }
        // .onDisappear is handled by anySheetBinding's setter now
    }

    @ViewBuilder
    private var linkInputSheetContent: some View {
        LinkInputView(linkText: $linkText, onSubmit: {
            processMetanoteLink(linkText)
            // showLinkInputSheet = false // Handled by anySheetBinding's setter
        })
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                mainContentSection
                errorSection
            }
            .frame(maxWidth: .infinity) // 确保内容填充整个屏幕宽度
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarTitleDisplayMode(.automatic)
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
                                Image(systemName: "magnifyingglass")
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
                                           showOcclusionSheet = true // 显示 PDF Occlusion sheet
                                       } else {
                                           // Handle error: show an alert or log
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
                    } else if showChatSheet {
                        chatSheetContent
                    } else if showSearchSheet {
                        NavigationView {
                            searchSheetContent
                        }
                    } else if showOcclusionSheet {
                        occlusionSheetContent
                          .onDisappear { // Ensure state is reset if view dismisses itself
                              if showOcclusionSheet { // only if it was this sheet
                                  showOcclusionSheet = false
                              }
                          }
                    } else if showPDFPicker {
                        pdfPickerSheetContent
                    } else if showLinkInputSheet {
                        linkInputSheetContent
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

                // Lock orientation to portrait initially
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }.onDisappear {
                // Reset orientation lock
                UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .statusBar(hidden: false)
        .ignoresSafeArea(.all, edges: .all) // Use full screen space
    }

    private func setupNotifications() {
        // 使用与 SceneDelegate 相同的通知名称
        let openPDFNotification = NSNotification.Name("OpenPDFNotification")

        // 添加通知名称常量
        let loadAnnotationsDatabaseNotification = NSNotification.Name("LoadAnnotationsDatabase")

        // 先移除可能存在的旧观察者，避免重复注册
        NotificationCenter.default.removeObserver(self, name: openPDFNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: loadAnnotationsDatabaseNotification, object: nil)

        NSLog("✅ ContentView.swift -> ContentView.setupNotifications, 正在注册通知观察者: \(openPDFNotification)")
        NSLog("✅ ContentView.swift -> ContentView.setupNotifications, 正在注册通知观察者: \(loadAnnotationsDatabaseNotification)")

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

            openPDF(at: self.convertedPdfPath, currentPage: page, xRatio: xRatio, yRatio: yRatio)
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
                NSLog("❌ ContentView.swift -> ContentView.setupNotifications, loadAnnotationsDatabaseNotification 通知中缺少数据库路径")

                return
            }

            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, loadAnnotationsDatabaseNotification 收到加载数据库通知，数据库路径：\(dataBasePath)")

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

        NotificationCenter.default.addObserver(
            forName: Notification.Name("OpenSelectedPDF"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let pdfPath = userInfo["pdfPath"] as? String,
                  let currentPage = userInfo["currentPage"] as? Int,
                  let xRatio = userInfo["xRatio"] as? Double,
                  let yRatio = userInfo["yRatio"] as? Double
            else {
                return
            }

            rawPdfPath = self.convertToRawPath(pdfPath)

            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenSelectedPDF 观察者, 接收到打开 PDF 请求，原始路径: \(pdfPath), 反转换路径: \(rawPdfPath)")

            // 调用 openPDF 方法打开文件
            openPDF(at: pdfPath, currentPage: currentPage, xRatio: xRatio, yRatio: yRatio)
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

        rawPdfPath = result.pdfPath
        convertedPdfPath = PathConverter.convertNoterPagePath(rawPdfPath, rootDirectoryURL: directoryManager.rootDirectoryURL)
        currentPage = result.page!
        xRatio = result.x!
        yRatio = result.y!

        NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 转换路径: \(convertedPdfPath), 页码: \(currentPage), yRatio: \(yRatio), xRatio: \(xRatio)")
        NSLog("✅ ContentView.swift -> ContentView.processMetanoteLink, 文件路径: \(String(describing: pdfURL)), 页码: \(currentPage), yRatio: \(yRatio), xRatio: \(xRatio)")

        openPDF(at: convertedPdfPath, currentPage: result.page!, xRatio: result.x!, yRatio: result.y!)
    }

    // 打开PDF文件的方法
    private func openPDF(at convertedPdfPath: String, currentPage: Int, xRatio: Double, yRatio: Double) {
        if let secureURL = directoryManager.startAccessingFile(at: convertedPdfPath) {
            pdfURL = secureURL
            self.currentPage = currentPage
            self.xRatio = xRatio
            self.yRatio = yRatio
            forceRender = true

            NSLog("✅ ContentView.swift -> ContentView.openPDF, 成功打开PDF文件: \(convertedPdfPath)")
        } else {
            pdfURL = nil
            pdfLoadError = "无法访问文件，请重新选择目录"

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
}

// 包装器视图，用于传递 ViewModel
struct AnnotationListViewWrapper: View {
    @ObservedObject var viewModel: AnnotationListViewModel

    var body: some View {
        AnnotationListView()
            .environmentObject(viewModel)
    }
}
