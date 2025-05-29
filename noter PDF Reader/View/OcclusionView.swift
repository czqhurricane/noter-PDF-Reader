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
    @Environment(\.presentationMode) var presentationMode

    var image: UIImage? // Accept UIImage

    var body: some View {
        VStack(spacing: 0) {
            // 模拟导航栏
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss() // 关闭 sheet
                }) {
                    Image(systemName: "chevron.backward")
                        .imageScale(.large)
                        .padding()
                }
                Spacer()
                Text("Occlusion") // 标题
                    .font(.headline)
                Spacer()
                // 可以添加一个占位符让标题居中，或者右侧按钮
                Image(systemName: "chevron.backward")
                    .imageScale(.large)
                    .padding()
                    .opacity(0) // 保持对称，但不可见
            }
            .frame(height: 44) // 标准导航栏高度
            .background(Color(.systemGray6)) // 背景色，可选

            WebViewContainer(image: image)
                .edgesIgnoringSafeArea(.bottom) // WebView 忽略底部安全区域
        }
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

        let webView = WKWebView(frame: .zero, configuration: configuration)

        webView.navigationDelegate = context.coordinator // Set navigation delegate

        // 获取HTML文件的路径
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "v3"),
           let resourceDirectoryPath = Bundle.main.resourcePath?.appending("/v3") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            let resourceDirectoryUrl = URL(fileURLWithPath: resourceDirectoryPath)

            // Use loadFileURL to load the local HTML file and grant access to the resource directory
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: resourceDirectoryUrl)
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

            // 注入 JavaScript 函数来读取文件并发送给 Swift
            let downloadScript = """
                function exportAnkiDeck() {
                    // 假设 Anki-Deck-Export.apkg 已经存在于 IndexedDB 或其他存储中
                    // 这里需要根据 genanki.js 实际的存储方式来获取文件内容
                    // 如果是写入到文件系统，可能需要通过 FileReader 或其他方式读取
                    // 这是一个示例，假设文件内容可以直接获取
                    // 实际情况可能需要更复杂的逻辑来从 IndexedDB 或其他地方读取文件
                    // 例如，如果 genanki.js 使用了 IndexedDB，您需要从 IndexedDB 中读取数据
                    // 或者如果它写入了 WebAssembly 的文件系统，您需要从那里读取

                    // 这是一个占位符，您需要根据 genanki.js 的实际文件保存方式来修改
                    // 假设文件内容可以通过某个全局变量或函数获取
                    // 例如，如果 genanki.js 暴露了一个获取文件内容的函数
                    // var fileContent = getAnkiDeckFileContent();

                    // 为了演示，我们假设文件内容是 Base64 编码的字符串
                    // 您需要替换 'YOUR_BASE64_ENCODED_ANKI_DECK_CONTENT' 为实际的文件内容
                    // 或者调用 genanki.js 中读取文件的方法

                    // 由于 genanki.js 使用了 writeToFile，这通常意味着它写入了 Emscripten 的文件系统
                    // 您需要找到从 Emscripten 文件系统读取文件的方法
                    // 例如，如果 Emscripten 的 FS 对象可用：
                    if (typeof FS !== 'undefined' && FS.readFile) {
                        try {
                            var fileData = FS.readFile('Anki-Deck-Export.apkg', { encoding: 'binary' });
                            var base64String = btoa(String.fromCharCode.apply(null, fileData));
                            window.webkit.messageHandlers.ankiDeckExport.postMessage(base64String);
                        } catch (e) {
                            console.error('Error reading Anki-Deck-Export.apkg from Emscripten FS:', e);
                        }
                    } else {
                        console.error('FS object or FS.readFile not available. Cannot read Anki-Deck-Export.apkg.');
                    }
                }
            """
            webView.evaluateJavaScript(downloadScript) { result, error in
                if let error = error {
                    NSLog("❌ OcclusionView.swift -> WebViewContainer.Coordinator.webView, JavaScript injection error: \(error.localizedDescription)")
                } else {
                    NSLog("✅ OcclusionView.swift -> WebViewContainer.Coordinator.webView, JavaScript injection successful. Result: \(String(describing: result))")
                    // 在这里调用注入的函数来触发文件导出
                    webView.evaluateJavaScript("exportAnkiDeck();") { result, error in
                        if let error = error {
                            NSLog("❌ OcclusionView.swift -> WebViewContainer.Coordinator.webView, exportAnkiDeck call error: \(error.localizedDescription)")
                        } else {
                            NSLog("✅ OcclusionView.swift -> WebViewContainer.Coordinator.webView, exportAnkiDeck called successfully. Result: \(String(describing: result))")
                        }
                    }
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
                                // 可以在这里添加代码来分享文件或通知用户
                            } catch {
                                NSLog("❌ Error saving Anki-Deck-Export.apkg: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}

struct OcclusionView_Previews: PreviewProvider {
    static var previews: some View {
        OcclusionView()
    }
}
