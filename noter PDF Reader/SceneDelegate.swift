import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    static var pendingPDFInfo: [String: Any]? = nil
    static var pendingVideoInfo: [String: Any]? = nil

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
        let lastSuccessfulRootPath: String? = UserDefaults.standard.string(forKey: "LastSuccessfulRootPath") ?? DirectoryAccessManager.shared.rootDirectoryURL?.path

        // 处理 id scheme
        if let scheme = url.scheme?.lowercased(), scheme == "id" {
            guard let decodedString = url.absoluteString.removingPercentEncoding else { return }

            // 提取 ID 部分
            let idComponents = decodedString.components(separatedBy: ":")
            guard idComponents.count > 1 else {
                NSLog("❌ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, ID 格式不正确: \(decodedString)")

                return
            }

            let nodeId = idComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)

            NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 提取到节点 ID: \(nodeId)")

            // 获取 org-roam 目录
            guard let orgRoamDirectoryURL = DirectoryAccessManager.shared.orgRoamDirectoryURL else {
                NSLog("❌ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, org-roam 目录未设置")

                return
            }

            // 构建 org-roam.db 路径
            let orgRoamDBPath = orgRoamDirectoryURL.appendingPathComponent("org-roam.db").path

            // 检查数据库文件是否存在
            guard FileManager.default.fileExists(atPath: orgRoamDBPath) else {
                NSLog("❌ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, org-roam.db 数据库文件不存在: \(orgRoamDBPath)")

                return
            }

            // 查询文件路径
            guard let filePath = DatabaseManager.shared.getFilePathByNodeId("\"\(nodeId)\"", orgRoamDBPath: orgRoamDBPath) else {
                NSLog("❌ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 未找到节点对应的文件路径: \(nodeId)")

                return
            }

            // 从文件路径中提取文件名（去除双引号）
            let cleanedFilePath = filePath.trimmingCharacters(in: .init(charactersIn: "\""))
            let fileName = URL(fileURLWithPath: cleanedFilePath).lastPathComponent

            NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 提取到文件名: \(fileName)")

            // 在 orgRoamDirectoryURL 中递归搜索文件
            guard let fileURL = DirectoryAccessManager.shared.findFileInDirectory(fileName: fileName, directory: orgRoamDirectoryURL) else {
                NSLog("❌ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 在目录中未找到文件: \(fileName)")

                return
            }

            // 使用 iOS 系统推荐的方式打开文件
            DispatchQueue.main.async {
                UIApplication.shared.open(fileURL, options: [:]) { success in
                    if success {
                        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 成功打开文件: \(fileURL.path)")
                    } else {
                        NSLog("❌ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 无法打开文件: \(fileURL.path)")
                    }
                }
            }

            return
        } else if let scheme = url.scheme?.lowercased(), scheme == "video" {
            guard let decodedString = url.absoluteString.removingPercentEncoding else { return }
            // 移除前缀 video
            let rest = String(decodedString.dropFirst(6))
            let parts = rest.split(separator: "#", maxSplits: 1).map(String.init)
            guard !parts.isEmpty else { return }

            if parts.count == 1 {
                let result = PathConverter.convertNoterPagePath(parts[0], rootDirectoryURL: URL(fileURLWithPath: lastSuccessfulRootPath!))
                SceneDelegate.pendingVideoInfo = [
                    "localVideoPath": result.trimmingCharacters(in: .whitespacesAndNewlines),
                    "startTime": 0.0,
                    "endTime": 0.0,
                ]

                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenVideoNotification"),
                    object: nil,
                    userInfo: [
                        "localVideoPath": result.trimmingCharacters(in: .whitespacesAndNewlines),
                        "startTime": 0.0,
                        "endTime": 0.0,
                    ]
                )

                return
            }

            if parts.count > 1 {
                var videoUrlString = parts[0]
                var start: String?
                var end: String?

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
                        if videoUrlString.contains("bilibili.com") {
                            // 如果 URL 已经包含参数，添加 &t=
                            videoUrlString += "&start_progress=\(startSeconds * 1000)"
                        } else { // 如果 URL 已经包含参数，添加 &t=
                            videoUrlString += "&t=\(startSeconds)"
                        }
                    } else {
                        if videoUrlString.contains("bilibili.com") {
                            // 如果 URL 不包含参数，添加 ?t=
                            videoUrlString += "?start_progress=\(startSeconds * 1000)"
                        } else {
                            // 如果 URL 不包含参数，添加 ?t=
                            videoUrlString += "?t=\(startSeconds)"
                        }
                    }
                }

                if videoUrlString.hasPrefix("/") {
                    var startTime = 0.0
                    var endTime = 0.0
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

                            SceneDelegate.pendingVideoInfo = [
                                "localVideoPath": components[0],
                                "startTime": startTime ?? 0.0,
                                "endTime": endTime ?? 0.0,
                            ]

                            NotificationCenter.default.post(
                                name: NSNotification.Name("OpenVideoNotification"),
                                object: nil,
                                userInfo: [
                                    "localVideoPath": components[0],
                                    "startTime": startTime ?? 0.0,
                                    "endTime": endTime ?? 0.0,
                                ]
                            )

                            NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 本地视频 path: \(components[0])，开始时间: \(startTime)秒，结束时间：\(endTime)秒")

                            return
                        }
                    } else {
                        SceneDelegate.pendingVideoInfo = [
                            "localVideoPath": result.trimmingCharacters(in: .whitespacesAndNewlines),
                            "startTime": 0.0,
                            "endTime": 0.0,
                        ]

                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenVideoNotification"),
                            object: nil,
                            userInfo: [
                                "localVideoPath": result.trimmingCharacters(in: .whitespacesAndNewlines),
                                "startTime": 0.0,
                                "endTime": 0.0,
                            ]
                        )

                        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 本地视频 path: \(result)，开始时间: \(startTime)秒，结束时间：\(endTime)秒")
                    }

                    return
                } else if videoUrlString.hasPrefix("http") {
                    if let videoUrl = URL(string: videoUrlString) {
                        UIApplication.shared.open(videoUrl, options: [:], completionHandler: nil)
                    }

                    NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 网络视频链接: \(String(describing: videoUrlString)), start: \(String(describing: start)), end: \(String(describing: end))")

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

        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 解析结果，路径: \(pdfPath), 页码: \(page ?? 0), yRatio: \(yRatio ?? 0), xRatio: \(xRatio ?? 0)")

        SceneDelegate.pendingPDFInfo = [
            "decodedString": decodedString,
            "pdfPath": pdfPath,
            "page": page ?? 1,
            "xRatio": xRatio ?? 0.0,
            "yRatio": yRatio ?? 0.0,
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
        NSLog("✅ SceneDelegate.swift -> SceneDelegate.handleIncomingURL, 已发送通知 OpenPDFNotification 带参数，pdfPath: \(pdfPath), page: \(page ?? 0), xRatio: \(xRatio ?? 0), yRatio: \(yRatio ?? 0)")
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
