import FMDB
import Foundation
import UIKit

class DirectoryAccessManager: ObservableObject {
    @Published var rootDirectoryURL: URL?
    @Published var orgRoamDirectoryURL: URL?
    @Published var isScanningRootDirectory: Bool = false
    @Published var isScanningOrgRoamDirectory: Bool = false
    @Published var scanningRootDirectoryProgress: Double = 0.0
    @Published var scanningOrgRoamDirectoryProgress: Double = 0.0
    @Published var errorMessageForRootDirectory: String?
    @Published var errorMessageForOrgRoamDirectory: String?

    // 添加单例实例
    static let shared = DirectoryAccessManager()

    // 存储所有文件和目录的书签数据
    var bookmarks: [String: Data] = [:]
    var pdfBookmarks: [String: Data] = [:]
    var orgBookmarks: [String: Data] = [:]

    // 保存和加载 PDF 根目录书签到文件系统
    private func saveRootDirectoryBookmarkToFile(_ bookmarkData: Data) -> Bool {
        do {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let bookmarkFile = documentsDirectory.appendingPathComponent("RootDirectoryBookmark.data")

            try bookmarkData.write(to: bookmarkFile)

            NSLog("✅ DirectoryAccessManager.swift -> saveRootDirectoryBookmarkToFile, 成功保存 PDF 根目录书签到 RootDirectoryBookmark.data 文件")

            return true
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> saveRootDirectoryBookmarkToFile, 保存 PDF 根目录书签到 RootDirectoryBookmark.data 文件失败: \(error.localizedDescription)")

            return false
        }
    }

    // 保存和加载 org 根目录书签到文件系统
    private func saveOrgRoamDirectoryBookmarkToFile(_ bookmarkData: Data) -> Bool {
        do {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let bookmarkFile = documentsDirectory.appendingPathComponent("OrgRoamDirectoryBookmark.data")

            try bookmarkData.write(to: bookmarkFile)

            NSLog("✅ DirectoryAccessManager.swift -> saveOrgRoamDirectoryBookmarkToFile, 成功保存 org 根目录书签到 OrgRoamDirectoryBookmark.data 文件")

            return true
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> saveOrgRoamDirectoryBookmarkToFile, 保存 org 根目录书签到 OrgRoamDirectoryBookmark.data 文件失败: \(error.localizedDescription)")

            return false
        }
    }

    private func loadRootDirectoryBookmarkFromFile() -> Data? {
        do {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let bookmarkFile = documentsDirectory.appendingPathComponent("RootDirectoryBookmark.data")

            if fileManager.fileExists(atPath: bookmarkFile.path) {
                let bookmarkData = try Data(contentsOf: bookmarkFile)

                NSLog("✅ DirectoryAccessManager.swift -> loadRootDirectoryBookmarkFromFile, 成功从 RootDirectoryBookmark.data 文件加载 PDF 根目录书签")

                return bookmarkData
            } else {
                NSLog("❌ DirectoryAccessManager.swift -> loadRootDirectoryBookmarkFromFile, RootDirectoryBookmark.data 根目录书签文件不存在")

                return nil
            }
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> loadRootDirectoryBookmarkFromFile, 从 RootDirectoryBookmark.data 文件加载 PDF 根目录书签失败: \(error.localizedDescription)")

            return nil
        }
    }

    private func loadOrgRoamDirectoryBookmarkFromFile() -> Data? {
        do {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let bookmarkFile = documentsDirectory.appendingPathComponent("OrgRoamDirectoryBookmark.data")

            if fileManager.fileExists(atPath: bookmarkFile.path) {
                let bookmarkData = try Data(contentsOf: bookmarkFile)

                NSLog("✅ DirectoryAccessManager.swift -> loadOrgRoamDirectoryBookmarkFromFile, 成功从 OrgRoamDirectoryBookmark.data 文件加载 org 根目录书签")

                return bookmarkData
            } else {
                NSLog("❌ DirectoryAccessManager.swift -> loadOrgRoamDirectoryBookmarkFromFile, OrgRoamDirectoryBookmark.data 根目录书签文件不存在")

                return nil
            }
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> loadOrgRoamDirectoryBookmarkFromFile, 从 OrgRoamDirectoryBookmark.data 文件加载根 org 目录书签失败: \(error.localizedDescription)")

            return nil
        }
    }

    // 保存 PDF 书签到数据库
    private func savePDFBookmarksToDatabase(_ bookmarks: [String: Data]) -> Bool {
        // 确保数据库已初始化
        guard let rootURL = rootDirectoryURL else {
            NSLog("❌ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, PDF 根目录 URL 未设置")

            return false
        }

        let dataBasePath = rootURL.appendingPathComponent("pdf-annotations.db").path

        // 检查数据库是否存在
        guard FileManager.default.fileExists(atPath: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, pdf-annotations.db 数据库文件不存在: \(dataBasePath)")

            return false
        }

        guard let dbQueue = FMDatabaseQueue(path: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, 无法打开 pdf-annotations.db 数据库")

            return false
        }

        var success = true

        dbQueue.inDatabase { db in
            // 创建 pdf_file_bookmarks 书签表（如果不存在）
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS pdf_file_bookmarks (
                path TEXT PRIMARY KEY,
                bookmark_data BLOB NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """

            if !db.executeStatements(createTableSQL) {
                NSLog("❌ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, 创建 pdf_file_bookmarks 书签表失败")

                success = false
                return
            }

            // 开始事务
            db.beginTransaction()

            // 清空现有书签
            if !db.executeUpdate("DELETE FROM pdf_file_bookmarks", withArgumentsIn: []) {
                NSLog("❌ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, 清空 pdf_file_bookmarks 书签表失败")

                db.rollback()
                success = false
                return
            }

            // 插入新书签
            for (path, bookmarkData) in bookmarks {
                let insertSQL = "INSERT INTO pdf_file_bookmarks (path, bookmark_data) VALUES (?, ?)"
                if !db.executeUpdate(insertSQL, withArgumentsIn: [path, bookmarkData]) {
                    NSLog("❌ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, pdf_file_bookmarks 书签表插入书签失败: \(path)")

                    success = false
                    break
                }
            }

            // 提交或回滚事务
            if success {
                db.commit()

                NSLog("✅ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, 成功保存 \(bookmarks.count) 个书签到 pdf-annotations.db 数据库 pdf_file_bookmarks 书签表")
            } else {
                db.rollback()

                NSLog("❌ DirectoryAccessManager.swift -> savePDFBookmarksToDatabase, 保存书签到 pdf-annotations.db 数据库失败，已回滚")
            }
        }

        dbQueue.close()

        return success
    }

    // 保存 org 书签到数据库
    private func saveOrgBookmarksToDatabase(_ bookmarks: [String: Data]) -> Bool {
        // 确保数据库已初始化
        guard let rootURL = rootDirectoryURL else {
            NSLog("❌ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, PDF 根目录 URL 未设置")

            return false
        }

        let dataBasePath = rootURL.appendingPathComponent("pdf-annotations.db").path

        // 检查数据库是否存在
        guard FileManager.default.fileExists(atPath: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, pdf-annotations.db 数据库文件不存在: \(dataBasePath)")

            return false
        }

        guard let dbQueue = FMDatabaseQueue(path: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, 无法打开 pdf-annotations.db 数据库")

            return false
        }

        var success = true

        dbQueue.inDatabase { db in
            // 创建 org_file_bookmarks 书签表（如果不存在）
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS org_file_bookmarks (
                path TEXT PRIMARY KEY,
                bookmark_data BLOB NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """

            if !db.executeStatements(createTableSQL) {
                NSLog("❌ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, 创建 org_file_bookmarks 书签表失败")

                success = false
                return
            }

            // 开始事务
            db.beginTransaction()

            // 清空现有书签
            if !db.executeUpdate("DELETE FROM org_file_bookmarks", withArgumentsIn: []) {
                NSLog("❌ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, 清空 org_file_bookmarks 书签表失败")

                db.rollback()
                success = false
                return
            }

            // 插入新书签
            for (path, bookmarkData) in bookmarks {
                let insertSQL = "INSERT INTO org_file_bookmarks (path, bookmark_data) VALUES (?, ?)"
                if !db.executeUpdate(insertSQL, withArgumentsIn: [path, bookmarkData]) {
                    NSLog("❌ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, org_file_bookmarks 书签表插入书签失败: \(path)")

                    success = false
                    break
                }
            }

            // 提交或回滚事务
            if success {
                db.commit()

                NSLog("✅ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, 成功保存 \(bookmarks.count) 个书签到 pdf-annotations.db 数据库 org_file_bookmarks 书签表")
            } else {
                db.rollback()
                NSLog("❌ DirectoryAccessManager.swift -> saveOrgBookmarksToDatabase, 保存书签到 pdf-annotations.db 数据库失败，已回滚")
            }
        }

        dbQueue.close()

        return success
    }

    // 从数据库加载书签
    private func loadBookmarksFromDatabase() -> [String: Data]? {
        // 确保根目录URL已设置
        guard let rootURL = rootDirectoryURL else {
            NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, PDF 根目录 URL 未设置")

            return nil
        }

        let dataBasePath = rootURL.appendingPathComponent("pdf-annotations.db").path

        // 检查数据库是否存在
        guard FileManager.default.fileExists(atPath: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, pdf-annotations.db 数据库文件不存在: \(dataBasePath)")

            return nil
        }

        guard let dbQueue = FMDatabaseQueue(path: dataBasePath) else {
            NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 无法打开 pdf-annotations.db 数据库")

            return nil
        }

        var loadedBookmarks: [String: Data] = [:]
        var success = false
        var loadedPDFBookmarksCount = 0

        dbQueue.inDatabase { db in
            // 检查 pdf_file_bookmarks 书签表是否存在
            let pdfTableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='pdf_file_bookmarks'"
            if let result = db.executeQuery(pdfTableExistsQuery, withArgumentsIn: []) {
                let pdfTableExists = result.next()
                result.close()

                if pdfTableExists {
                    // 查询所有书签
                    let querySQL = "SELECT path, bookmark_data FROM pdf_file_bookmarks"
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
                        loadedPDFBookmarksCount = loadedBookmarks.count

                        NSLog("✅ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 成功从数据库加载 \(loadedBookmarks.count) 个 PDF 书签")
                    } else {
                        NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 查询 PDF 书签失败: \(db.lastErrorMessage())")
                    }
                } else {
                    NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, pdf_file_bookmarks 表不存在")
                }
            }
        }

        dbQueue.inDatabase { db in
            // 检查 org_file_bookmarks 书签表是否存在
            let orgTableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='org_file_bookmarks'"
            if let result = db.executeQuery(orgTableExistsQuery, withArgumentsIn: []) {
                let orgTableExists = result.next()
                result.close()

                if orgTableExists {
                    // 查询所有书签
                    let querySQL = "SELECT path, bookmark_data FROM org_file_bookmarks"
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

                        NSLog("✅ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 成功从数据库加载 \(loadedBookmarks.count - loadedPDFBookmarksCount) 个 org 书签")
                    } else {
                        NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, 查询 org 书签失败: \(db.lastErrorMessage())")
                    }
                } else {
                    NSLog("❌ DirectoryAccessManager.swift -> loadBookmarksFromDatabase, org_file_bookmarks 表不存在")
                }
            }
        }

        dbQueue.close()

        return success ? loadedBookmarks : nil
    }

    // 扫描目录并创建书签
    func scanDirectory(at url: URL, completion: @escaping () -> Void) {
        isScanningRootDirectory = true
        scanningRootDirectoryProgress = 0
        errorMessageForRootDirectory = nil

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
                            self.errorMessageForRootDirectory = "创建数据库失败，请重试"
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
                // 创建 PDF 根目录的书签
                let rootDirectoryBookmark = try url.bookmarkData(options: .minimalBookmark,
                                                                 includingResourceValuesForKeys: nil,
                                                                 relativeTo: nil)

                DispatchQueue.main.async {
                    self.rootDirectoryURL = url
                    self.pdfBookmarks[url.path] = rootDirectoryBookmark

                    // 同时保存到 UserDefaults 和文件系统
                    UserDefaults.standard.set(rootDirectoryBookmark, forKey: "RootDirectoryBookmark")
                    _ = self.saveRootDirectoryBookmarkToFile(rootDirectoryBookmark)

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
                                    self.pdfBookmarks[fileURL.path] = bookmark
                                }

                                // 更新进度
                                processedCount += 1
                                let progress = Double(processedCount) / Double(totalCount)

                                DispatchQueue.main.async {
                                    self.scanningRootDirectoryProgress = progress
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
                        for (path, bookmarkData) in self.pdfBookmarks {
                            serializableBookmarks[path] = bookmarkData
                        }

                        // 保存到 UserDefaults
                        UserDefaults.standard.set(serializableBookmarks, forKey: "PDFFileBookmarks")
                        // 保存到数据库（在数据库初始化后）
                        _ = self.savePDFBookmarksToDatabase(serializableBookmarks)
                        self.scanningRootDirectoryProgress = 1.0

                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 目录扫描完成，创建了 \(serializableBookmarks.count) 个书签")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessageForRootDirectory = "扫描目录失败: \(error.localizedDescription)"
                    self.isScanningRootDirectory = false

                    NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.scanDirectory, 扫描目录失败: \(error.localizedDescription)")
                }
            }

            // 停止访问资源
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                self.isScanningRootDirectory = false
                self.bookmarks = self.bookmarks
                    .merging(self.pdfBookmarks, uniquingKeysWith: { current, _ in current })
                    .merging(self.orgBookmarks, uniquingKeysWith: { current, _ in current })
                completion()
            }
        }
    }

    // 扫描目录并创建书签
    func scanOrgRoamDirectory(at url: URL, completion: @escaping () -> Void) {
        isScanningOrgRoamDirectory = true
        scanningOrgRoamDirectoryProgress = 0
        errorMessageForOrgRoamDirectory = nil

        // 保存当前目录路径到UserDefaults
        UserDefaults.standard.set(url.absoluteString, forKey: "LastSelectedOrgRoamDirectory")

        // 检查是否存在pdf-annotations.db文件
        let dataBasePath = url.appendingPathComponent("org-roam.db").path

        if FileManager.default.fileExists(atPath: dataBasePath) {
            NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanOrgRoamDirectory, 在目录中找到数据库文件: \(dataBasePath)")
        }

        // 获取永久访问权限
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()

        // 在后台线程执行扫描
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // 创建 Org 根目录的书签
                let rootBookmark = try url.bookmarkData(options: .minimalBookmark,
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil)

                DispatchQueue.main.async {
                    self.orgRoamDirectoryURL = url
                    self.orgBookmarks[url.path] = rootBookmark

                    // 同时保存到 UserDefaults 和文件系统
                    UserDefaults.standard.set(rootBookmark, forKey: "OrgRoamDirectoryBookmark")
                    _ = self.saveOrgRoamDirectoryBookmarkToFile(rootBookmark)

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanOrgRoamDirectory, 成功创建 Org 根目录书签: \(url.path)")
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

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanOrgRoamDirectory, 找到 \(totalCount) 个文件和目录")

                    for fileURL in allFiles {
                        autoreleasepool {
                            do {
                                // 为每个文件创建书签
                                let bookmark = try fileURL.bookmarkData(options: .minimalBookmark,
                                                                        includingResourceValuesForKeys: nil,
                                                                        relativeTo: nil)

                                DispatchQueue.main.async {
                                    self.orgBookmarks[fileURL.path] = bookmark
                                }

                                // 更新进度
                                processedCount += 1
                                let progress = Double(processedCount) / Double(totalCount)

                                DispatchQueue.main.async {
                                    self.scanningOrgRoamDirectoryProgress = progress
                                }
                            } catch {
                                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.scanOrgRoamDirectory, 无法为文件创建书签: \(fileURL.path), 错误: \(error.localizedDescription)")
                            }
                        }
                    }

                    // 保存所有书签到 UserDefaults 和数据库
                    DispatchQueue.main.async {
                        // 将书签字典转换为可序列化的格式
                        var serializableBookmarks: [String: Data] = [:]
                        for (path, bookmarkData) in self.orgBookmarks {
                            serializableBookmarks[path] = bookmarkData
                        }

                        // 保存到 UserDefaults
                        UserDefaults.standard.set(serializableBookmarks, forKey: "OrgFileBookmarks")
                        // 保存到数据库（在数据库初始化后）
                        _ = self.saveOrgBookmarksToDatabase(serializableBookmarks)
                        self.scanningOrgRoamDirectoryProgress = 1.0

                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.scanOrgRoamDirectory, 目录扫描完成，创建了 \(serializableBookmarks.count) 个书签")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessageForOrgRoamDirectory = "扫描目录失败: \(error.localizedDescription)"
                    self.isScanningOrgRoamDirectory = false

                    NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.scanOrgRoamDirectory, 扫描目录失败: \(error.localizedDescription)")
                }
            }

            // 停止访问资源
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                self.isScanningOrgRoamDirectory = false
                completion()
                self.bookmarks = self.bookmarks
                    .merging(self.pdfBookmarks, uniquingKeysWith: { current, _ in current })
                    .merging(self.orgBookmarks, uniquingKeysWith: { current, _ in current })
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
        // 尝试从文件加载 org 根目录书签
        if let orgRoamDirectoryBookmark = loadOrgRoamDirectoryBookmarkFromFile() {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: orgRoamDirectoryBookmark,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)

                if !isStale {
                    orgRoamDirectoryURL = url

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已从 OrgRoamDirectoryBookmark.data 文件恢复根目录书签")
                }
            } catch {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 无法从 OrgRoamDirectoryBookmark.data 文件恢复根目录书签: \(error.localizedDescription)")
            }
        }

        // 尝试从文件加载 PDF 根目录书签
        if let rootDirectoryBookmark = loadRootDirectoryBookmarkFromFile() {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: rootDirectoryBookmark,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)

                if !isStale {
                    rootDirectoryURL = url

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已从 RootDirectoryBookmark.data 文件恢复 PDF 根目录书签")

                    // 尝试从数据库加载所有书签，包括 PDF，org 文件
                    if let savedBookmarks = loadBookmarksFromDatabase() {
                        bookmarks = savedBookmarks

                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已从 pdf-annotations.db 数据库恢复 \(savedBookmarks.count) 个文件书签")

                        return
                    }
                }
            } catch {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 无法从 RootDirectoryBookmark.data 文件恢复 PDF 根目录书签: \(error.localizedDescription)")
            }
        }

        if let rootDirectoryBookmark = UserDefaults.standard.data(forKey: "RootDirectoryBookmark") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: rootDirectoryBookmark,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)

                if !isStale {
                    rootDirectoryURL = url

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已恢复 PDF 根目录书签")

                    // 恢复所有文件书签
                    if let savedBookmarks = UserDefaults.standard.dictionary(forKey: "PDFFileBookmarks") as? [String: Data] {
                        bookmarks = savedBookmarks

                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已恢复 \(savedBookmarks.count) 个 PDF 文件书签")
                    }
                } else {
                    NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, UserDefaults.standard.data 中 PDF 根目录书签已过期")
                }
            } catch {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 无法从 UserDefaults.standard.dictionary 恢复 PDF 根目录书签: \(error.localizedDescription)")
            }
        }

        if let orgRoamDirectoryBookmark = UserDefaults.standard.data(forKey: "OrgRoamDirectoryBookmark") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: orgRoamDirectoryBookmark,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)

                if !isStale {
                    orgRoamDirectoryURL = url

                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已恢复 org 根目录书签")

                    // 恢复所有文件书签
                    if let savedBookmarks = UserDefaults.standard.dictionary(forKey: "OrgFileBookmarks") as? [String: Data] {
                        bookmarks = bookmarks.merging(savedBookmarks) { $1 }

                        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 已恢复 \(savedBookmarks.count) 个 org 文件书签")
                    }
                } else {
                    NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, UserDefaults.standard.data 中 org 根目录书签已过期")
                }
            } catch {
                NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.restoreSavedBookmarks, 无法从 UserDefaults.standard.dictionary 恢复 org 根目录书签: \(error.localizedDescription)")
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
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.updateFilesTable, 无法打开数据库：\(dbPath)")

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

            // 遍历所有 PDF 文件并插入到files表
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(at: rootURL,
                                                    includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: [.skipsHiddenFiles],
                                                    errorHandler: nil)

            if let allURLs = enumerator?.allObjects as? [URL] {
                for fileURL in allURLs {
                    if fileURL.pathExtension.lowercased() == "pdf" || fileURL.pathExtension.lowercased() == "MP4" {
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

    // 递归搜索文件
    func findFileInDirectory(fileName: String, directory: URL) -> URL? {
        NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.findFileInDirectory, 开始在目录中搜索文件: \(fileName), 目录: \(directory.path)")

        let fileManager = FileManager.default

        do {
            // 获取目录中的所有内容
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

            // 首先在当前目录中查找
            for url in contents {
                if url.lastPathComponent == fileName {
                    NSLog("✅ DirectoryAccessManager.swift -> DirectoryAccessManager.findFileInDirectory, 找到文件: \(url.path)")

                    return url
                }
            }

            // 然后递归搜索子目录
            for url in contents {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    if let found = findFileInDirectory(fileName: fileName, directory: url) {
                        return found
                    }
                }
            }
        } catch {
            NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.findFileInDirectory, 搜索目录失败: \(error.localizedDescription)")
        }

        NSLog("❌ DirectoryAccessManager.swift -> DirectoryAccessManager.findFileInDirectory, 未找到文件: \(fileName)")

        return nil
    }
}
