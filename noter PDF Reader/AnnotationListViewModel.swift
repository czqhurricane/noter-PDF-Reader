import FMDB
import SwiftUI

class AnnotationListViewModel: ObservableObject {
    @Published var annotations: [String] = []
    @Published var isLoading: Bool = false
    // 存储原始注释数据，包含ID信息
    @Published var annotationData: [AnnotationData] = []

    // 创建单例实例
    static let shared = AnnotationListViewModel()

    // 使用 DirectoryAccessManager 单例
    private let directoryManager = DirectoryAccessManager.shared

    // 私有初始化方法，防止外部创建实例
    private init() {
        NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.init, 初始化 AnnotationListViewModel")
    }

    func loadAnnotationsFromDatabase(_ dataBasePath: String) {
        isLoading = true

        NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 开始加载数据库: \(dataBasePath)")

        // 在后台线程执行数据库操作
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 确保 self 不为 nil
            guard let self = self else { return }

            // 打开数据库
            guard DatabaseManager.shared.openDatabase(with: self.directoryManager, at: dataBasePath) else {
                DispatchQueue.main.async {
                    self.isLoading = false

                    NSLog("❌ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 无法打开数据库: \(dataBasePath)")
                }

                return
            }

            // 查询注释
            let annotationData = DatabaseManager.shared.queryAnnotations()

            NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 查询到 \(annotationData.count) 条注释")

            // 格式化注释
            var formattedAnnotations: [String] = []

            for annotation in annotationData {
                let formatted = DatabaseManager.shared.formatAnnotationForNoterPage(annotation)
                if !formatted.isEmpty {
                    formattedAnnotations.append(formatted)
                }
            }

            // 关闭数据库
            DatabaseManager.shared.closeDatabase()

            // 在主线程更新UI
            DispatchQueue.main.async {
                self.annotationData = annotationData
                self.annotations = formattedAnnotations
                self.isLoading = false

                NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 已加载 \(formattedAnnotations.count) 条注释")
            }
        }
    }

    // 删除单个注释
    func deleteAnnotation(withId id: String) -> Bool {
        if let savedDatabasePath = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
           let url = URL(string: savedDatabasePath)
        {
            let dataBasePath = url.appendingPathComponent("pdf-annotations.db").path

            // 打开数据库
            guard DatabaseManager.shared.openDatabase(with: directoryManager, at: dataBasePath) else {
                NSLog("❌ AnnotationListViewModel.swift -> AnnotationListViewModel.deleteAnnotation, 无法打开数据库: \(dataBasePath)")

                return false
            }

            // 删除注释
            let success = DatabaseManager.shared.deleteAnnotation(id: id)

            // 如果删除成功，更新本地数据
            if success {
                // 从本地数据中移除已删除的注释
                annotationData.removeAll { $0.id == id }

                // 更新格式化后的注释列表
                updateFormattedAnnotations()
            }

            // 关闭数据库
            DatabaseManager.shared.closeDatabase()

            return success
        } else {
            NSLog("❌ AnnotationListViewModel.swift -> AnnotationListViewModel.deleteAnnotation, 当前数据库路径为空")

            return false
        }
    }

    // 批量删除注释
    func deleteAnnotations(withIds ids: [String]) -> Bool {
        if let savedDatabasePath = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
           let url = URL(string: savedDatabasePath)
        {
            let dataBasePath = url.appendingPathComponent("pdf-annotations.db").path

            // 打开数据库
            guard DatabaseManager.shared.openDatabase(with: directoryManager, at: dataBasePath) else {
                NSLog("❌ AnnotationListViewModel.swift -> AnnotationListViewModel.deleteAnnotation, 无法打开数据库: \(dataBasePath)")

                return false
            }

            // 删除注释
            let success = DatabaseManager.shared.deleteAnnotations(withIds: ids)

            // 如果删除成功，更新本地数据
            if success {
                // 从本地数据中移除已删除的注释
                annotationData.removeAll { annotation in ids.contains(annotation.id) }

                // 更新格式化后的注释列表
                updateFormattedAnnotations()
            }

            // 关闭数据库
            DatabaseManager.shared.closeDatabase()

            return success
        } else {
            NSLog("❌ AnnotationListViewModel.swift -> AnnotationListViewModel.deleteAnnotation, 当前数据库路径为空")

            return false
        }
    }

    // 更新格式化后的注释列表
    private func updateFormattedAnnotations() {
        annotations = annotationData.compactMap { DatabaseManager.shared.formatAnnotationForNoterPage($0) }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
