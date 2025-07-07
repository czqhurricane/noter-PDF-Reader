import PDFKit
import SwiftUI

extension UIResponder {
    static var currentFirstResponder: UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }

    private weak static var _currentFirstResponder: UIResponder?

    @objc private func findFirstResponder(_: Any) {
        UIResponder._currentFirstResponder = self
    }
}

extension CGRect {
    var isValid: Bool {
        return origin.x.isFinite && origin.y.isFinite &&
            !origin.x.isNaN && !origin.y.isNaN &&
            size.width > 0 && size.height > 0
    }
}

struct PDFKitView: UIViewRepresentable {
    var url: URL
    var page: Int
    var xRatio: Double
    var yRatio: Double
    var isLocationMode: Bool // 是否处于位置选择模式
    var rawPdfPath: String // PDF 在电脑端的路径
    var showOutlines: Bool // 显示 PDF 目录
    var shouldShowArrow: Bool

    var coordinatorCallback: ((Coordinator) -> Void)? // 用于传递协调器的回调函数

    @Binding var isPDFLoaded: Bool
    @Binding var viewPoint: CGPoint
    @Binding var annotation: String
    @Binding var forceRender: Bool
    @Binding var pdfDocument: PDFDocument?
    @Binding var selectedSearchSelection: String?
    @Binding var selectedFolderSearchText: String?
    @Binding var showChatSheet: Bool
    @Binding var textToProcess: String
    @Binding var autoSendMessage: Bool
    @Binding var source: String

    func makeUIView(context: Context) -> PDFView {
        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, url : \(String(describing: url))")

        // 检查文件是否存在
        let fileManager = FileManager.default
        let fileExists = fileManager.fileExists(atPath: url.path)
        let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.path
        let encodedPathExists = fileManager.fileExists(atPath: encodedPath)

        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 文件存在检查: \(fileExists ? "存在" : "不存在") - 路径: \(url.path)")
        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 文件存在检查: \(encodedPathExists ? "存在" : "不存在") - 编码路径: \(encodedPath)")

        // 检查文件是否可读
        if fileExists {
            let isReadable = fileManager.isReadableFile(atPath: url.path)

            NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 文件可读性检查: \(isReadable ? "可读" : "不可读")")
        }

        let pdfView = CustomPDFView()

        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical

        pdfView.usePageViewController(true)

        // 设置更稳定的分页参数
        pdfView.pageShadowsEnabled = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        // 根据isLocationMode状态决定是否添加手势识别器
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator,
                                                   action: #selector(Coordinator.handleTap(_:)))
        pdfView.addGestureRecognizer(tapRecognizer)

        // 尝试多种方式加载文档
        var document: PDFDocument? = nil

        // 方法1: 直接使用原始URL
        document = PDFDocument(url: url)

        if document != nil {
            NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 方法1成功: 使用原始URL加载PDF")
        } else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 方法1失败: 无法使用原始URL加载PDF")

            // 方法2: 尝试使用 Data 加载
            if fileExists {
                do {
                    let data = try Data(contentsOf: url)
                    document = PDFDocument(data: data)

                    if document != nil {
                        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 方法 2 成功: 使用 Data 加载 PDF")
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 方法2失败: 无法使用Data加载PDF")
                    }
                } catch {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 方法 2 异常: \(error.localizedDescription)")
                }
            }

            // 方法3: 尝试使用编码后的URL
            if document == nil {
                if let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let encodedURL = URL(string: "file://" + encodedPath)
                {
                    document = PDFDocument(url: encodedURL)

                    if document != nil {
                        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 方法 3 成功: 使用编码 URL 加载 PDF")
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 方法 3 失败: 无法使用编码 URL 加载 PDF")
                    }
                }
            }
        }

        // 设置PDF文档
        if let document = document {
            pdfView.document = document
            pdfDocument = document

            navigateToPage(pdfView, context: context)

            NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 成功获取 pdfView.document")
        } else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 所有方法均无法加载 PDF 文档")

            // 通知用户加载失败
            DispatchQueue.main.async {
                self.isPDFLoaded = false
            }
        }

        // 添加延迟设置，确保视图层次结构稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pdfView.delegate = context.coordinator
        }

        // 将pdfView实例传递给协调器，以便可以访问它进行截图
        context.coordinator.pdfView = pdfView

        // 使用协调器实例调用回调函数
        coordinatorCallback?(context.coordinator)

        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 返回 pdfView = CustomPDFView()")

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard pdfView.superview != nil,
              pdfView.window != nil
        else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, PDFView状态无效，跳过更新")

            return
        }

        // 确保委托仍然有效
        if pdfView.delegate == nil {
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 重新设置 delegate")

            pdfView.delegate = context.coordinator
            context.coordinator.pdfView = pdfView
        }

        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.updateUIView(pdfView, context: context)
            }

            return
        }

        // 检查视图状态
        guard pdfView.superview != nil else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, PDFView 没有父视图，跳过更新")

            return
        }

        context.coordinator.parent = self
        context.coordinator.isLocationMode = isLocationMode // 更新协调器中的状态

        // 处理目录显示
        if showOutlines {
            if context.coordinator.outlineVC == nil {
                let outlineVC = PDFOutlineViewController()

                outlineVC.pdfView = pdfView
                context.coordinator.outlineVC = outlineVC

                // 改进的视图控制器获取逻辑
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                       let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                       let rootVC = window.rootViewController
                    {
                        // 确保视图控制器仍然有效
                        guard !rootVC.isBeingDismissed && !rootVC.isBeingPresented else {
                            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 视图控制器正在转换中，跳过 present 操作")

                            return
                        }

                        rootVC.present(outlineVC, animated: true) {
                            NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 成功显示目录")
                        }
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 无法获取有效的根视图控制器")
                    }
                }
            }
        } else {
            // 安全地关闭大纲视图控制器
            if let outlineVC = context.coordinator.outlineVC {
                DispatchQueue.main.async {
                    // 检查视图控制器状态
                    if outlineVC.presentingViewController != nil && !outlineVC.isBeingDismissed {
                        outlineVC.dismiss(animated: true) {
                            context.coordinator.outlineVC = nil

                            NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 成功关闭目录")
                        }
                    } else {
                        context.coordinator.outlineVC = nil
                    }
                }
            }
        }

        // 处理 PDFFolderSearchView文件夹搜索结果高亮
        if let searchText = selectedFolderSearchText {
            DispatchQueue.main.async {
                self.highlightSearchText(pdfView: pdfView, searchText: searchText)
            }

            // 确保在主线程重置状态，避免重复处理
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.selectedFolderSearchText = nil
            }
        }

        // 处理 PDFSearchView文件夹搜索结果高亮
        if let searchText = selectedSearchSelection {
            DispatchQueue.main.async {
                self.highlightSearchText(pdfView: pdfView, searchText: searchText)
            }

            // 确保在主线程重置状态，避免重复处理
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.selectedSearchSelection = nil
            }
        }

        let currentState = (url: url, page: page, xRatio: xRatio, yRatio: yRatio, forceRender: forceRender)

        if context.coordinator.previousState == nil ||
            context.coordinator.previousState! != currentState
        {
            // 安全地更新状态
            DispatchQueue.main.async {
                self.forceRender = false
            }

            context.coordinator.previousState = (url: url, page: page, xRatio: xRatio, yRatio: yRatio, forceRender: false)
        } else {
            return
        }

        // 如果文档已加载，则不重新加载
        if let document = pdfView.document, document.documentURL == url {
            NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 文档已加载，跳转到指定页面")

            navigateToPage(pdfView, context: context)

            return
        }

        // 尝试加载文档（与 makeUIView 中相同的逻辑）
        var document: PDFDocument? = nil

        // 尝试多种方式加载文档
        document = PDFDocument(url: url)

        if document != nil {
            NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 方法 1 成功: 使用原始 URL 加载PDF")
        } else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 方法 1 失败: 无法使用原始 URL 加载 PDF")

            do {
                let data = try Data(contentsOf: url)
                document = PDFDocument(data: data)

                if document != nil {
                    NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 方法 2 成功: 使用 Data 加载PDF")
                } else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 方法 2 失败: 无法使用 Data 加载 PDF")
                }
            } catch {
                NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 无法使用 Data 加载 PDF: \(error.localizedDescription)")
            }

            if document == nil {
                if let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let encodedURL = URL(string: "file://" + encodedPath)
                {
                    document = PDFDocument(url: encodedURL)

                    if document != nil {
                        NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 方法 3 成功: 使用编码 URL 加载 PDF")
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 方法 3 失败: 无法使用编码 URL 加载 PDF")
                    }
                }
            }
        }

        if let document = document {
            pdfView.document = document
            pdfDocument = document

            NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 成功加载文档")

            navigateToPage(pdfView, context: context)
        } else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 所有方法均无法加载 PDF 文档")

            DispatchQueue.main.async {
                self.isPDFLoaded = false
            }
        }
    }

    // 提取导航到指定页面的逻辑为单独的方法
    private func navigateToPage(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }

        if let targetPage = document.page(at: page - 1) {
            pdfView.go(to: targetPage)

            // 增加延迟，确保 PDF 视图完全加载
            if shouldShowArrow {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    pdfView.layoutDocumentView()
                    pdfView.layoutIfNeeded()
                    pdfView.documentView?.layoutIfNeeded()

                    if let currentPage = pdfView.currentPage {
                        let pdfSize = currentPage.bounds(for: .mediaBox).size
                        self.isPDFLoaded = true
                        self.viewPoint = context.coordinator.convertToViewCoordinates(pdfView: pdfView) ?? .zero

                        // 确保 documentView 存在
                        if let docView = pdfView.documentView {
                            NSLog("✅ PDFKitView.swift -> PDFKitView.navigateToPage, 成功获取 documentView，尺寸: \(docView.bounds.size)")

                            // 添加箭头图层（先移除再添加，避免重复）
                            context.coordinator.arrowLayer.removeFromSuperlayer()
                            docView.layer.addSublayer(context.coordinator.arrowLayer)

                            // 初始化位置
                            context.coordinator.updateArrowPosition(pdfView: pdfView)

                            // 调试信息
                            NSLog("✅ PDFKitView.swift -> PDFKitView.navigateToPage, 添加箭头图层，PDF尺寸 pdfSize = \(pdfSize)")
                        } else {
                            NSLog("❌ PDFKitView.swift -> PDFKitView.navigateToPage, docView = pdfView.documentView 为 nil，即使在延迟后")
                            // 添加箭头图层（先移除再添加，避免重复）
                            context.coordinator.arrowLayer.removeFromSuperlayer()
                            // pdfView.documentView 为 nil 的情况下，直接使用 pdfView 替代 docView
                            pdfView.layer.addSublayer(context.coordinator.arrowLayer)
                            context.coordinator.updateArrowPosition(pdfView: pdfView)

                            // 调试信息
                            NSLog("✅ PDFKitView.swift -> PDFKitView.navigateToPage, 添加箭头图层，PDF尺寸 pdfSize = \(pdfSize)")
                        }
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.navigateToPage, 跳转后无法获取当前页面")

                        self.isPDFLoaded = false
                    }
                }
            }
        } else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.navigateToPage, 无法获取目标页面，页码: \(page)，总页数: \(document.pageCount)")

            isPDFLoaded = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // 高亮 PDFFolderSearchView 文件夹搜索文本的方法
    private func highlightSearchText(pdfView: PDFView, searchText: String) {
        guard let document = pdfView.document,
              let currentPage = pdfView.currentPage else { return }

        // 在当前页面搜索文本
        let selections = document.findString(searchText, fromSelection: nil, withOptions: [.caseInsensitive])

        // 检查是否找到匹配项
        guard let foundSelection = selections else { return }

        // 检查找到的选择是否在当前页面
        if let page = foundSelection.pages.first, page == currentPage {
            // 高亮显示找到的文本
            foundSelection.color = UIColor.orange.withAlphaComponent(0.5)
            pdfView.setCurrentSelection(foundSelection, animate: true)

            // 5秒后取消选中
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                pdfView.setCurrentSelection(nil, animate: true)
            }
        }
    }

    class Coordinator: NSObject, PDFViewDelegate {
        let arrowLayer = CAShapeLayer()
        // directoryManager 属性
        let directoryManager = DirectoryAccessManager.shared

        var xRatio: Double { parent.xRatio }
        var yRatio: Double { parent.yRatio }
        var parent: PDFKitView
        var isLocationMode: Bool = false
        var currentOutlineString = "" // 新增属性存储当前大纲路径
        var previousState: (url: URL, page: Int, xRatio: Double, yRatio: Double, forceRender: Bool)?
        var outlineVC: PDFOutlineViewController?

        private var isProcessingPageChange = false
        private var arrowTimer: Timer? // 计时器的属性
        private var lastTapXRatio: Double = 0
        private var lastTapYRatio: Double = 0
        private var selectedText: String = "" // 存储选中文本的属性
        private var pageText: String = ""
        private var isTranslationMode: Bool = false // 否是翻译模式标识
        private var savePageTimer: Timer?

        // 向 PDFView 添加一个弱引用
        weak var pdfView: PDFView?

        init(_ parent: PDFKitView) {
            self.parent = parent

            super.init()

            // 确保在主线程添加通知观察者
            DispatchQueue.main.async {
                // 添加页面变化通知观察者
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.pageDidChange(notification:)),
                    name: Notification.Name.PDFViewPageChanged,
                    object: nil
                )

                // 添加文本选择通知观察者
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleTextSelection(_:)),
                    name: Notification.Name.PDFViewSelectionChanged,
                    object: nil
                )
            }

            // 配置箭头样式
            arrowLayer.fillColor = UIColor.red.cgColor

            // 创建箭头路径
            let arrowPath = CGMutablePath()
            let arrowSize: CGFloat = 10

            // 绘制箭头形状
            arrowPath.move(to: CGPoint(x: arrowSize / 2, y: 0))
            arrowPath.addLine(to: CGPoint(x: arrowSize, y: arrowSize))
            arrowPath.addLine(to: CGPoint(x: arrowSize / 2, y: arrowSize * 0.6))
            arrowPath.addLine(to: CGPoint(x: 0, y: arrowSize))
            arrowPath.closeSubpath()

            // 设置路径
            arrowLayer.path = arrowPath

            // 设置锚点在箭头尖端
            arrowLayer.anchorPoint = CGPoint(x: 0.5, y: 0)

            // 设置初始大小
            arrowLayer.bounds = CGRect(x: 0, y: 0, width: arrowSize, height: arrowSize)
        }

        func convertToViewCoordinates(pdfView: PDFView) -> CGPoint? {
            guard let page = pdfView.currentPage else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, 无法获取 page = pdfView.currentPage")

                return nil
            }

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, 成功获取 page = pdfView.currentPage")

            let pageSize = page.bounds(for: .mediaBox).size

            // 添加对页面大小的验证
            guard pageSize.width > 0 && pageSize.height > 0 &&
                pageSize.width.isFinite && pageSize.height.isFinite
            else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, Invalid page size: \(pageSize)")

                return nil
            }

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, PDF 页面尺寸 pageSize  = \(pageSize)")

            let xRatio = self.xRatio
            let yRatio = self.yRatio

            // 添加对比例值的验证
            guard xRatio.isFinite && yRatio.isFinite &&
                !xRatio.isNaN && !yRatio.isNaN
            else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates,  Invalid ratio values: xRatio=\(xRatio), yRatio=\(yRatio)")

                return nil
            }

            // PDF page 页面坐标系（左下角原点）转换为 PDFView 视图坐标系
            let pdfPoint = CGPoint(
                x: pageSize.width * CGFloat(xRatio),
                y: pageSize.height * CGFloat(1 - yRatio) // 翻转 Y 轴
            )

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, PDF page 坐标点 pdfPoint = \(pdfPoint), xRatio = \(xRatio), yRatio = \(yRatio)")

            // 验证 pdfPoint
            guard pdfPoint.x.isFinite && pdfPoint.y.isFinite &&
                !pdfPoint.x.isNaN && !pdfPoint.y.isNaN
            else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, Invalid pdfPoint: \(pdfPoint)")
                return nil
            }

            // 转换为 PDFView 的坐标系
            let viewPoint = pdfView.convert(pdfPoint, from: page)

            // 在返回前验证 viewPoint
            guard viewPoint.x.isFinite && viewPoint.y.isFinite &&
                !viewPoint.x.isNaN && !viewPoint.y.isNaN
            else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, Invalid viewPoint after conversion: \(viewPoint)")

                return nil
            }

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, 转换后的 pdfView 视图坐标点 viewPoint = \(viewPoint)")

            return viewPoint
        }

        func updateArrowPosition(pdfView: PDFView) {
            guard let position = convertToViewCoordinates(pdfView: pdfView) else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.updateArrowPosition, 无法获取位置 position  = convertToViewCoordinates(pdfView: pdfView)")

                return
            }

            // 额外安全检查
            guard position.x.isFinite && position.y.isFinite &&
                !position.x.isNaN && !position.y.isNaN
            else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.updateArrowPosition, Invalid position values: \(position)")

                return
            }

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.updateArrowPosition, 成功获取位置 position  = convertToViewCoordinates(pdfView: pdfView) = \(position)")

            CATransaction.begin()
            CATransaction.setDisableActions(true)

            // 设置位置（注意：由于我们设置了锚点在箭头尖端，所以这里直接使用转换后的位置）
            arrowLayer.position = position

            // 根据 PDF 缩放比例调整大小
            let scale = 3 / pdfView.scaleFactor
            let rotation = CATransform3DMakeRotation(.pi / 2, 0, 0, 1) // Clockwise 90°
            let scaledRotation = CATransform3DConcat(
                CATransform3DMakeScale(scale, scale, 1),
                rotation
            )
            arrowLayer.transform = scaledRotation

            // 确保图层可见
            arrowLayer.isHidden = false
            arrowLayer.opacity = 1.0 // 添加这一行，确保每次都重置不透明度
            arrowLayer.zPosition = 999 // 确保在最上层

            CATransaction.commit()

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.updateArrowPosition, 箭头位置更新完成")

            // 取消之前的计时器（如果存在）
            arrowTimer?.invalidate()

            // 创建新的计时器，10秒后隐藏箭头
            arrowTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                CATransaction.begin()
                CATransaction.setAnimationDuration(0.5) // 添加淡出动画
                self.arrowLayer.opacity = 0
                CATransaction.commit()

                NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.updateArrowPosition, 箭头已在10秒后隐藏")
            }
        }

        // PDFViewDelegate方法
        func pdfViewWillClick(onLink _: PDFView, with _: URL) {
            // 处理PDF内部链接点击
        }

        func pdfViewDidEndPageChange(_: PDFView) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidEndPageChange, PDF 页面切换完成")
        }

        func pdfViewDidEndDisplayingPage(_: PDFView, page: PDFPage) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidEndDisplayingPage, PDF 页面显示结束: \(page)")
        }

        func pdfViewDidLayoutSubviews(_: PDFView) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidLayoutSubviews, PDF 视图完成子视图布局")
        }

        deinit {
            // 在析构函数中清理计时器
            arrowTimer?.invalidate()

            // 确保在主线程移除通知观察者
            DispatchQueue.main.async {
                NotificationCenter.default.removeObserver(self)
            }
            // 清理CAShapeLayer
            arrowLayer.removeFromSuperlayer()

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.deinit, Coordinator 已释放")
        }

        private func showAnnotationDialog(pdfView: PDFView, selectedText: String) {
            // 创建自定义视图控制器而不是使用 UIAlertController
            let customVC = UIViewController()
            customVC.modalPresentationStyle = .formSheet
            customVC.preferredContentSize = CGSize(width: 350, height: 250)

            // 创建UITextView作为多行输入框
            let textView = UITextView()
            textView.text = selectedText
            textView.font = UIFont.systemFont(ofSize: 16)
            textView.isEditable = true
            textView.layer.borderColor = UIColor.lightGray.cgColor
            textView.layer.borderWidth = 1.0
            textView.layer.cornerRadius = 8.0
            textView.autocorrectionType = .no

            // 创建确认和取消按钮
            let confirmButton = UIButton(type: .system)
            confirmButton.setTitle("确认", for: .normal)
            confirmButton.backgroundColor = .systemBlue
            confirmButton.setTitleColor(.white, for: .normal)
            confirmButton.layer.cornerRadius = 8.0

            let cancelButton = UIButton(type: .system)
            cancelButton.setTitle("取消", for: .normal)
            cancelButton.backgroundColor = .systemGray5
            cancelButton.layer.cornerRadius = 8.0

            // 设置按钮动作
            confirmButton.addAction(UIAction { [weak self, weak textView, weak customVC] _ in
                guard let self = self, let text = textView?.text, let customVC = customVC else { return }

                DispatchQueue.main.async {
                    if let document = pdfView.document {
                        let fileName = document.documentURL?.lastPathComponent ?? "unknown.pdf"
                        // 获取PDF路径、页码、坐标和大纲路径
                        let pdfPath = self.parent.rawPdfPath
                        let pageNumber = (pdfView.currentPage?.pageRef?.pageNumber ?? 0)
                        // 使用存储的值
                        let xRatio = self.lastTapXRatio
                        let yRatio = self.lastTapYRatio
                        let outlineString = self.currentOutlineString
                        // 获取当前时间戳并格式化为 (high low) 形式
                        let currentTimeInterval = Date().timeIntervalSince1970
                        // 将秒数分解为 HIGH 和 LOW 部分
                        let seconds = Int64(floor(currentTimeInterval))
                        let high = Int32(seconds >> 16)
                        let low = Int32(seconds & 0xFFFF)
                        let formattedTimestamp = "(\(high) \(low))"
                        // 生成唯一ID
                        let annotationId = pdfPath + "#" + String(Int(currentTimeInterval))
                        // 格式化坐标
                        let edges = "(\(xRatio) \(yRatio))"

                        // 创建注释数据对象
                        let annotation = AnnotationData(
                            id: annotationId,
                            file: pdfPath,
                            page: pageNumber,
                            edges: edges,
                            type: "text",
                            color: "",
                            contents: text,
                            subject: "",
                            created: formattedTimestamp,
                            modified: formattedTimestamp,
                            outlines: outlineString
                        )

                        // 格式化注释内容
                        let formattedAnnotation = "[[NOTERPAGE:\(pdfPath)#(\(pageNumber) \(yRatio) . \(xRatio))][\(text) < \(outlineString.isEmpty ? fileName : outlineString)]]"

                        self.parent.annotation = formattedAnnotation

                        // 持久化保存到数据库
                        if let savedDatabasePath = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
                           let url = URL(string: savedDatabasePath)
                        {
                            let dataBasePath = url.appendingPathComponent("pdf-annotations.db").path

                            // 打开数据库
                            guard DatabaseManager.shared.openDatabase(with: self.directoryManager, at: dataBasePath) else {
                                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, 无法打开数据库: \(dataBasePath)")
                                return
                            }

                            // 添加注释
                            if DatabaseManager.shared.addAnnotation(annotation) {
                                NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, confirmAction，成功添加注释: \(text)")

                            } else {
                                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, confirmAction, 添加注释失败")
                            }

                            // 关闭数据库
                            DatabaseManager.shared.closeDatabase()
                        }

                        NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, 新建注释使用的比例 - xRatio: \(xRatio), yRatio: \(yRatio)")
                        NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, 保存注释: \(formattedAnnotation)")
                    }
                }

                customVC.dismiss(animated: true)
            }, for: .touchUpInside)

            cancelButton.addAction(UIAction { [weak customVC] _ in
                customVC?.dismiss(animated: true)

                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, 注释输入已取消")
            }, for: .touchUpInside)

            // 创建标题标签
            let titleLabel = UILabel()
            titleLabel.text = "添加注释"
            titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
            titleLabel.textAlignment = .center

            // 添加视图到控制器
            customVC.view.backgroundColor = .systemBackground

            // 使用自动布局
            for item in [titleLabel, textView, confirmButton, cancelButton] {
                item.translatesAutoresizingMaskIntoConstraints = false
                customVC.view.addSubview(item)
            }

            NSLayoutConstraint.activate([
                // 标题布局
                titleLabel.topAnchor.constraint(equalTo: customVC.view.topAnchor, constant: 20),
                titleLabel.leadingAnchor.constraint(equalTo: customVC.view.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: customVC.view.trailingAnchor, constant: -20),

                // 文本视图布局
                textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
                textView.leadingAnchor.constraint(equalTo: customVC.view.leadingAnchor, constant: 20),
                textView.trailingAnchor.constraint(equalTo: customVC.view.trailingAnchor, constant: -20),
                textView.heightAnchor.constraint(equalTo: customVC.view.heightAnchor, multiplier: 0.5),

                // 按钮布局
                cancelButton.leadingAnchor.constraint(equalTo: customVC.view.leadingAnchor, constant: 20),
                cancelButton.bottomAnchor.constraint(equalTo: customVC.view.bottomAnchor, constant: -20),
                cancelButton.widthAnchor.constraint(equalTo: customVC.view.widthAnchor, multiplier: 0.4),

                confirmButton.trailingAnchor.constraint(equalTo: customVC.view.trailingAnchor, constant: -20),
                confirmButton.bottomAnchor.constraint(equalTo: customVC.view.bottomAnchor, constant: -20),
                confirmButton.widthAnchor.constraint(equalTo: customVC.view.widthAnchor, multiplier: 0.4),
            ])

            // 显示自定义视图控制器 - 修复的部分
            DispatchQueue.main.async {
                // 更安全的方式获取根视图控制器
                guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                      let rootViewController = window.rootViewController
                else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, 无法获取根视图控制器")

                    return
                }

                // 确保视图控制器可以呈现模态视图
                var presentingVC = rootViewController
                while let presented = presentingVC.presentedViewController {
                    presentingVC = presented
                }

                // 检查视图控制器状态
                guard !presentingVC.isBeingDismissed && !presentingVC.isBeingPresented else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.showAnnotationDialog, 视图控制器正在转换中")

                    return
                }

                presentingVC.present(customVC, animated: true) {
                    // 自动聚焦到文本视图
                    textView.becomeFirstResponder()
                }
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let pdfView = recognizer.view as? CustomPDFView else { return }

            // 检查获取位置模式
            guard isLocationMode else {
                return
            }

            let location = recognizer.location(in: pdfView)
            guard let page = pdfView.currentPage else { return }

            // 将点击位置转换为 pdfView 坐标
            let pdfPoint = pdfView.convert(location, to: page)
            let pageBounds = page.bounds(for: .mediaBox)

            // 计算比率
            let xRatio = Double(pdfPoint.x / pageBounds.width)
            // 翻转 y 轴
            let yRatio = Double(1 - (pdfPoint.y / pageBounds.height))

            // 保存到存储属性
            lastTapXRatio = xRatio
            lastTapYRatio = yRatio

            // 更新位置并显示箭头
            parent.xRatio = xRatio
            parent.yRatio = yRatio

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.handleTap, handleTap 计算的比例 - xRatio: \(xRatio), yRatio: \(yRatio)")
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.handleTap, handleTap 更新后的 self 中的计算属性 - xRatio: \(self.xRatio), yRatio: \(self.yRatio)")
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.handleTap, handleTap 更新后的 parent 中的计算属性 - xRatio: \(parent.xRatio), yRatio: \(parent.yRatio)")

            updateArrowPosition(pdfView: pdfView)

            // 获取 PDF 大纲层次结构
            if let document = pdfView.document {
                var hierarchy: [String] = []

                func logOutlineHierarchy(_ outline: PDFOutline) {
                    if let destination = outline.destination, destination.page == page {
                        let fullHierarchy = hierarchy + [outline.label ?? ""]
                        let reversedHierarchy = Array(fullHierarchy.reversed())
                        let outlineString = reversedHierarchy
                            .filter { !$0.isEmpty }
                            .joined(separator: " < ")

                        NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.handleTap.logOutlineHierarchy, 当前页面大纲层级: \(outlineString)")
                        currentOutlineString = outlineString // 存储当前大纲路径
                    }

                    hierarchy.append(outline.label ?? "")
                    for i in 0 ..< outline.numberOfChildren {
                        if let child = outline.child(at: i) {
                            logOutlineHierarchy(child)
                        }
                    }
                    hierarchy.removeLast()
                }

                if let root = document.outlineRoot {
                    logOutlineHierarchy(root)
                } else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.handleTap, 当前 PDF 文档没有大纲目录")
                }
            }

            // 重置自动隐藏计时器
            arrowTimer?.invalidate()
            arrowTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.5)
                self.arrowLayer.opacity = 0
                CATransaction.commit()
            }

            // 首先检查文本选择
            if let selectedText = pdfView.currentSelection?.string, !selectedText.isEmpty {
                showAnnotationDialog(pdfView: pdfView, selectedText: selectedText)
            } else {
                // 显示注释对话框
                showAnnotationDialog(pdfView: pdfView, selectedText: "")
            }
        }

        // 处理文本选择
        @objc func handleTextSelection(_ notification: Notification) {
            guard let pdfView = notification.object as? CustomPDFView else { return }
            guard let selection = pdfView.currentSelection else {
                return
            }

            // 隐藏菜单如果当前没有选择文本
            guard let selectedText = selection.string, !selectedText.isEmpty else {
                return
            }

            // 保存选中的文本
            self.selectedText = selectedText

            // 确保 PDFView 是第一响应者
            if !pdfView.isFirstResponder {
                pdfView.becomeFirstResponder()
            }

            // 显示菜单
            if let currentPage = pdfView.currentPage {
                // 保存页面的文本
                pageText = currentPage.string ?? "default value"
            }
        }

        // 处理“翻译”菜单项的点击事件
        @objc func translateSelectedText(_: Any) {
            isTranslationMode = true
            showChatView()
        }

        // 处理“翻译整页”菜单项的点击事件
        @objc func translateWholePage(_: Any) {
            DispatchQueue.main.async {
                self.parent.showChatSheet = true
                self.parent.textToProcess = self.pageText
                self.parent.autoSendMessage = true
            }
        }

        // 处理“对话”菜单项的点击事件
        @objc func chatWithSelectedText(_: Any) {
            isTranslationMode = false
            showChatView()
        }

        // 处理“高亮”菜单项的点击事件
        @objc func highlightSelectedText(_: Any?) {
            // 获取当前PDFView和选中内容
            guard let currentResponder = UIResponder.currentFirstResponder,
                  let pdfView = currentResponder as? CustomPDFView,
                  let currentSelection = pdfView.currentSelection,
                  let page = currentSelection.pages.first else { return }

            // 创建高亮注释
            let bounds = currentSelection.bounds(for: page)
            let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            highlight.color = UIColor.yellow.withAlphaComponent(0.5)

            // 确保文档未锁定且允许注释
            if !page.document!.isLocked && page.document!.allowsCommenting {
                page.addAnnotation(highlight)
            }

            // 在UI上立即显示高亮效果
            pdfView.setNeedsDisplay()

            // 将文件保存操作放在后台线程执行
            if let document = pdfView.document,
               let documentURL = document.documentURL
            {
                // 创建一个弱引用，避免循环引用
                weak var weakDocument = document

                // 使用后台队列执行保存操作
                DispatchQueue.main.async {
                    // 确保document仍然有效
                    guard let strongDocument = weakDocument else { return }

                    // 在后台线程保存文件
                    strongDocument.write(to: documentURL)

                    // 在主线程更新UI或显示成功消息
                    DispatchQueue.main.async {
                        NSLog("✅ PDFKitView.swift -> highlightSelectedText, 成功将高亮保存到PDF文件")
                    }
                }
            }
        }

        // 显示ChatView
        private func showChatView() {
            DispatchQueue.main.async {
                self.parent.showChatSheet = true
                self.parent.textToProcess = self.selectedText
                self.parent.autoSendMessage = self.isTranslationMode
            }
        }

        func captureCurrentPageAsImage() -> UIImage? {
            guard let pdfView = pdfView, let currentPage = pdfView.currentPage else {
                NSLog("❌ PDFKitView.swift -> Coordinator.captureCurrentPageAsImage, PDFView or currentPage is nil")

                return nil
            }
            let pageBounds = currentPage.bounds(for: .cropBox)
            let renderer = UIGraphicsImageRenderer(bounds: pageBounds)
            let image = renderer.image { _ in
                UIColor.white.setFill()
                UIRectFill(pageBounds)
                currentPage.draw(with: .cropBox, to: UIGraphicsGetCurrentContext()!)
            }

            if let document = pdfView.document {
                var hierarchy: [String] = []

                func logOutlineHierarchy(_ outline: PDFOutline) {
                    if let destination = outline.destination, destination.page == currentPage {
                        let fullHierarchy = hierarchy + [outline.label ?? ""]
                        let reversedHierarchy = Array(fullHierarchy.reversed())
                        let outlineString = reversedHierarchy
                            .filter { !$0.isEmpty }
                            .joined(separator: " < ")

                        NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.captureCurrentPageAsImage.logOutlineHierarchy, 当前页面大纲层级: \(outlineString)")
                        // 存储当前大纲路径
                        currentOutlineString = outlineString
                    }

                    hierarchy.append(outline.label ?? "")
                    for i in 0 ..< outline.numberOfChildren {
                        if let child = outline.child(at: i) {
                            logOutlineHierarchy(child)
                        }
                    }
                    hierarchy.removeLast()
                }

                if let root = document.outlineRoot {
                    logOutlineHierarchy(root)
                } else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.captureCurrentPageAsImage, 当前 PDF 文档没有大纲目录")
                }

                let fileName = document.documentURL?.lastPathComponent ?? "unknown.pdf"
                // 获取PDF路径、页码、坐标和大纲路径
                let pdfPath = parent.rawPdfPath
                let pageNumber = (pdfView.currentPage?.pageRef?.pageNumber ?? 0)
                // 使用存储的值
                let xRatio = 0.5
                let yRatio = 0.5
                let outlineString = currentOutlineString

                // 格式化注释内容
                let formattedSource = "<a href=\"NOTERPAGE:\(pdfPath)#(\(pageNumber) \(yRatio) . \(xRatio))\">\(outlineString.isEmpty ? fileName : outlineString)</a>"

                parent.source = formattedSource

                NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.captureCurrentPageAsImage, formattedSource: \(formattedSource)")
            }
            NSLog("✅ PDFKitView.swift -> Coordinator.captureCurrentPageAsImage, Screenshot captured")

            return image
        }

        @objc private func pageDidChange(notification: Notification) {
            // 防止重复处理页面切换
            guard !isProcessingPageChange else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, 跳过重复的页面切换事件")

                return
            }

            isProcessingPageChange = true

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, PDF 页面切换完成")

            // 添加更严格的状态检查
            guard let pdfView = notification.object as? PDFView,
                  pdfView.superview != nil,
                  pdfView.window != nil,
                  !pdfView.isHidden && pdfView.alpha > 0
            else {
                isProcessingPageChange = false

                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, PDFView状态无效")

                return
            }

            // 检查是否正在进行视图转换
            if let window = pdfView.window {
                // 修复：更安全的视图控制器检查
                var isTransitioning = false

                if let windowScene = window.windowScene,
                   let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
                   let rootVC = keyWindow.rootViewController {

                    var currentVC = rootVC
                    while let presented = currentVC.presentedViewController {
                        currentVC = presented
                    }

                    isTransitioning = currentVC.isBeingPresented || currentVC.isBeingDismissed
                }

                if isTransitioning {
                    isProcessingPageChange = false
                    NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, 视图控制器正在转换中")
                    return
                }
            }

            // 使用更长的延迟，让 PDFKit 完全完成内部状态更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                defer {
                    self?.isProcessingPageChange = false
                }

                guard let self = self else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, Coordinator 已释放")

                    return
                }

                // 再次检查PDFView状态
                guard pdfView.superview != nil,
                      pdfView.window != nil,
                      let currentPage = pdfView.currentPage,
                      let document = pdfView.document
                else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, 无法获取 PDF 视图或页面信息")

                    return
                }

                // 确保PDFView处于稳定状态
                guard pdfView.window != nil else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, PDFView正在被销毁")

                    return
                }

                // PDFKit 使用 0 基索引，我们使用 1 基索引
                let currentPageIndex = document.index(for: currentPage) + 1
                let pdfPath = self.parent.rawPdfPath

                // 取消之前的定时器
                self.savePageTimer?.invalidate()

                // 创建防抖定时器，延迟保存
                self.savePageTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    DispatchQueue.global(qos: .background).async {
                        // 保存当前页面号到数据库
                        let result = DatabaseManager.shared.saveLastVisitedPage(pdfPath: pdfPath, page: currentPageIndex)

                        if result {
                            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, 已保存当前文件：\(pdfPath)，当前页面号: \(currentPageIndex) 到数据库")
                        } else {
                            NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, 保存页面失败")
                        }
                    }
                }
            }
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, PDF 页面切换完成")
        }
    }
}

class CustomPDFView: PDFView {
    private var contextMenuInteraction: UIContextMenuInteraction?
    private var isCleaningUp = false
    private var isViewTransitioning = false
    private var pageViewController: UIPageViewController?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupContextMenu()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContextMenu()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContextMenu()
    }

    private func setupContextMenu() {
        contextMenuInteraction = UIContextMenuInteraction(delegate: self)
        addInteraction(contextMenuInteraction!)
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil && !isCleaningUp {
            isCleaningUp = true
            isViewTransitioning = true

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.usePageViewController(false)

                // 清理委托和文档
                self.delegate = nil
                self.document = nil

                // 清理选择状态
                self.setCurrentSelection(nil, animate: false)
            }

            // 延迟清理，给 PDFKit 时间完成内部操作
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.gestureRecognizers?.forEach { self?.removeGestureRecognizer($0) }

                NSLog("✅ PDFKitView.swift -> CustomPDFView.willMove, CustomPDFView 即将从父视图移除")
            }

            NSLog("✅ PDFKitView.swift -> CustomPDFView.willMove, CustomPDFView 即将从父视图移除")
        }

        super.willMove(toSuperview: newSuperview)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            isCleaningUp = false
            isViewTransitioning = false

            NSLog("✅ PDFKitView.swift -> CustomPDFView.didMoveToSuperview, CustomPDFView 已添加到父视图")
        } else if isCleaningUp {
            // 确保视图完全清理
            document = nil
            delegate = nil
            isViewTransitioning = false

            NSLog("✅ PDFKitView.swift -> CustomPDFView.didMoveToSuperview, CustomPDFView 已从父视图移除并清理")
        }
    }

    override func goToNextPage(_ sender: Any?) {
        guard !isViewTransitioning && !isCleaningUp && superview != nil && window != nil else {
            NSLog("❌ PDFKitView.swift -> CustomPDFView.goToNextPage, 视图状态无效，跳过操作")

            return
        }
        super.goToNextPage(sender)
    }

    override func goToPreviousPage(_ sender: Any?) {
        guard !isViewTransitioning && !isCleaningUp && superview != nil && window != nil else {
            NSLog("❌ PDFKitView.swift -> CustomPDFView.goToPreviousPage, 视图状态无效，跳过操作")

            return
        }
        super.goToPreviousPage(sender)
    }

    override func go(to page: PDFPage) {
        guard !isViewTransitioning && !isCleaningUp && superview != nil && window != nil else {
            NSLog("❌ PDFKitView.swift -> CustomPDFView.go(to:), 视图状态无效，跳过操作")

            return
        }
        super.go(to: page)
    }

    override var canBecomeFirstResponder: Bool { true }

    // 添加析构函数确保资源清理
    deinit {
        isCleaningUp = true
        delegate = nil
        document = nil

        NSLog("✅ PDFKitView.swift -> CustomPDFView.deinit, CustomPDFView 已释放")
    }
}

extension CustomPDFView: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_: UIContextMenuInteraction, configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration? {
        // 检查是否有文本被选中
        guard let selection = currentSelection,
              let selectedText = selection.string,
              !selectedText.isEmpty
        else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self,
                  let coordinator = self.delegate as? PDFKitView.Coordinator
            else {
                return UIMenu(title: "", children: [])
            }

            let translateAction = UIAction(
                title: "翻译",
                image: UIImage(systemName: "translate")
            ) { _ in
                coordinator.translateSelectedText(self)
            }

            let translateWholePageAction = UIAction(
                title: "翻译整页",
                image: UIImage(systemName: "doc.text")
            ) { _ in
                coordinator.translateWholePage(self)
            }

            let chatAction = UIAction(
                title: "对话",
                image: UIImage(systemName: "message")
            ) { _ in
                coordinator.chatWithSelectedText(self)
            }

            let highlightAction = UIAction(
                title: "高亮",
                image: UIImage(systemName: "highlighter")
            ) { _ in
                coordinator.highlightSelectedText(self)
            }

            return UIMenu(title: "", children: [translateAction, translateWholePageAction, chatAction, highlightAction])
        }
    }

    func contextMenuInteraction(_: UIContextMenuInteraction, willPerformPreviewActionForMenuWith _: UIContextMenuConfiguration, animator _: UIContextMenuInteractionCommitAnimating) {
        // 可选：处理预览动作
    }
}
