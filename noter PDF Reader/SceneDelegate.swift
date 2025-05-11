import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
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
            NSLog("SceneDelegate scene(_:willConnectTo:options:) 收到 URL 上下文: \(urlContext)")
            handleIncomingURL(urlContext.url)
        }
    }

    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        NSLog("SceneDelegate scene(_:openURLContexts:) 收到 URL 上下文: %@", URLContexts)
        // NSLog("SceneDelegate scene(_:openURLContexts:) 收到 URL 上下文: \(URLContexts)")
        if let urlContext = URLContexts.first {
            // NSLog("SceneDelegate handleIncomingURL 准备处理 URL: \(urlContext.url)")
            handleIncomingURL(urlContext.url)
        } else {
            NSLog("SceneDelegate scene(_:openURLContexts:) 没有收到 URL 上下文")
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "noterpage" else {
            NSLog("SceneDelegate handleIncomingURL 不支持的URL方案: \(url.scheme ?? "nil")")
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

        NSLog("SceneDelegate handleIncomingURL pdfPath: \(pdfPath)")
        NSLog("SceneDelegate handleIncomingURL fragment: \(fragment)")

        var page: Int?
        var xRatio: Double?
        var yRatio: Double?

        // Match pattern: (page yRatio . xRatio)
        let pattern = "(\\d+)\\s+([0-9.]+)\\s+\\.\\s+([0-9.]+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsFragment = fragment as NSString
            if let match = regex.firstMatch(in: fragment, range: NSRange(location: 0, length: nsFragment.length)) {
                page = Int(nsFragment.substring(with: match.range(at: 1)))
                yRatio = Double(nsFragment.substring(with: match.range(at: 2)))
                xRatio = Double(nsFragment.substring(with: match.range(at: 3)))
            }
        }

        NSLog("SceneDelegate handleIncomingURL 解析结果 - 路径: \(pdfPath), 页码: \(page ?? 0), Y: \(yRatio ?? 0), X: \(xRatio ?? 0)")

        // 修改：使用延迟发送通知，确保 ContentView 已完成初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 使用静态字符串常量作为通知名称
            let notificationName = "OpenPDFNotification"
            NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 正在发送通知: \(notificationName)")

            // Post notification with extracted values
            NotificationCenter.default.post(
              name: NSNotification.Name(notificationName),
              object: nil,
              userInfo: [
                "pdfPath": pdfPath,
                "page": page ?? 1,
                "xRatio": xRatio ?? 0.0,
                "yRatio": yRatio ?? 0.0,
              ]
            )

            // 添加额外的日志确认通知已发送
            NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 已发送通知: \(notificationName) 带参数 pdfPath=\(pdfPath) page = \(page ?? 0), xRatio = \(xRatio ?? 0) yRatio = \(yRatio ?? 0)")
        }
    }
}
