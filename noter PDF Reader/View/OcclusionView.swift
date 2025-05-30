import SwiftUI
import WebKit

extension UIImage {
    func verticallyFlipped() -> UIImage {
        guard let cgImage = cgImage else { return self }

        let ciImage = CIImage(cgImage: cgImage)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -size.height)
        let transformedCiImage = ciImage.transformed(by: transform)

        let context = CIContext(options: nil)
        guard let flippedCgImage = context.createCGImage(transformedCiImage, from: transformedCiImage.extent) else {
            return self
        }

        return UIImage(cgImage: flippedCgImage, scale: scale, orientation: .up)
    }
}

struct OcclusionView: View {
    var image: UIImage? // Accept UIImage

    var body: some View {
        WebViewContainer(image: image)
          .navigationBarTitleDisplayMode(.inline)
          .navigationTitle("Occlusion")
          .edgesIgnoringSafeArea(.bottom) // WebView 忽略底部安全区域
    }
}

struct WebViewContainer: UIViewRepresentable {
    var image: UIImage?

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        // Add the script message handler here, before creating the webView
        userContentController.add(context.coordinator, name: "ankiDeckExport")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        // 改进的配置
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        // configuration.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // 添加进程池配置
        configuration.processPool = WKProcessPool()

        if #available(iOS 14, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)

        webView.navigationDelegate = context.coordinator // Set navigation delegate

        // 添加错误处理
        webView.allowsBackForwardNavigationGestures = false

        // 获取HTML文件的路径
        if let htmlFileURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "v3") {
            do {
                let htmlData = try Data(contentsOf: htmlFileURL)
                let v3DirectoryURL = htmlFileURL.deletingLastPathComponent()
                webView.load(htmlData, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: v3DirectoryURL)
            } catch {
                NSLog("❌ OcclusionView.swift -> WebViewContainer.makeUIView, Error loading HTML data: \(error.localizedDescription)")
            }
        } else {
            NSLog("❌ OcclusionView.swift -> WebViewContainer.makeUIView, 无法找到 HTML 文件")
        }

        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension WebViewContainer {
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        // MARK: - WKNavigationDelegate

        func webView(_: WKWebView, decidePolicyFor _: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            NSLog("❌ OcclusionView.swift -> WebView provisional navigation failed: \(error.localizedDescription)")

            // 尝试重新加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "v3") {
                    webView.loadFileURL(htmlURL, allowingReadAccessTo: Bundle.main.bundleURL)
                }
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            NSLog("❌ OcclusionView.swift -> WebView navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            guard let originalImage = parent.image else {
                NSLog("❌ OcclusionView.swift -> WebViewContainer.Coordinator.webView, Coordinator.webView.didFinish, Image is nil")
                return
            }
            let image = originalImage.verticallyFlipped() // 先翻转
            guard let imageData = image.pngData(),
                  let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let scale = windowScene.screen.scale as CGFloat?
            else {
                NSLog("❌ OcclusionView.swift -> WebViewContainer.Coordinator.webView, Coordinator.webView.didFinish, Image data is nil or scale is unavailable")
                return
            }
            let base64String = imageData.base64EncodedString()
            let fullBase64String = "data:image/png;base64,\(base64String)"
            let width = image.size.width
            let height = image.size.height
            let script = "addImage('\(fullBase64String)', \(height), \(width));"
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    NSLog("❌ OcclusionView.swift -> WebViewContainer.Coordinator.webView, Coordinator.webView.didFinish, JavaScript evaluation error: \(error.localizedDescription)")
                } else {
                    NSLog("✅ OcclusionView.swift -> WebViewContainer.Coordinator.webView, Coordinator.webView.didFinish, addImage called successfully. Result: \(String(describing: result))")
                }
            }

            // The script message handler is now added in makeUIView
            // No need to add it here:
            // webView.configuration.userContentController.add(self, name: "ankiDeckExport")
            // 注入拦截下载的脚本
            let downloadScript = """
            (function() {
            const originalSaveAs = window.saveAs;
            window.saveAs = function(blob, filename) {
            if (filename === 'Anki-Deck-Export.apkg') {
            const reader = new FileReader();
            reader.onload = function() {
            const base64 = reader.result.split(',')[1];
            webkit.messageHandlers.ankiDeckExport.postMessage(base64);
            };
            reader.readAsDataURL(blob);
            } else {
            originalSaveAs.call(this, blob, filename);
            }
            };
            })();
            """

            webView.evaluateJavaScript(downloadScript) { _, error in
                if let error = error {
                    NSLog("❌ Download script injection error: \(error.localizedDescription)")
                } else {
                    NSLog("✅ Download script injected successfully")
                }
            }
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "ankiDeckExport" {
                if let base64String = message.body as? String {
                    // 解码 Base64 字符串并保存文件
                    if let data = Data(base64Encoded: base64String) {
                        let fileManager = FileManager.default
                        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                            let fileURL = documentsDirectory.appendingPathComponent("Anki-Deck-Export.apkg")
                            do {
                                try data.write(to: fileURL)
                                NSLog("✅ Anki-Deck-Export.apkg saved to: \(fileURL.path)")

                                // 在主线程中显示分享界面
                                DispatchQueue.main.async {
                                    self.shareFile(fileURL: fileURL)
                                }
                            } catch {
                                NSLog("❌ Error saving Anki-Deck-Export.apkg: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }

        private func shareFile(fileURL: URL) {
            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

            // Find the topmost presented view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController
            {
                // Get the topmost view controller
                var topViewController = rootViewController
                while let presentedViewController = topViewController.presentedViewController {
                    topViewController = presentedViewController
                }

                // For iPad, set up popover
                if let popover = activityViewController.popoverPresentationController {
                    popover.sourceView = topViewController.view
                    popover.sourceRect = CGRect(x: topViewController.view.bounds.midX,
                                                y: topViewController.view.bounds.midY,
                                                width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }

                topViewController.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
}

struct OcclusionView_Previews: PreviewProvider {
    static var previews: some View {
        OcclusionView()
    }
}
