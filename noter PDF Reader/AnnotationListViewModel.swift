import SwiftUI
import FMDB

class AnnotationListViewModel: ObservableObject {
    @Published var annotations: [String] = []
    @Published var isLoading: Bool = false

    // 创建单例实例
    static let shared = AnnotationListViewModel()

    // 私有初始化方法，防止外部创建实例
    private init() {
        NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.init, 初始化 AnnotationListViewModel")
    }

    func loadAnnotationsFromDatabase(_ dataBasePath: String) {
        isLoading = true

        NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 开始加载数据库: \(dataBasePath)")

        // 在后台线程执行数据库操作
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 打开数据库
            guard DatabaseManager.shared.openDatabase(at: dataBasePath) else {
                DispatchQueue.main.async {
                    self?.isLoading = false

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
                self?.annotations = formattedAnnotations
                self?.isLoading = false

                NSLog("✅ AnnotationListViewModel.swift -> AnnotationListViewModel.loadAnnotationsFromDatabase, 已加载 \(formattedAnnotations.count) 条注释")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
