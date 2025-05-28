import SwiftUI
import WebKit

struct OcclusionView: View {
    var body: some View {
        WebViewContainer()
            .edgesIgnoringSafeArea(.all)
            .navigationBarTitle("Occlusion", displayMode: .inline)
    }
}

struct WebViewContainer: UIViewRepresentable {
    func makeUIView(context _: Context) -> WKWebView {
        let webView = WKWebView()

        // 获取HTML文件的路径
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "v3") {
            let url = URL(fileURLWithPath: htmlPath)
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("无法找到HTML文件")
        }

        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        // 更新视图（如果需要）
    }
}

struct OcclusionView_Previews: PreviewProvider {
    static var previews: some View {
        OcclusionView()
    }
}
