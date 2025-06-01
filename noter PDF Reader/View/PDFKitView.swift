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

struct PDFKitView: UIViewRepresentable {
    var url: URL
    var page: Int
    var xRatio: Double
    var yRatio: Double
    var isLocationMode: Bool // 是否处于位置选择模式
    var rawPdfPath: String // PDF 在电脑端的路径
    var showOutlines: Bool // 显示 PDF 目录

    var coordinatorCallback: ((Coordinator) -> Void)? // Callback to pass the coordinator

    @Binding var isPDFLoaded: Bool
    @Binding var viewPoint: CGPoint
    @Binding var annotation: String // 绑定到ContentView的注释状态
    @Binding var forceRender: Bool
    @Binding var pdfDocument: PDFDocument?
    @Binding var selectedSearchSelection: PDFSelection?
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

            // 方法2: 尝试使用Data加载
            if fileExists {
                do {
                    let data = try Data(contentsOf: url)
                    document = PDFDocument(data: data)
                    if document != nil {
                        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 方法2成功: 使用Data加载PDF")
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 方法2失败: 无法使用Data加载PDF")
                    }
                } catch {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 方法2异常: \(error.localizedDescription)")
                }
            }

            // 方法3: 尝试使用编码后的URL
            if document == nil {
                if let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let encodedURL = URL(string: "file://" + encodedPath)
                {
                    document = PDFDocument(url: encodedURL)
                    if document != nil {
                        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 方法3成功: 使用编码URL加载PDF")
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 方法3失败: 无法使用编码URL加载PDF")
                    }
                }
            }
        }

        // 设置PDF文档
        if let document = document {
            pdfView.document = document
            pdfDocument = document

            NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 成功获取 pdfView.document")
        } else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.makeUIView, 所有方法均无法加载PDF文档")
            // 通知用户加载失败
            DispatchQueue.main.async {
                self.isPDFLoaded = false
            }
        }

        // 设置代理
        pdfView.delegate = context.coordinator

        // Pass the pdfView instance to the coordinator so it can be accessed for screenshots
        context.coordinator.pdfView = pdfView

        // Call the callback with the coordinator instance
        coordinatorCallback?(context.coordinator)

        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 返回 pdfView = PDFView()")

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.updateUIView(pdfView, context: context)
            }
            return
        }

        // 检查视图状态
        guard pdfView.superview != nil else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, PDFView没有父视图，跳过更新")

            return
        }

        context.coordinator.parent = self
        context.coordinator.isLocationMode = isLocationMode // 更新协调器中的状态

        // 处理搜索结果选择
        if let selection = selectedSearchSelection {
            // Navigate to the selected page
            if let page = selection.pages.first {
                pdfView.go(to: page)
            }

            // Highlight the selected text - Fix: Use UIColor.yellow instead of just .yellow
            selection.color = UIColor.yellow.withAlphaComponent(0.3)
            pdfView.setCurrentSelection(selection, animate: true)

            // Reset selection state
            DispatchQueue.main.async {
                selectedSearchSelection = nil
            }
        }

        // 处理目录显示
        if showOutlines {
            if context.coordinator.outlineVC == nil {
                let outlineVC = PDFOutlineViewController()
                outlineVC.pdfView = pdfView
                context.coordinator.outlineVC = outlineVC

                // 安全地获取根视图控制器
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController
                {
                    // 确保在主线程呈现
                    DispatchQueue.main.async {
                        rootVC.present(outlineVC, animated: true)
                        NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 显示目录")
                    }
                }
            }
        } else {
            // Dismiss outline view controller if it is presented
            if let outlineVC = context.coordinator.outlineVC {
                DispatchQueue.main.async {
                    outlineVC.dismiss(animated: true)
                    context.coordinator.outlineVC = nil
                }
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

        // 尝试加载文档（与makeUIView中相同的逻辑）
        var document: PDFDocument? = nil

        // 尝试多种方式加载文档
        document = PDFDocument(url: url)

        if document != nil {
            NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 方法1成功: 使用原始URL加载PDF")
        } else {
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 方法1失败: 无法使用原始URL加载PDF")

            do {
                let data = try Data(contentsOf: url)
                document = PDFDocument(data: data)
                if document != nil {
                    NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 方法2成功: 使用Data加载PDF")
                } else {
                    NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 方法2失败: 无法使用Data加载PDF")
                }
            } catch {
                NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 无法使用 Data 加载PDF: \(error.localizedDescription)")
            }

            if document == nil {
                if let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let encodedURL = URL(string: "file://" + encodedPath)
                {
                    document = PDFDocument(url: encodedURL)
                    if document != nil {
                        NSLog("✅ PDFKitView.swift -> PDFKitView.updateUIView, 方法3成功: 使用编码URL加载PDF")
                    } else {
                        NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 方法3失败: 无法使用编码URL加载PDF")
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
            NSLog("❌ PDFKitView.swift -> PDFKitView.updateUIView, 所有方法均无法加载PDF文档")

            DispatchQueue.main.async {
                self.isPDFLoaded = false
            }
        }
    }

    // 提取导航到指定页面的逻辑为单独的方法
    func navigateToPage(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }

        if let targetPage = document.page(at: page - 1) {
            pdfView.go(to: targetPage)

            // 增加延迟，确保 PDF 视图完全加载
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

                    isPDFLoaded = false
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

    class Coordinator: NSObject, PDFViewDelegate {
        let arrowLayer = CAShapeLayer()
        var xRatio: Double { parent.xRatio }
        var yRatio: Double { parent.yRatio }
        var parent: PDFKitView
        var isLocationMode: Bool = false // 添加这个属性
        var currentOutlineString = "" // 新增属性存储当前大纲路径
        var previousState: (url: URL, page: Int, xRatio: Double, yRatio: Double, forceRender: Bool)?
        var outlineVC: PDFOutlineViewController?

        // directoryManager 属性
        let directoryManager = DirectoryAccessManager.shared

        // 计时器的属性
        private var arrowTimer: Timer?
        private var lastTapXRatio: Double = 0
        private var lastTapYRatio: Double = 0
        // 存储选中文本的属性
        private var selectedText: String = ""
        private var pageText: String = ""
        // 否是翻译模式标识
        private var isTranslationMode: Bool = false

        weak var pdfView: PDFView? // Add a weak reference to the PDFView

        init(_ parent: PDFKitView) {
            self.parent = parent

            super.init()

            // 添加页面变化通知监听器
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pageDidChange(notification:)),
                name: Notification.Name.PDFViewPageChanged,
                object: nil
            )

            // 注册自定义菜单项并设置target为self
            UIMenuController.shared.menuItems = [
                UIMenuItem(title: "翻译", action: #selector(Coordinator.translateSelectedText(_:))),
                UIMenuItem(title: "翻译整页", action: #selector(Coordinator.translateWholePage(_:))),
                UIMenuItem(title: "对话", action: #selector(Coordinator.chatWithSelectedText(_:))),
                UIMenuItem(title: "高亮", action: #selector(Coordinator.highlightSelectedText(_:))),
            ]

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

            // 文本选择通知监听
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextSelection(_:)),
                name: .PDFViewSelectionChanged,
                object: nil
            )
        }

        func convertToViewCoordinates(pdfView: PDFView) -> CGPoint? {
            guard let page = pdfView.currentPage else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, 无法获取 page = pdfView.currentPage")

                return nil
            }

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, 成功获取 page = pdfView.currentPage")

            let pageSize = page.bounds(for: .mediaBox).size

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, PDF页面尺寸 pageSize  = \(pageSize)")

            let xRatio = self.xRatio
            let yRatio = self.yRatio

            // PDF page 页面坐标系（左下角原点）转换为 PDFView 视图坐标系
            let pdfPoint = CGPoint(
                x: pageSize.width * CGFloat(xRatio),
                y: pageSize.height * CGFloat(1 - yRatio) // 翻转 Y 轴
            )

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, PDF page 坐标点 pdfPoint = \(pdfPoint), xRatio = \(xRatio), yRatio = \(yRatio)")

            // 转换为 PDFView 的坐标系
            let viewPoint = pdfView.convert(pdfPoint, from: page)

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.convertToViewCoordinates, 转换后的 pdfView 视图坐标点 viewPoint = \(viewPoint)")

            return viewPoint
        }

        func updateArrowPosition(pdfView: PDFView) {
            guard let position = convertToViewCoordinates(pdfView: pdfView) else {
                NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.updateArrowPosition, 无法获取位置 position  = convertToViewCoordinates(pdfView: pdfView)")

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

            // updateArrowPosition(pdfView: pdfView)
        }

        func pdfViewDidEndDisplayingPage(_: PDFView, page: PDFPage) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidEndDisplayingPage, PDF 页面显示结束: \(page)")
        }

        func pdfViewDidLayoutSubviews(_: PDFView) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidLayoutSubviews, PDF 视图完成子视图布局")

            // updateArrowPosition(pdfView: pdfView)
        }

        // 在析构函数中清理计时器
        // 在析构函数中移除通知监听器
        deinit {
            arrowTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }

        private func showAnnotationDialog(pdfView: PDFView, selectedText: String) {
            // 创建自定义视图控制器而不是使用UIAlertController
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

            // 显示自定义视图控制器
            if let rootViewController = pdfView.window?.rootViewController {
                rootViewController.present(customVC, animated: true) {
                    // 自动聚焦到文本视图
                    textView.becomeFirstResponder()
                }
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let pdfView = recognizer.view as? CustomPDFView else { return }

            // Then check location mode
            guard isLocationMode else {
                return
            }

            let location = recognizer.location(in: pdfView)
            guard let page = pdfView.currentPage else { return }

            // Convert tap location to PDF page coordinates
            let pdfPoint = pdfView.convert(location, to: page)
            let pageBounds = page.bounds(for: .mediaBox)

            // Calculate ratios
            let xRatio = Double(pdfPoint.x / pageBounds.width)
            let yRatio = Double(1 - (pdfPoint.y / pageBounds.height)) // Flip Y axis

            // 保存到存储属性
            lastTapXRatio = xRatio
            lastTapYRatio = yRatio

            // Update position and show arrow
            parent.xRatio = xRatio
            parent.yRatio = yRatio

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.handleTap, handleTap 计算的比例 - xRatio: \(xRatio), yRatio: \(yRatio)")
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.handleTap, handleTap 更新后的 self 中的计算属性 - xRatio: \(self.xRatio), yRatio: \(self.yRatio)")
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.handleTap, handleTap 更新后的 parent 中的计算属性 - xRatio: \(parent.xRatio), yRatio: \(parent.yRatio)")

            updateArrowPosition(pdfView: pdfView)

            // Log outline hierarchy
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

            // Reset auto-hide timer
            arrowTimer?.invalidate()
            arrowTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.5)
                self.arrowLayer.opacity = 0
                CATransaction.commit()
            }

            // Check for text selection first
            if let selectedText = pdfView.currentSelection?.string, !selectedText.isEmpty {
                showAnnotationDialog(pdfView: pdfView, selectedText: selectedText)
            } else {
                // Show annotation dialog
                showAnnotationDialog(pdfView: pdfView, selectedText: "")
            }
        }

        // 处理文本选择
        @objc func handleTextSelection(_ notification: Notification) {
            guard let pdfView = notification.object as? CustomPDFView else { return }
            guard let selection = pdfView.currentSelection else { return }
            guard let selectedText = selection.string, !selectedText.isEmpty else { // 隐藏菜单如果当前没有选择文本
                UIMenuController.shared.hideMenu()
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

                let selectionRect = selection.bounds(for: currentPage)
                let convertedRect = pdfView.convert(selectionRect, from: currentPage)
                // 延迟显示菜单，确保选择状态稳定
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 检查是否仍然有文本被选中，避免在选择消失后显示菜单
                    if let selectionString = pdfView.currentSelection?.string, !selectionString.isEmpty {
                        UIMenuController.shared.showMenu(from: pdfView, rect: convertedRect)
                    }
                }
            }
        }

        // 处理翻译操作
        @objc func translateSelectedText(_: Any) {
            isTranslationMode = true
            showChatView()
        }

        // 添加新的方法来处理"翻译整页"菜单项的点击事件
        @objc func translateWholePage(_: Any) {
            DispatchQueue.main.async {
                self.parent.showChatSheet = true
                self.parent.textToProcess = self.pageText
                self.parent.autoSendMessage = true
            }
        }

        // 处理对话操作
        @objc func chatWithSelectedText(_: Any) {
            isTranslationMode = false
            showChatView()
        }

        // 处理高亮操作
        @objc func highlightSelectedText(_: Any?) {
            // 获取当前PDFView和选中内容
            guard let pdfView = UIResponder.currentFirstResponder as? PDFView,
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
                DispatchQueue.global(qos: .userInitiated).async {
                    // 确保document仍然有效
                    guard let strongDocument = weakDocument else { return }

                    // 在后台线程保存文件
                    strongDocument.write(to: documentURL)

                    // 在主线程更新UI或显示成功消息
                    DispatchQueue.main.async {
                        NSLog("✅ PDFKitView.swift -> highlightSelectedText, 成功将高亮保存到PDF文件")
                        // 可以在这里添加成功提示，如果需要
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

                self.parent.source = formattedSource
                NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.captureCurrentPageAsImage, formattedSource: \(formattedSource)")
            }

            NSLog("✅ PDFKitView.swift -> Coordinator.captureCurrentPageAsImage, Screenshot captured")
            return image
        }

        @objc private func pageDidChange(notification: Notification) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, PDF 页面切换完成")

            // 确保通知来自正确的 PDFView
            guard let pdfView = notification.object as? PDFView,
                  pdfView == self.pdfView
            else {
                return
            }

            // 获取当前页面号并保存到数据库
            if let currentPage = pdfView.currentPage,
               let document = pdfView.document
            {
                let currentPageIndex = document.index(for: currentPage) + 1 // PDFKit使用0基索引，我们使用1基索引

                // 保存当前页面号到数据库
                let _ = DatabaseManager.shared.saveLastVisitedPage(pdfPath: parent.rawPdfPath, page: currentPageIndex)

                NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pageDidChange, 已保存当前文件：\(parent.rawPdfPath)，当前页面号: \(currentPageIndex) 到数据库")
            }
        }
    }
}

class CustomPDFView: PDFView {
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if newSuperview == nil {
            NSLog("✅ PDFKitView.swift -> CustomPDFView.willMove, CustomPDFView 即将从父视图移除")
            NSLog("✅ ")
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            NSLog("✅ PDFKitView.swift -> CustomPDFView.didMoveToSuperview, CustomPDFView已添加到父视图")
        }
    }

    override var canBecomeFirstResponder: Bool { true }

    // 必须声明显式的 @objc 方法来支持 iOS 14
    @objc func translateSelectedText(_ sender: Any?) {
        // 直接通过父视图的coordinator调用方法
        if let coordinator = delegate as? PDFKitView.Coordinator {
            coordinator.translateSelectedText(sender!)
        }
    }

    @objc func translateWholePage(_ sender: Any?) {
        // 直接通过父视图的coordinator调用方法
        if let coordinator = delegate as? PDFKitView.Coordinator {
            coordinator.translateWholePage(sender!)
        }
    }

    @objc func chatWithSelectedText(_ sender: Any?) {
        // 直接通过父视图的coordinator调用方法
        if let coordinator = delegate as? PDFKitView.Coordinator {
            coordinator.chatWithSelectedText(sender!)
        }
    }

    @objc func highlightSelectedText(_ sender: Any?) {
        // 直接通过父视图的coordinator调用方法
        if let coordinator = delegate as? PDFKitView.Coordinator {
            coordinator.highlightSelectedText(sender!)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // 使用明确的 #selector 语法来确保兼容性
        if action == #selector(translateSelectedText(_:)) || action == #selector(translateWholePage(_:)) || action == #selector(chatWithSelectedText(_:)) || action == #selector(highlightSelectedText(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
}
