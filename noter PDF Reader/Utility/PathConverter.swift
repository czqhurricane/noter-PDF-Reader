import Foundation
import UIKit

enum PathConverter {
    // 用户配置的原始路径
    static var originalPath = UserDefaults.standard.string(forKey: "OriginalPath") ?? ""

    private static let customPath = ""
    // 缓存最后一次成功的根目录路径
    private static var lastSuccessfulRootPath: String? = UserDefaults.standard.string(forKey: "LastSuccessfulRootPath")

    static func convertNoterPagePath(_ path: String, rootDirectoryURL: URL?) -> String {
        // 确保每次调用时都处理原始路径，移除结尾的斜杠
        var processedOriginalPath = originalPath
        if processedOriginalPath.hasSuffix("/") {
            processedOriginalPath.removeLast()
        }
        if let rootURL = rootDirectoryURL {
            // 更新缓存
            lastSuccessfulRootPath = rootURL.path
            UserDefaults.standard.set(rootURL.path, forKey: "LastSuccessfulRootPath")

            NSLog("✅ PathConverter.swift -> PathConverter.convertNoterPagePath, 原始路径：\(originalPath)")

            return path.replacingOccurrences(of: processedOriginalPath, with: rootURL.path)
        } else if let cachedPath = lastSuccessfulRootPath {
            NSLog("❌ PathConverter.swift -> PathConverter.convertNoterPagePath, 使用缓存的根目录路径：\(cachedPath)")

            return path.replacingOccurrences(of: processedOriginalPath, with: cachedPath)
        } else {
            NSLog("❌ PathConverter.swift -> PathConverter.convertNoterPagePath, 无可用根目录，返回原始路径")

            return path
        }
    }

    static func parseNoterPageLink(_ url: String) -> (pdfPath: String, page: Int?, x: Double?, y: Double?)? {
        guard let decodedString = url.removingPercentEncoding else { return nil }
        let cleanComponents = decodedString.components(separatedBy: ":")
        guard cleanComponents.count > 1 else { return nil }
        let fullPathFragment = cleanComponents[1...].joined(separator: ":")
        let pathParts = fullPathFragment.components(separatedBy: "#")
        let rawPath = pathParts.first ?? ""
        let pdfPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let fragment = pathParts.dropFirst().joined(separator: "#")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))

        NSLog("✅ PathConverter.swift -> PathConverter.parseNoterPageLink, pdfPath: \(pdfPath), fragment: \(fragment)")

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
        NSLog("✅ PathConverter.swift -> PathConverter.parseNoterPageLink, 解析结果 - 路径: \(pdfPath), 页码: \(page ?? 0), yRatio: \(yRatio ?? 0), xRatio: \(xRatio ?? 0)")

        return (pdfPath, page, xRatio, yRatio)
    }

    static func parseVideoLink(_ url: String) -> (videoUrlString: String, start: String?, end: String?)? {
        guard url.hasPrefix("video:"),
              let decodedString = url.removingPercentEncoding
        else {
            return nil
        }

        let rest = String(decodedString.dropFirst(6)) // Remove "video:" prefix
        let parts = rest.split(separator: "#", maxSplits: 1).map(String.init)
        guard !parts.isEmpty else { return nil }

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
            if let startTime = start?.trimmingCharacters(in: .whitespacesAndNewlines), let seconds = convertTimeToSeconds(startTime) {
                // 检查 URL 是否已经包含参数
                if videoUrlString.contains("?") {
                    // 如果 URL 已经包含参数，添加 &t=
                    videoUrlString += "&t=\(seconds)"
                } else {
                    // 如果 URL 不包含参数，添加 ?t=
                    videoUrlString += "?t=\(seconds)"
                }
            }
        }

        NSLog("✅ PathConverter.swift -> PathConverter.parseVideoLink, 解析结果 - 视频 URL: \(videoUrlString), start: \(start), end: \(end)")
        return (videoUrlString, start, end)
    }

    // 将时间格式（如 0:12:15）转换为秒数
    static func convertTimeToSeconds(_ timeString: String) -> Int? {
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
