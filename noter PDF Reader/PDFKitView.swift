import PDFKit
import SwiftUI

struct PDFKitView: UIViewRepresentable {
    var url: URL
    var page: Int
    var xRatio: Double
    var yRatio: Double
    var isLocationMode: Bool // 添加这个属性来控制是否处于位置选择模式
    var rawPdfPath: String

    @Binding var isPDFLoaded: Bool
    @Binding var viewPoint: CGPoint
    @Binding var annotation: String // 绑定到ContentView的注释状态
    @Binding var forceRender: Bool

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

        let pdfView = PDFView()
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

        NSLog("✅ PDFKitView.swift -> PDFKitView.makeUIView, 返回 pdfView = PDFView()")

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isLocationMode = isLocationMode // 更新协调器中的状态

        let currentState = (url: url, page: page, xRatio: xRatio, yRatio: yRatio, forceRender: forceRender)

        if context.coordinator.previousState == nil ||
            context.coordinator.previousState! != currentState
        {
            forceRender = false
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

        // 添加 directoryManager 属性
        let directoryManager = DirectoryAccessManager.shared

        // 添加计时器属性
        private var arrowTimer: Timer?
        private var lastTapXRatio: Double = 0
        private var lastTapYRatio: Double = 0

        init(_ parent: PDFKitView) {
            self.parent = parent

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
        deinit {
            arrowTimer?.invalidate()
        }

        private func showAnnotationDialog(pdfView: PDFView, selectedText: String) {
            if let rootViewController = pdfView.window?.rootViewController {
                let alert = UIAlertController(title: "添加注释", message: nil, preferredStyle: .alert)

                alert.addTextField { textField in
                    textField.placeholder = "输入您的注释"
                    textField.text = selectedText
                }

                let confirmAction = UIAlertAction(title: "确认", style: .default) { _ in
                    if let text = alert.textFields?.first?.text {
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
                    }
                }

                let cancelAction = UIAlertAction(title: "取消", style: .cancel) {
                    _ in NSLog("❌ PDFKitView.swift -> PDFKitView.Coordinator.showAnnotationDialog, 注释输入已取消")
                }

                alert.addAction(confirmAction)
                alert.addAction(cancelAction)

                rootViewController.present(alert, animated: true)
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let pdfView = recognizer.view as? PDFView else { return }

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
    }
}
