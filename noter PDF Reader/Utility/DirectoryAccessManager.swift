import Foundation
import UIKit

class DirectoryAccessManager: ObservableObject {
    @Published var rootDirectoryURL: URL?
    @Published var isScanning: Bool = false
    @Published var scanningProgress: Double = 0
    @Published var errorMessage: String?

    // 添加单例实例
    static let shared = DirectoryAccessManager()

    // 存储所有文件和目录的书签数据
    private var bookmarks: [String: Data] = [:]

    // 扫描目录并创建书签
    func scanDirectory(at url: URL, completion: @escaping () -> Void) {
        isScanning = true
        scanningProgress = 0
        errorMessage = nil

        // 保存当前目录路径到UserDefaults
        UserDefaults.standard.set(url.absoluteString, forKey: "LastSelectedDirectory")

        // 检查是否存在pdf-annotations.db文件
        let dataBasePath = url.appendingPathComponent("pdf-annotations.db").path

        if FileManager.default.fileExists(atPath: dataBasePath) {
            NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 在目录中找到数据库文件: \(dataBasePath)")

            // 发送通知，通知加载数据库
            NotificationCenter.default.post(
                name: NSNotification.Name("LoadAnnotationsDatabase"),
                object: nil,
                userInfo: ["dataBasePath": dataBasePath]
            )
        } else {
            NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 在目录中未找到数据库文件")
        }

        // 获取永久访问权限
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()

        // 在后台线程执行扫描
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // 创建根目录的书签
                let rootBookmark = try url.bookmarkData(options: .minimalBookmark,
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil)

                DispatchQueue.main.async {
                    self.rootDirectoryURL = url
                    self.bookmarks[url.path] = rootBookmark
                    UserDefaults.standard.set(rootBookmark, forKey: "RootDirectoryBookmark")

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 成功创建根目录书签: \(url.path)")
                }

                // 递归扫描目录
                var allFiles: [URL] = []
                var processedCount = 0

                // 获取所有文件和目录
                let fileManager = FileManager.default
                let enumerator = fileManager.enumerator(at: url,
                                                        includingPropertiesForKeys: [.isDirectoryKey],
                                                        options: [.skipsHiddenFiles],
                                                        errorHandler: nil)

                if let allURLs = enumerator?.allObjects as? [URL] {
                    allFiles = allURLs

                    // 计算总文件数用于进度显示
                    let totalCount = allFiles.count

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 找到 \(totalCount) 个文件和目录")

                    for fileURL in allFiles {
                        autoreleasepool {
                            do {
                                // 为每个文件创建书签
                                let bookmark = try fileURL.bookmarkData(options: .minimalBookmark,
                                                                        includingResourceValuesForKeys: nil,
                                                                        relativeTo: nil)

                                DispatchQueue.main.async {
                                    self.bookmarks[fileURL.path] = bookmark
                                }

                                // 更新进度
                                processedCount += 1
                                let progress = Double(processedCount) / Double(totalCount)

                                DispatchQueue.main.async {
                                    self.scanningProgress = progress
                                }
                            } catch {
                                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 无法为文件创建书签: \(fileURL.path), 错误: \(error.localizedDescription)")
                            }
                        }
                    }

                    // 保存所有书签到 UserDefaults
                    DispatchQueue.main.async {
                        // 将书签字典转换为可序列化的格式
                        var serializableBookmarks: [String: Data] = [:]
                        for (path, bookmarkData) in self.bookmarks {
                            serializableBookmarks[path] = bookmarkData
                        }

                        // 保存到 UserDefaults
                        UserDefaults.standard.set(serializableBookmarks, forKey: "FileBookmarks")
                        self.scanningProgress = 1.0

                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 目录扫描完成，创建了 \(serializableBookmarks.count) 个书签")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "扫描目录失败: \(error.localizedDescription)"
                    self.isScanning = false

                    NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 扫描目录失败: \(error.localizedDescription)")
                }
            }

            // 停止访问资源
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                self.isScanning = false
                completion()
            }
        }
    }

    // 根据路径获取URL，自动处理安全访问
    func getSecureURL(for path: String) -> URL? {
        // 检查是否有书签
        guard let bookmark = bookmarks[path] else {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.getSecureURL, 未找到该路径的书签: \(path)")

            return nil
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)

            if isStale {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.getSecureURL, 该路径的书签已过期: \(path)")

                return nil
            }

            return url
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.getSecureURL, 无法解析书签: \(error.localizedDescription)")
            return nil
        }
    }

    // 打开文件并获取安全访问权限
    func startAccessingFile(at path: String) -> URL? {
        guard let url = getSecureURL(for: path) else {
            return nil
        }

        // 开始访问资源
        let success = url.startAccessingSecurityScopedResource()
        if success {
            NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.startAccessingFile, 成功开始访问文件: \(path)")
        } else {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.startAccessingFile, 无法开始访问文件: \(path)")
        }

        return success ? url : nil
    }

    // 停止访问文件
    func stopAccessingFile(at url: URL) {
        url.stopAccessingSecurityScopedResource()

        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.stopAccessingFile, 停止访问文件: \(url.path)")
    }

    // 恢复之前保存的书签
    func restoreSavedBookmarks() {
        if let rootBookmark = UserDefaults.standard.data(forKey: "RootDirectoryBookmark") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: rootBookmark,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)

                if !isStale {
                    rootDirectoryURL = url

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已恢复根目录书签")

                    // 恢复所有文件书签
                    if let savedBookmarks = UserDefaults.standard.dictionary(forKey: "FileBookmarks") as? [String: Data] {
                        bookmarks = savedBookmarks

                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已恢复 \(savedBookmarks.count) 个文件书签")
                    }
                } else {
                    NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 根目录书签已过期")
                }
            } catch {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 无法恢复根目录书签: \(error.localizedDescription)")
            }
        }
    }

    // 检查是否有特定路径的访问权限
    func hasAccessTo(path: String) -> Bool {
        return bookmarks[path] != nil
    }

    // 检查是否有对指定路径的访问权限
    func hasAccessToFile(at path: String) -> Bool {
        // 检查文件是否存在
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.hasAccessToFile, 文件不存在: \(path)")

            return false
        }

        // 尝试获取访问权限
        guard let accessibleURL = startAccessingFile(at: path) else {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.hasAccessToFile, 无法获取文件访问权限: \(path)")

            return false
        }

        // 检查是否可读
        let isReadable = fileManager.isReadableFile(atPath: accessibleURL.path)

        // 停止访问文件
        stopAccessingFile(at: accessibleURL)

        if !isReadable {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.hasAccessToFile, 文件不可读: \(path)")
        }

        return isReadable
    }
}
