import FMDB
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

    // 添加新的方法用于保存和加载根目录书签到文件系统
    private func saveRootBookmarkToFile(_ bookmarkData: Data) -> Bool {
        do {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let bookmarkFile = documentsDirectory.appendingPathComponent("RootDirectoryBookmark.data")

            try bookmarkData.write(to: bookmarkFile)
            NSLog("✅ DirectoryAccessManager.swift -> saveRootBookmarkToFile, 成功保存根目录书签到文件")
            return true
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> saveRootBookmarkToFile, 保存根目录书签到文件失败: \(error.localizedDescription)")
            return false
        }
    }

    private func loadRootBookmarkFromFile() -> Data? {
        do {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let bookmarkFile = documentsDirectory.appendingPathComponent("RootDirectoryBookmark.data")

            if fileManager.fileExists(atPath: bookmarkFile.path) {
                let bookmarkData = try Data(contentsOf: bookmarkFile)
                NSLog("✅ DirectoryAccessManager.swift -> loadRootBookmarkFromFile, 成功从文件加载根目录书签")
                return bookmarkData
            } else {
                NSLog("❌ DirectoryAccessManager.swift -> loadRootBookmarkFromFile, 根目录书签文件不存在")
                return nil
            }
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> loadRootBookmarkFromFile, 从文件加载根目录书签失败: \(error.localizedDescription)")
            return nil
        }
    }

    // 保存书签到数据库
    private func saveBookmarksToDatabase(_ bookmarks: [String: Data]) -> Bool {
        // 确保数据库已初始化
        guard let rootURL = rootDirectoryURL else {
            NSLog("❌ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 根目录URL未设置")
            return false
        }

        let dataBasePath = rootURL.appendingPathComponent("pdf-annotations.db").path

        // 检查数据库是否存在
        guard FileManager.default.fileExists(atPath: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 数据库文件不存在: \(dataBasePath)")
            return false
        }

        guard let dbQueue = FMDatabaseQueue(path: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 无法打开数据库")
            return false
        }

        var success = true

        dbQueue.inDatabase { db in
            // 创建书签表（如果不存在）
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS file_bookmarks (
                path TEXT PRIMARY KEY,
                bookmark_data BLOB NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """

            if !db.executeStatements(createTableSQL) {
                NSLog("❌ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 创建书签表失败")
                success = false
                return
            }

            // 开始事务
            db.beginTransaction()

            // 清空现有书签
            if !db.executeUpdate("DELETE FROM file_bookmarks", withArgumentsIn: []) {
                NSLog("❌ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 清空书签表失败")
                db.rollback()
                success = false
                return
            }

            // 插入新书签
            for (path, bookmarkData) in bookmarks {
                let insertSQL = "INSERT INTO file_bookmarks (path, bookmark_data) VALUES (?, ?)"
                if !db.executeUpdate(insertSQL, withArgumentsIn: [path, bookmarkData]) {
                    NSLog("❌ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 插入书签失败: \(path)")
                    success = false
                    break
                }
            }

            // 提交或回滚事务
            if success {
                db.commit()
                NSLog("✅ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 成功保存 \(bookmarks.count) 个书签到数据库")
            } else {
                db.rollback()
                NSLog("❌ DirectoryAccessManager.swift -> saveBookmarksToDatabase, 保存书签到数据库失败，已回滚")
            }
        }

        dbQueue.close()
        return success
    }

    // 从数据库加载书签
    private func loadBookmarksFromDatabase() -> [String: Data]? {
        // 确保根目录URL已设置
        guard let rootURL = rootDirectoryURL else {
            NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 根目录URL未设置")
            return nil
        }

        let dataBasePath = rootURL.appendingPathComponent("pdf-annotations.db").path

        // 检查数据库是否存在
        guard FileManager.default.fileExists(atPath: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 数据库文件不存在: \(dataBasePath)")
            return nil
        }

        guard let dbQueue = FMDatabaseQueue(path: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 无法打开数据库")
            return nil
        }

        var loadedBookmarks: [String: Data] = [:]
        var success = false

        dbQueue.inDatabase { db in
            // 检查表是否存在
            let tableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='file_bookmarks'"
            if let result = db.executeQuery(tableExistsQuery, withArgumentsIn: []) {
                let tableExists = result.next()
                result.close()

                if tableExists {
                    // 查询所有书签
                    let querySQL = "SELECT path, bookmark_data FROM file_bookmarks"
                    if let queryResult = db.executeQuery(querySQL, withArgumentsIn: []) {
                        while queryResult.next() {
                            if let path = queryResult.string(forColumn: "path"),
                               let bookmarkData = queryResult.data(forColumn: "bookmark_data")
                            {
                                loadedBookmarks[path] = bookmarkData
                            }
                        }
                        queryResult.close()
                        success = true
                        NSLog("✅ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 成功从数据库加载 \(loadedBookmarks.count) 个书签")
                    } else {
                        NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 查询书签失败: \(db.lastErrorMessage())")
                    }
                } else {
                    NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, file_bookmarks表不存在")
                }
            }
        }

        dbQueue.close()
        return success ? loadedBookmarks : nil
    }

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

            // 清空并重新填充files表
            updateFilesTable(at: dataBasePath, rootURL: url)

            // 发送通知，通知加载数据库
            NotificationCenter.default.post(
                name: NSNotification.Name("LoadAnnotationsDatabase"),
                object: nil,
                userInfo: ["dataBasePath": dataBasePath]
            )

        } else {
            NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 在目录中未找到数据库文件，开始创建")

            // 创建数据库文件并初始化表结构
            if DatabaseManager.shared.initializeDatabase(at: dataBasePath) {
                NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 成功创建并初始化数据库: \(dataBasePath)")

                // 添加延迟确保数据库初始化完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }

                    // 清空并重新填充files表
                    self.updateFilesTable(at: dataBasePath, rootURL: url)

                    // 发送通知，通知加载新创建的数据库
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LoadAnnotationsDatabase"),
                        object: nil,
                        userInfo: ["dataBasePath": dataBasePath]
                    )
                }
            } else {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 创建数据库失败: \(dataBasePath)")

                // 添加重试逻辑
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }

                    NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 尝试重新创建数据库")

                    if DatabaseManager.shared.initializeDatabase(at: dataBasePath) {
                        self.updateFilesTable(at: dataBasePath, rootURL: url)

                        NotificationCenter.default.post(
                            name: NSNotification.Name("LoadAnnotationsDatabase"),
                            object: nil,
                            userInfo: ["dataBasePath": dataBasePath]
                        )
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "创建数据库失败，请重试"
                        }
                    }
                }
            }
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

                    // 同时保存到 UserDefaults 和文件系统

                    UserDefaults.standard.set(rootBookmark, forKey: "RootDirectoryBookmark")
                    _ = self.saveRootBookmarkToFile(rootBookmark)

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

                    // 保存所有书签到 UserDefaults 和数据库
                    DispatchQueue.main.async {
                        // 将书签字典转换为可序列化的格式
                        var serializableBookmarks: [String: Data] = [:]
                        for (path, bookmarkData) in self.bookmarks {
                            serializableBookmarks[path] = bookmarkData
                        }

                        // 保存到 UserDefaults
                        UserDefaults.standard.set(serializableBookmarks, forKey: "FileBookmarks")
                        // 保存到数据库（在数据库初始化后）
                        _ = self.saveBookmarksToDatabase(serializableBookmarks)
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
            NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.startAccessingFile, 成功获取安全访问权限: \(path)")
        } else {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.startAccessingFile, 无法获取安全访问权限: \(path)")
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
        // 首先尝试从文件加载根目录书签
        if let rootBookmark = loadRootBookmarkFromFile() {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: rootBookmark,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)

                if !isStale {
                    rootDirectoryURL = url
                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已从文件恢复根目录书签")

                    // 尝试从数据库加载所有书签
                    if let savedBookmarks = loadBookmarksFromDatabase() {
                        bookmarks = savedBookmarks
                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已从数据库恢复 \(savedBookmarks.count) 个文件书签")
                        return
                    }
                }
            } catch {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 无法从文件恢复根目录书签: \(error.localizedDescription)")
            }
        }

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

    // 更新数据库中的files表
    private func updateFilesTable(at dbPath: String, rootURL: URL) {
        guard let dbQueue = FMDatabaseQueue(path: dbPath) else {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.updateFilesTable, 无法打开数据库")

            return
        }

        dbQueue.inDatabase { db in
            // 创建files表（如果不存在）
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS files (
                file TEXT UNIQUE PRIMARY KEY,
                title TEXT NOT NULL
            )
            """

            if !db.executeStatements(createTableSQL) {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.updateFilesTable, 创建 files 表失败")

                return
            }

            // 清空files表
            if !db.executeUpdate("DELETE FROM files", withArgumentsIn: []) {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.updateFilesTable, 清空 files 表失败")

                return
            }

            // 遍历所有PDF文件并插入到files表
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(at: rootURL,
                                                    includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: [.skipsHiddenFiles],
                                                    errorHandler: nil)

            if let allURLs = enumerator?.allObjects as? [URL] {
                for fileURL in allURLs {
                    if fileURL.pathExtension.lowercased() == "pdf" {
                        let filePath = fileURL.path
                        let fileName = fileURL.deletingPathExtension().lastPathComponent
                        // 将 filePath 转换为 rawPath
                        let rawPath = convertToRawPath(filePath)

                        let insertSQL = "INSERT INTO files (file, title) VALUES (?, ?)"
                        if !db.executeUpdate(insertSQL, withArgumentsIn: [rawPath, fileName]) {
                            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.updateFilesTable, 插入文件记录失败: \(rawPath)")
                        }
                    }
                }
            }

            NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.updateFilesTable, files表更新完成")
        }

        dbQueue.close()
    }

    func convertToRawPath(_ path: String) -> String {
        // 获取当前的 rootDirectoryURL
        let rootPath: String

        if let rootURL = rootDirectoryURL {
            rootPath = rootURL.path
        } else if let cachedPath = UserDefaults.standard.string(forKey: "LastSuccessfulRootPath") {
            rootPath = cachedPath
        } else {
            return path // 无法转换，返回原始路径
        }

        // 获取原始路径
        var processedOriginalPath = PathConverter.originalPath
        if processedOriginalPath.hasSuffix("/") {
            processedOriginalPath.removeLast()
        }

        // 执行反向替换
        return path.replacingOccurrences(of: rootPath, with: processedOriginalPath)
    }
}
