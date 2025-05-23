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
        NSLog("✅ PathConverter.swift -> PathConverter.parseNoterPageLink, 解析结果 - 路径: \(pdfPath), 页码: \(page ?? 0), yRatio: \(yRatio ?? 0), xRatio: \(xRatio ?? 0)")

        return (pdfPath, page, xRatio, yRatio)
    }
}
