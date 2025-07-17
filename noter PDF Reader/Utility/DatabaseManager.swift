import FMDB
import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()
    private var database: FMDatabase?
    private var dbQueue: FMDatabaseQueue?

    // 私有初始化方法，确保单例模式
    private init() {
        dbQueue = nil
    }

    // 初始化数据库表结构
    func initializeDatabase(at path: String) -> Bool {
        NSLog("✅ DatabaseManager.swift -> DatabaseManager.initializeDatabase, 开始初始化数据库: \(path)")

        guard let queue = FMDatabaseQueue(path: path) else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.initializeDatabase, 无法创建数据库队列: \(path)")

            return false
        }

        var success = true

        queue.inDatabase { db in
            // 创建 sync_times 表
            let createSyncTimesTable = """
            CREATE TABLE IF NOT EXISTS sync_times (
                file TEXT UNIQUE PRIMARY KEY,
                last_sync_time TEXT NOT NULL
            )
            """

            // 创建 files 表
            let createFilesTable = """
            CREATE TABLE IF NOT EXISTS files (
                file TEXT UNIQUE PRIMARY KEY,
                title TEXT NOT NULL
            )
            """

            // 创建 annotations 表
            let createAnnotationsTable = """
            CREATE TABLE IF NOT EXISTS annotations (
                id TEXT NOT NULL PRIMARY KEY,
                file TEXT NOT NULL,
                page INTEGER NOT NULL,
                edges TEXT NOT NULL,
                type TEXT NOT NULL,
                color TEXT NOT NULL,
                contents TEXT,
                subject TEXT,
                created TEXT NOT NULL,
                modified TEXT NOT NULL,
                outlines TEXT,
                FOREIGN KEY (file) REFERENCES files (file) ON DELETE CASCADE
            )
            """

            // 创建索引
            let createIndex = """
            CREATE INDEX IF NOT EXISTS annotations_file_page ON annotations (file, page)
            """

            // 执行表创建语句
            if !db.executeStatements(createSyncTimesTable) {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.initializeDatabase, 创建 sync_times 表失败: \(db.lastErrorMessage())")
                success = false
                return
            }

            if !db.executeStatements(createFilesTable) {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.initializeDatabase, 创建 files 表失败: \(db.lastErrorMessage())")
                success = false
                return
            }

            if !db.executeStatements(createAnnotationsTable) {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.initializeDatabase, 创建 annotations 表失败: \(db.lastErrorMessage())")
                success = false
                return
            }

            if !db.executeStatements(createIndex) {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.initializeDatabase, 创建索引失败: \(db.lastErrorMessage())")
                success = false
                return
            }

            NSLog("✅ DatabaseManager.swift -> DatabaseManager.initializeDatabase, 数据库表结构创建成功")
        }

        queue.close()
        return success
    }

    // 在 DatabaseManager 中
    func openDatabase(with directoryManager: DirectoryAccessManager, at path: String) -> Bool {
        NSLog("✅ DatabaseManager.swift -> DatabaseManager.openDatabase, 尝试打开数据库: \(path)")

        // 关闭之前可能打开的数据库
        closeDatabase()

        // 首先检查是否有访问权限
        guard let accessibleURL = directoryManager.startAccessingFile(at: path) else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.openDatabase, 无法访问数据库文件: \(path)")

            return false
        }

        // 使用获取到访问权限的URL路径
        if let newQueue = FMDatabaseQueue(path: accessibleURL.path) {
            dbQueue = newQueue

            NSLog("✅ DatabaseManager.swift -> DatabaseManager.openDatabase, 成功打开数据库: \(path)")

            return true
        } else {
            directoryManager.stopAccessingFile(at: accessibleURL)

            NSLog("❌ DatabaseManager.swift -> DatabaseManager.openDatabase, 无法打开数据库: \(path)")

            return false
        }
    }

    // 关闭数据库
    func closeDatabase() {
        dbQueue?.close()

        NSLog("✅ DatabaseManager.swift -> DatabaseManager.closeDatabase, 数据库已关闭")
    }

    // 查询注释
    func queryAnnotations() -> [AnnotationData] {
        var annotations: [AnnotationData] = []

        guard let queue = dbQueue else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.queryAnnotations, 数据库队列未初始化")

            return annotations
        }

        // 添加事务处理
        queue.inTransaction { db, rollback in
            do {
                // 检查表是否存在
                let tableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='annotations'"
                let tableResult = try db.executeQuery(tableExistsQuery, values: nil)

                guard tableResult.next() else {
                    NSLog("❌ DatabaseManager.swift -> DatabaseManager.queryAnnotations, annotations表不存在")

                    tableResult.close()
                    return
                }
                tableResult.close()

                // 查询注释数据
                let queryString = """
                SELECT id, file, page, edges, type, color, contents, subject, created, modified, outlines
                FROM annotations
                ORDER BY created DESC
                """

                let results = try db.executeQuery(queryString, values: nil)

                while results.next() {
                    let id = results.string(forColumn: "id") ?? ""
                    let file = results.string(forColumn: "file") ?? ""
                    let page = Int(results.int(forColumn: "page"))
                    let edges = results.string(forColumn: "edges") ?? ""
                    let type = results.string(forColumn: "type") ?? ""
                    let color = results.string(forColumn: "color") ?? ""
                    let contents = results.string(forColumn: "contents") ?? ""
                    let subject = results.string(forColumn: "subject") ?? ""
                    let created = results.string(forColumn: "created") ?? ""
                    let modified = results.string(forColumn: "modified") ?? ""
                    let outlines = results.string(forColumn: "outlines") ?? ""

                    let annotation = AnnotationData(
                        id: id,
                        file: file,
                        page: page,
                        edges: edges,
                        type: type,
                        color: color,
                        contents: contents,
                        subject: subject,
                        created: created,
                        modified: modified,
                        outlines: outlines
                    )

                    annotations.append(annotation)
                }

                results.close()

                NSLog("✅ DatabaseManager.swift -> DatabaseManager.queryAnnotations, 成功查询到 \(annotations.count) 条注释")
            } catch {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.queryAnnotations, 查询失败: \(error.localizedDescription)")
                rollback.pointee = true
            }
        }

        return annotations
    }

    // 格式化注释为NOTERPAGE格式
    func formatAnnotationForNoterPage(_ annotation: AnnotationData) -> String {
        // 从edges中提取坐标
        let edgesComponents = annotation.edges
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            .components(separatedBy: " ")

        // 确保有足够的组件
        guard edgesComponents.count >= 2 else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.formatAnnotationForNoterPage, 无效的edges格式: \(annotation.edges)")

            return ""
        }

        let xRatio = Double(edgesComponents[0]) ?? 0.0
        let yRatio = Double(edgesComponents[1]) ?? 0.0

        // 从文件路径中提取文件名
        let fileName = URL(fileURLWithPath: annotation.file).lastPathComponent.replacingOccurrences(of: "\"", with: "")
        let file = annotation.file.replacingOccurrences(of: "\"", with: "")
        let contents = annotation.contents.replacingOccurrences(of: "\"", with: "")
        let outlines = annotation.outlines.replacingOccurrences(of: "\"", with: "")
        let formattedAnnotation: String

        // 构建NOTERPAGE格式
        if outlines.isEmpty {
            formattedAnnotation = "[[NOTERPAGE:\(file)#(\(annotation.page) \(yRatio) . \(xRatio))][\(contents) < \(fileName)]]"
        } else {
            formattedAnnotation = "[[NOTERPAGE:\(file)#(\(annotation.page) \(yRatio) . \(xRatio))][\(contents) < \(outlines) < \(fileName)]]"
        }

        return formattedAnnotation
    }

    // 添加新的注释
    func addAnnotation(_ annotation: AnnotationData) -> Bool {
        guard let queue = dbQueue else {
            NSLog("✅ DatabaseManager.swift -> DatabaseManager.addAnnotation, 数据库队列未初始化 ")

            return false
        }

        var success = false

        // 处理字符串参数
        let safeId = annotation.id.hasPrefix("\"") ? annotation.id : "\"\(annotation.id)\""
        let safeFile = annotation.file.hasPrefix("\"") ? annotation.file : "\"\(annotation.file)\""
        let safeType = annotation.type
        let safeColor = annotation.color
        let safeContents = annotation.contents.hasPrefix("\"") ? annotation.contents : "\"\(annotation.contents.replacingOccurrences(of: "\"", with: "\\\""))\""
        let safeSubject = annotation.subject
        let safeCreated = annotation.created
        let safeModified = annotation.modified
        let safeOutlines = annotation.outlines.hasPrefix("\"") ? annotation.outlines : "\"\(annotation.outlines.replacingOccurrences(of: "\"", with: "\\\""))\""

        queue.inDatabase { db in
            let insertSQL = """
            INSERT INTO annotations (id, file, page, edges, type, color, contents, subject, created, modified, outlines)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            success = db.executeUpdate(
                insertSQL,
                withArgumentsIn: [
                    safeId,
                    safeFile,
                    annotation.page,
                    annotation.edges,
                    safeType,
                    safeColor,
                    safeContents,
                    safeSubject,
                    safeCreated,
                    safeModified,
                    safeOutlines,
                ]
            )

            if success {
                NSLog("✅ DatabaseManager.swift -> DatabaseManager.addAnnotation, 成功添加注释")
            } else {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.addAnnotation, 添加注释失败: \(db.lastErrorMessage())")
            }
        }

        return success
    }

    // 更新注释
    func updateAnnotation(_ annotation: AnnotationData) -> Bool {
        guard let queue = dbQueue else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.updateAnnotation, 数据库队列未初始化")

            return false
        }

        var success = false

        queue.inDatabase { db in
            let updateSQL = """
            UPDATE annotations
            SET file = ?, page = ?, edges = ?, type = ?, color = ?, contents = ?, subject = ?, modified = ?, outlines = ?
            WHERE id = ?
            """

            success = db.executeUpdate(
                updateSQL,
                withArgumentsIn: [
                    annotation.file,
                    annotation.page,
                    annotation.edges,
                    annotation.type,
                    annotation.color,
                    annotation.contents,
                    annotation.subject,
                    annotation.modified,
                    annotation.outlines,
                    annotation.id,
                ]
            )

            if success {
                NSLog("✅ DatabaseManager.swift -> DatabaseManager.updateAnnotation, 成功更新注释")
            } else {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.updateAnnotation, 更新注释失败: \(db.lastErrorMessage())")
            }
        }

        return success
    }

    // 删除注释
    func deleteAnnotation(id: String) -> Bool {
        guard let queue = dbQueue else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.deleteAnnotation, 数据库队列未初始化")

            return false
        }

        var success = false

        queue.inDatabase { db in
            let deleteSQL = "DELETE FROM annotations WHERE id = ?"

            success = db.executeUpdate(deleteSQL, withArgumentsIn: [id])

            if success {
                NSLog("✅ DatabaseManager.swift -> DatabaseManager.deleteAnnotation, 成功删除注释 ID：\(id)")
            } else {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.deleteAnnotation, 删除注释失败 ID：\(id)，错误: \(db.lastErrorMessage())")
            }
        }

        return success
    }

    // 批量删除注释
    func deleteAnnotations(withIds ids: [String]) -> Bool {
        guard let queue = dbQueue else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.deleteAnnotations, 数据库队列未初始化")

            return false
        }

        var success = true

        queue.inDatabase { db in
            // 开始事务
            db.beginTransaction()

            for id in ids {
                let deleteSQL = "DELETE FROM annotations WHERE id = ?"
                let result = db.executeUpdate(deleteSQL, withArgumentsIn: [id])

                if !result {
                    success = false

                    NSLog("❌ DatabaseManager.swift -> DatabaseManager.deleteAnnotations, 删除注释失败 ID: \(id), 错误: \(db.lastErrorMessage())")
                    break
                }
            }

            // 根据操作结果提交或回滚事务
            if success {
                db.commit()

                NSLog("✅ DatabaseManager.swift -> DatabaseManager.deleteAnnotations, 成功删除 \(ids.count) 条注释")
            } else {
                db.rollback()

                NSLog("❌ DatabaseManager.swift -> DatabaseManager.deleteAnnotations, 批量删除注释失败，已回滚")
            }
        }

        return success
    }

    // 保存PDF最后访问页面
    func saveLastVisitedPage(pdfPath: String, page: Int) -> Bool {
        guard let queue = dbQueue else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.saveLastVisitedPage, 数据库队列未初始化")

            return false
        }

        var success = false

        queue.inDatabase { db in
            // 首先检查表是否存在，如果不存在则创建
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS pdf_last_visited (
                pdf_path TEXT PRIMARY KEY,
                last_page INTEGER NOT NULL,
                last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP
            )
            """

            if db.executeStatements(createTableSQL) {
                // 使用INSERT OR REPLACE来更新或插入记录
                let insertSQL = """
                INSERT OR REPLACE INTO pdf_last_visited (pdf_path, last_page, last_accessed)
                VALUES (?, ?, CURRENT_TIMESTAMP)
                """

                success = db.executeUpdate(insertSQL, withArgumentsIn: [pdfPath, page])

                if success {
                    NSLog("✅ DatabaseManager.swift -> DatabaseManager.saveLastVisitedPage, 成功保存 PDF 最后访问页面: \(pdfPath), 页码: \(page)")
                } else {
                    NSLog("❌ DatabaseManager.swift -> DatabaseManager.saveLastVisitedPage, 保存失败: \(db.lastErrorMessage())")
                }
            } else {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.saveLastVisitedPage, 创建表失败: \(db.lastErrorMessage())")
            }
        }

        return success
    }

    // 查询PDF最后访问页面
    func getLastVisitedPage(pdfPath: String) -> Int? {
        guard let queue = dbQueue else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.getLastVisitedPage, 数据库队列未初始化")

            return nil
        }

        var lastPage: Int?

        queue.inDatabase { db in
            // 首先检查表是否存在
            let tableExistsSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name='pdf_last_visited'"
            if let result = db.executeQuery(tableExistsSQL, withArgumentsIn: []) {
                let tableExists = result.next()
                result.close()

                if tableExists {
                    let querySQL = "SELECT last_page FROM pdf_last_visited WHERE pdf_path = ?"
                    if let queryResult = db.executeQuery(querySQL, withArgumentsIn: [pdfPath]) {
                        if queryResult.next() {
                            lastPage = Int(queryResult.int(forColumn: "last_page"))

                            NSLog("✅ DatabaseManager.swift -> DatabaseManager.getLastVisitedPage, 找到 PDF 最后访问页面: \(pdfPath), 页码: \(lastPage ?? 0)")
                        } else {
                            NSLog("✅ DatabaseManager.swift -> DatabaseManager.getLastVisitedPage, 未找到PDF访问记录: \(pdfPath)")
                        }
                        queryResult.close()
                    }
                } else {
                    NSLog("✅ DatabaseManager.swift -> DatabaseManager.getLastVisitedPage, pdf_last_visited表不存在")
                }
            }
        }

        return lastPage
    }

    // 根据 PDF 文件标题获取 PDF 文件路径
    func getFilePathByTitle(_ title: String) -> String? {
        var filePath: String?

        dbQueue?.inDatabase { db in
            let sql = "SELECT file FROM files WHERE title = ? LIMIT 1"
            if let resultSet = db.executeQuery(sql, withArgumentsIn: [title]) {
                if resultSet.next() {
                    filePath = resultSet.string(forColumn: "file")
                }
                resultSet.close()
            }
        }

        return filePath
    }

    // 根据ID查询org-roam.db中的文件路径
    func getFilePathByNodeId(_ nodeId: String, orgRoamDBPath: String) -> String? {
        NSLog("✅ DatabaseManager.swift -> DatabaseManager.getFilePathByNodeId, 尝试查询节点ID: \(nodeId)")

        // 关闭之前可能打开的数据库
        closeDatabase()

        // 打开org-roam.db数据库
        guard let queue = FMDatabaseQueue(path: orgRoamDBPath) else {
            NSLog("❌ DatabaseManager.swift -> DatabaseManager.getFilePathByNodeId, 无法打开数据库: \(orgRoamDBPath)")

            return nil
        }

        var filePath: String?

        queue.inDatabase { db in
            let sql = "SELECT file FROM nodes WHERE id = ? LIMIT 1"
            if let resultSet = db.executeQuery(sql, withArgumentsIn: [nodeId]) {
                if resultSet.next() {
                    filePath = resultSet.string(forColumn: "file")

                    NSLog("✅ DatabaseManager.swift -> DatabaseManager.getFilePathByNodeId, 找到文件路径: \(filePath ?? "nil")")
                } else {
                    NSLog("❌ DatabaseManager.swift -> DatabaseManager.getFilePathByNodeId, 未找到ID对应的文件: \(nodeId)")
                }
                resultSet.close()
            } else {
                NSLog("❌ DatabaseManager.swift -> DatabaseManager.getFilePathByNodeId, 查询失败: \(db.lastErrorMessage())")
            }
        }

        queue.close()
        return filePath
    }
}

// 添加 Equatable 协议
struct AnnotationData: Equatable {
    let id: String
    let file: String
    let page: Int
    let edges: String
    let type: String
    let color: String
    let contents: String
    let subject: String
    let created: String
    let modified: String
    let outlines: String

    // 实现 Equatable 协议的 == 方法
    static func == (lhs: AnnotationData, rhs: AnnotationData) -> Bool {
        return lhs.id == rhs.id &&
            lhs.file == rhs.file &&
            lhs.page == rhs.page &&
            lhs.edges == rhs.edges &&
            lhs.type == rhs.type &&
            lhs.color == rhs.color &&
            lhs.contents == rhs.contents &&
            lhs.subject == rhs.subject &&
            lhs.created == rhs.created &&
            lhs.modified == rhs.modified &&
            lhs.outlines == rhs.outlines
    }
}
