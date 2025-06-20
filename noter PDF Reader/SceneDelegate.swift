import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    static var pendingPDFInfo: [String: Any]? = nil
    static var decodedStringInfo: [String: Any]? = nil

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 创建SwiftUI视图
        let contentView = ContentView()

        // 使用UIHostingController作为窗口的根视图控制器
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }

        // 处理传入的URL
        if let urlContext = connectionOptions.urlContexts.first {
            NSLog("✅ SceneDelegate.swift -> SceneDelegate.scene(_:willConnectTo:options:), 收到 URL 上下文: \(urlContext)")

            handleIncomingURL(urlContext.url)
        }
    }

    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        NSLog("✅ SceneDelegate.swift -> SceneDelegate.scene(_:openURLContexts:), 收到 URL 上下文: %@", URLContexts)

        if let urlContext = URLContexts.first {
            let receivedURL = urlContext.url

            handleIncomingURL(receivedURL)

            guard let decodedString = receivedURL.absoluteString.removingPercentEncoding else { return }

            // 使用通知中心发送URL
            NotificationCenter.default.post(
                name: Notification.Name("ReceivedURLNotification"),
                object: nil,
                userInfo: ["decodedString": decodedString]
            )
        } else {
            NSLog("❌ SceneDelegate.swift -> SceneDelegate.scene, 没有收到 URL 上下文")

            return
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "noterpage" else {
            NSLog("❌ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 不支持的URL方案: \(url.scheme ?? "nil")")

            return
        }

        guard let decodedString = url.absoluteString.removingPercentEncoding else { return }
        let cleanComponents = decodedString.components(separatedBy: ":")
        guard cleanComponents.count > 1 else { return }
        let fullPathFragment = cleanComponents[1...].joined(separator: ":")
        let pathParts = fullPathFragment.components(separatedBy: "#")
        let rawPath = pathParts.first ?? ""
        let pdfPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let fragment = pathParts.dropFirst().joined(separator: "#")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))

        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, pdfPath: \(pdfPath), fragment: \(fragment)")

        var page: Int?
        var xRatio: Double?
        var yRatio: Double?

        // 匹配模式：(页面 y 比例 . x 比例)
        let pattern = "(\\d+)\\s+([0-9.]+)\\s+\\.\\s+([0-9.]+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsFragment = fragment as NSString
            if let match = regex.firstMatch(in: fragment, range: NSRange(location: 0, length: nsFragment.length)) {
                page = Int(nsFragment.substring(with: match.range(at: 1)))
                yRatio = Double(nsFragment.substring(with: match.range(at: 2)))
                xRatio = Double(nsFragment.substring(with: match.range(at: 3)))
            }
        }

        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 解析结果 - 路径: \(pdfPath), 页码: \(page ?? 0), yRatio: \(yRatio ?? 0), xRatio: \(xRatio ?? 0)")

        SceneDelegate.pendingPDFInfo = [
            "decodedString": decodedString,
            "pdfPath": pdfPath,
            "page": page ?? 1,
            "xRatio": xRatio ?? 0.0,
            "yRatio": yRatio ?? 0.0,
        ]

        SceneDelegate.decodedStringInfo = [
            "decodedString": decodedString,
        ]

        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 存储 PDF 信息，等待应用初始化完成")

        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 正在发送通知: OpenPDFNotification")

        NotificationCenter.default.post(
            name: NSNotification.Name("OpenPDFNotification"),
            object: nil,
            userInfo: [
                "pdfPath": pdfPath,
                "page": page ?? 0,
                "xRatio": xRatio ?? 0.0,
                "yRatio": yRatio ?? 0.0,
            ]
        )

        // 添加额外的日志确认通知已发送
        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 已发送通知: OpenPDFNotification 带参数 pdfPath=\(pdfPath) page = \(page ?? 0), xRatio = \(xRatio ?? 0) yRatio = \(yRatio ?? 0)")
    }
}
