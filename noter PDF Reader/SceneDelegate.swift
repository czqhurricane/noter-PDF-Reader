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
        var lastSuccessfulRootPath: String? = UserDefaults.standard.string(forKey: "LastSuccessfulRootPath")

        if let scheme = url.scheme?.lowercased(), scheme == "video" {
            guard let decodedString = url.absoluteString.removingPercentEncoding else { return }
            let rest = decodedString.dropFirst(6) // Remove "video:" prefix
            let parts = rest.split(separator: "#", maxSplits: 1).map(String.init)
            guard !parts.isEmpty else { return }

            var videoUrlString = parts[0]
            var start: String?
            var end: String?

            if parts.count > 1 {
                let fragment = parts[1]
                let timeParts = fragment.split(separator: "-", maxSplits: 1).map(String.init)

                if timeParts.count == 1 {
                    start = timeParts[0]
                } else if timeParts.count == 2 {
                    start = timeParts[0]
                    end = timeParts[1]
                }

                // 将时间戳转换为秒数并添加到 URL 中
                if let startTimeString = start?.trimmingCharacters(in: .whitespacesAndNewlines), let startSeconds = convertTimeToSeconds(startTimeString) {
                    // 检查 URL 是否已经包含参数
                    if videoUrlString.contains("?") {
                        // 如果 URL 已经包含参数，添加 &t=
                        videoUrlString += "&t=\(startSeconds)"
                    } else {
                        // 如果 URL 不包含参数，添加 ?t=
                        videoUrlString += "?t=\(startSeconds)"
                    }
                }

                if videoUrlString.hasPrefix("/") {
                    var startTime: Double = 0
                    var endTime: Double = 0
                    var localVideoUrl: URL

                    let result = PathConverter.convertNoterPagePath(videoUrlString, rootDirectoryURL: URL(fileURLWithPath: lastSuccessfulRootPath!))
                    if let endTimeString = end?.trimmingCharacters(in: .whitespacesAndNewlines), let endSeconds = convertTimeToSeconds(endTimeString) {
                        endTime = Double(endSeconds)
                    }
                    // 解析时间参数
                    if result.contains("?t=") {
                        let components = result.components(separatedBy: "?t=")
                        if components.count > 1, let startTimeValue = components.last, let startSeconds = Double(startTimeValue) {
                            startTime = startSeconds
                            localVideoUrl = URL(string: components[0]) ?? URL(fileURLWithPath: components[0])
                            // 使用我们的 VideoPlayerView 打开
                            let videoPlayerView = VideoPlayerView(videoURL: localVideoUrl, startTime: startTime, endTime: endTime)
                            let hostingController = UIHostingController(rootView: videoPlayerView)
                            UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)

                            NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 本地视频链接: \(components[0])，本地视频 URL: \(localVideoUrl), 开始时间: \(startTime)秒，结束时间：\(endTime)秒")
                        }
                    } else {
                        localVideoUrl = URL(string: result) ?? URL(fileURLWithPath: result)
                        // 使用我们的VideoPlayerView打开
                        let videoPlayerView = VideoPlayerView(videoURL: localVideoUrl, startTime: startTime)
                        let hostingController = UIHostingController(rootView: videoPlayerView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                    }

                    return
                }

                if videoUrlString.hasPrefix("http") {
                    if let videoUrl = URL(string: videoUrlString) {
                        UIApplication.shared.open(videoUrl, options: [:], completionHandler: nil)
                    }

                    NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 网络视频链接: \(videoUrlString), start: \(start), end: \(end)")

                    return
                }
            }
        }

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

    // 将时间格式（如 0:12:15）转换为秒数
    private func convertTimeToSeconds(_ timeString: String) -> Int? {
        let components = timeString.components(separatedBy: ":")
        var seconds = 0

        if components.count == 3 { // 格式为 h:m:s
            if let hours = Int(components[0]),
               let minutes = Int(components[1]),
               let secs = Int(components[2])
            {
                seconds = hours * 3600 + minutes * 60 + secs
            } else {
                return nil
            }
        } else if components.count == 2 { // 格式为 m:s
            if let minutes = Int(components[0]),
               let secs = Int(components[1])
            {
                seconds = minutes * 60 + secs
            } else {
                return nil
            }
        } else if components.count == 1 { // 格式为 s
            if let secs = Int(components[0]) {
                seconds = secs
            } else {
                return nil
            }
        } else {
            return nil
        }

        return seconds
    }
}
