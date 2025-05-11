import Foundation
import UIKit

enum PathConverter {
    // 原始iCloud路径
    private static let originalPath = "/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents"

    private static let customPath = ""

    static func convertNoterPagePath(_ path: String, rootDirectoryURL: URL?) -> String {
        guard let rootURL = rootDirectoryURL else {
            return path.replacingOccurrences(of: originalPath, with: customPath)
        }
        return path.replacingOccurrences(of: originalPath, with: rootURL.path)
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
        NSLog("✅ PathConverter.swift -> PathConverter.parseNoterPageLink, 解析结果 - 路径: \(pdfPath), 页码: \(page ?? 0), Y: \(yRatio ?? 0), X: \(xRatio ?? 0)")

        return (pdfPath, page, xRatio, yRatio)
    }
}
