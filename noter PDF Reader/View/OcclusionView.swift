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
        let webView = WKWebView()

        webView.navigationDelegate = context.coordinator // Set navigation delegate

        // 获取HTML文件的路径
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "v3") {
            let url = URL(fileURLWithPath: htmlPath)
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            NSLog("❌ OcclusionView.swift -> WebViewContainer.makeUIView, 无法找到 HTML 文件")
        }

        webView.navigationDelegate = context.coordinator // 设置 navigationDelegate

        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
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
        }
    }
}

struct OcclusionView_Previews: PreviewProvider {
    static var previews: some View {
        OcclusionView()
    }
}
