import FMDB
import SwiftUI

class AnnotationListViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    // 存储原始注释数据，包含ID信息
    @Published var annotationDatas: [AnnotationData] = []
    @Published var searchText: String = ""
    @Published var filteredFormattedAnnotations: [String] = []
    @Published var formattedAnnotations: [String] = []
    // 添加防抖动搜索
    private var searchWorkItem: DispatchWorkItem?

    // 使用 DirectoryAccessManager 单例
    private let directoryManager = DirectoryAccessManager.shared

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
            let annotations = DatabaseManager.shared.queryAnnotations()

            NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 查询到 \(self.annotationDatas.count) 条注释")

            // 关闭数据库
            DatabaseManager.shared.closeDatabase()

            // 在主线程更新UI
            DispatchQueue.main.async {
                self.annotationDatas = annotations
                self.updateSearchResults()
                self.isLoading = false

                NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 搜索到 \(self.filteredFormattedAnnotations.count) 条注释")
            }
        }
    }

    func updateSearchResults() {
        // 取消之前的搜索任务
        searchWorkItem?.cancel()

        // 创建新的搜索任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let formatted = self.formatAnnotations()
            let filtered = self.filterAnnotations(formatted: formatted)

            DispatchQueue.main.async {
                self.formattedAnnotations = formatted
                self.filteredFormattedAnnotations = filtered

                NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.updateSearchResults, 更新搜索结果")
            }
        }

        searchWorkItem = workItem

        // 延迟执行搜索，避免频繁搜索
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    // 修改：返回数值而非修改属性
    private func formatAnnotations() -> [String] {
        var results = [String]()

        for annotation in annotationDatas {
            let formatted = DatabaseManager.shared.formatAnnotationForNoterPage(annotation)
            if !formatted.isEmpty {
                results.append(formatted)
            }
        }

        return results
    }

    // 修改：返回数值而非修改属性
    private func filterAnnotations(formatted: [String]) -> [String] {
        if searchText.isEmpty {
            return formatted
        } else {
            return formatted.filter {
                $0.lowercased().contains(searchText.lowercased())
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
                annotationDatas.removeAll { $0.id == id }

                // 更新格式化后的注释列表
                updateSearchResults()
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
                annotationDatas.removeAll { annotation in ids.contains(annotation.id) }

                // 更新格式化后的注释列表
                updateSearchResults()
            }

            // 关闭数据库
            DatabaseManager.shared.closeDatabase()

            return success
        } else {
            NSLog("❌ AnnotationListViewModel.swift -> AnnotationListViewModel.deleteAnnotation, 当前数据库路径为空")

            return false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
