import PDFKit
import SwiftUI

struct PDFKitView: UIViewRepresentable {
    var url: URL
    var page: Int
    var xRatio: Double
    var yRatio: Double

    @Binding var isPDFLoaded: Bool
    @Binding var viewPoint: CGPoint

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

        // 如果文档已加载，则不重新加载
        if pdfView.document != nil {
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
            let scale = 1 / pdfView.scaleFactor
            let rotation = CATransform3DMakeRotation(.pi / 2, 0, 0, 1) // Clockwise 90°
            let scaledRotation = CATransform3DConcat(
                CATransform3DMakeScale(scale, scale, 1),
                rotation
            )
            arrowLayer.transform = scaledRotation

            // 确保图层可见
            arrowLayer.isHidden = false
            arrowLayer.zPosition = 999 // 确保在最上层

            CATransaction.commit()

            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.updateArrowPosition, 箭头位置更新完成")
        }

        // PDFViewDelegate方法
        func pdfViewWillClick(onLink _: PDFView, with _: URL) {
            // 处理PDF内部链接点击
        }

        func pdfViewDidEndPageChange(_ pdfView: PDFView) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidEndPageChange, PDF 页面切换完成")

            updateArrowPosition(pdfView: pdfView)
        }

        func pdfViewDidEndDisplayingPage(_: PDFView, page: PDFPage) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidEndDisplayingPage, PDF 页面显示结束: \(page)")
        }

        func pdfViewDidLayoutSubviews(_ pdfView: PDFView) {
            NSLog("✅ PDFKitView.swift -> PDFKitView.Coordinator.pdfViewDidLayoutSubviews, PDF 视图完成子视图布局")

            updateArrowPosition(pdfView: pdfView)
        }
    }
}
