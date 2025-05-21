import SwiftUI

struct AnnotationListView: View {
    @Environment(\.presentationMode) var presentationMode

    // 使用共享的 ViewModel 实例
    @ObservedObject private var annotationListViewModel = AnnotationListViewModel.shared

    @State private var currentEditMode: EditMode = .inactive
    @State private var selectedAnnotations = Set<String>()
    // 创建一个映射，用于存储格式化注释和原始注释ID之间的关系
    @State private var annotationIdMap: [String: String] = [:]
    // 添加搜索文本状态
    @State private var searchText = ""

    // 添加 directoryManager 属性
    private let directoryManager = DirectoryAccessManager.shared

    // 添加过滤后的注释列表计算属性
    private var filteredAnnotations: [String] {
        if searchText.isEmpty {
            return annotationListViewModel.annotations
        } else {
            return annotationListViewModel.annotations.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                SearchBar(text: $searchText, placeholder: "搜索注释")
                    .padding(.vertical, 8)

                if annotationListViewModel.isLoading {
                    ProgressView("加载注释中...")
                } else if annotationListViewModel.annotations.isEmpty {
                    Text("没有找到注释")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(selection: $selectedAnnotations) {
                        ForEach(filteredAnnotations, id: \.self) { annotation in
                            VStack(alignment: .leading) {
                                Text(extractedAnnotation(annotation))
                                    .font(.body)
                                    .lineLimit(2)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        extractAndHandleNOTERPAGE(from: annotation)
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            UIPasteboard.general.string = annotation
                                        }) {
                                            Text("拷贝")
                                            Image(systemName: "doc.on.doc")
                                        }

                                        Button(action: {
                                            // 获取注释ID并删除
                                            if let id = getAnnotationId(for: annotation) {
                                                annotationListViewModel.deleteAnnotation(withId: id)
                                            }
                                        }) {
                                            Text("删除")
                                            Image(systemName: "trash")
                                        }
                                    }
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: slideToDeleteAnnotation)
                    }.navigationBarTitle("保存的注释", displayMode: .inline)
                        .navigationBarItems(
                            leading: EditButton(),
                            trailing: Button("收起") {
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                        .environment(\.editMode, $currentEditMode)
                }

                // 自定义底部工具栏
                if currentEditMode.isEditing {
                    HStack(spacing: 20) {
                        Button(action: copySelectedAnnotations) {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 20))
                                Text("拷贝")
                                    .font(.caption)
                            }
                            .frame(minWidth: 80)
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        Spacer()

                        Button(action: deleteSelectedAnnotations) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                Text("删除")
                                    .font(.caption)
                            }
                            .frame(minWidth: 80)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
                }
            }
        }.onAppear {
            loadAnnotationsFromLastSelectedDirectory()
            // 构建注释ID映射
            updateAnnotationIdMap()
        }
        .onChange(of: annotationListViewModel.annotationData) { _ in
            // 当注释数据更新时，更新ID映射
            updateAnnotationIdMap()
        }
    }

    private func extractedAnnotation(_ text: String) -> String {
        // Split on ][ and take the part after the first occurrence
        let parts = text.components(separatedBy: "][")
        guard parts.count > 1 else { return text }

        // Remove the trailing ]] and any whitespace
        return parts[1]
            .replacingOccurrences(of: "]]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 更新注释ID映射
    private func updateAnnotationIdMap() {
        annotationIdMap.removeAll()

        for (index, annotation) in annotationListViewModel.annotationData.enumerated() {
            if index < annotationListViewModel.annotations.count {
                let formattedAnnotation = annotationListViewModel.annotations[index]
                annotationIdMap[formattedAnnotation] = annotation.id
            }
        }

        NSLog("✅ AnnotationListView.swift -> AnnotationListView.updateAnnotationIdMap, 已更新注释ID映射，共 \(annotationIdMap.count) 条")
    }

    // 获取注释的ID
    private func getAnnotationId(for annotation: String) -> String? {
        return annotationIdMap[annotation]
    }

    // 修改 slideToDeleteAnnotation 方法，使用 ID 删除
    private func slideToDeleteAnnotation(at offsets: IndexSet) {
        // 获取要删除的注释
        let annotationsToDelete = offsets.map { annotationListViewModel.annotations[$0] }

        // 获取注释ID
        let idsToDelete = annotationsToDelete.compactMap { getAnnotationId(for: $0) }

        if !idsToDelete.isEmpty {
            // 删除注释
            if annotationListViewModel.deleteAnnotations(withIds: idsToDelete) {
                // 显示删除成功提示
                showToast(message: "已删除 \(idsToDelete.count) 条注释")
            } else {
                // 显示删除失败提示
                showToast(message: "删除失败，请重试")
            }
        }
    }

    // 删除选中的注释
    private func deleteSelectedAnnotations() {
        // 获取选中注释的ID
        let selectedIds = selectedAnnotations.compactMap { getAnnotationId(for: $0) }

        if !selectedIds.isEmpty {
            // 删除选中的注释
            if annotationListViewModel.deleteAnnotations(withIds: selectedIds) {
                // 清除选择
                selectedAnnotations.removeAll()

                // 显示删除成功提示
                showToast(message: "已删除 \(selectedIds.count) 条注释")
            } else {
                // 显示删除失败提示
                showToast(message: "删除失败，请重试")
            }
        }
    }

    // 显示提示信息
    private func showToast(message: String) {
        let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
        if let keyWindow = keyWindow {
            let toastLabel = UILabel()
            toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            toastLabel.textColor = UIColor.white
            toastLabel.textAlignment = .center
            toastLabel.font = UIFont.systemFont(ofSize: 14)
            toastLabel.text = message
            toastLabel.alpha = 1.0
            toastLabel.layer.cornerRadius = 10
            toastLabel.clipsToBounds = true

            keyWindow.addSubview(toastLabel)
            toastLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toastLabel.centerXAnchor.constraint(equalTo: keyWindow.centerXAnchor),
                toastLabel.bottomAnchor.constraint(equalTo: keyWindow.safeAreaLayoutGuide.bottomAnchor, constant: -100),
                toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
                toastLabel.heightAnchor.constraint(equalToConstant: 40),
            ])

            // 2秒后淡出
            UIView.animate(withDuration: 0.5, delay: 2.0, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }, completion: { _ in
                toastLabel.removeFromSuperview()
            })
        }
    }

    private func extractAndHandleNOTERPAGE(from annotation: String) {
        // Extract the NOTERPAGE portion from the annotation string
        let components = annotation.components(separatedBy: ")][")
        guard components.count > 1 else { return }

        let noterpagePart = components[0]
            .replacingOccurrences(of: "[[NOTERPAGE:", with: "NOTERPAGE:")

        // Close the annotation list and pass the NOTERPAGE link
        presentationMode.wrappedValue.dismiss()

        processAnnotationLink(noterpagePart)
    }

    private func copySelectedAnnotations() {
        let selectedTexts = annotationListViewModel.annotations.filter { selectedAnnotations.contains($0) }

        if !selectedTexts.isEmpty {
            // 在主线程上执行剪贴板操作
            DispatchQueue.main.async {
                UIPasteboard.general.string = selectedTexts.joined(separator: "\n\n")

                // 使用 UIImpactFeedbackGenerator 替代 UINotificationFeedbackGenerator
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare() // 提前准备生成器
                generator.impactOccurred() // 触发反馈

                // 显示一个临时提示，提供视觉反馈
                showToast(message: "已拷贝 \(selectedTexts.count) 条注释")
            }
        }

        NSLog("✅ AnnotationListView.swift -> AnnotationListView.copySelectedAnnotations, selectedTexts: \(selectedTexts)")
    }

    private func processAnnotationLink(_ link: String) {
        guard let result = PathConverter.parseNoterPageLink(link) else {
            NSLog("❌ AnnotationListView.swift -> AnnotationListView.processAnnotationLink, 无效的 Metanote 链接")

            return
        }

        let rawPdfPath = result.pdfPath
        let convertedPdfPath = PathConverter.convertNoterPagePath(rawPdfPath, rootDirectoryURL: nil)
        let pdfURL = URL(fileURLWithPath: convertedPdfPath)
        let currentPage = result.page ?? 0
        let xRatio = result.x ?? 0.0
        let yRatio = result.y ?? 0.0

        NSLog("✅ ContentView.swift -> ContentView.processAnnotationLink, 转换路径: \(convertedPdfPath), 页码: \(currentPage), yRatio: \(yRatio), xRatio: \(xRatio)")
        NSLog("✅ ContentView.swift -> ContentView.processAnnotationLink, 文件路径: \(String(describing: pdfURL)), 页码: \(currentPage), yRatio: \(yRatio), xRatio: \(xRatio)")

        NotificationCenter.default.post(
            name: NSNotification.Name("OpenPDFNotification"),
            object: nil,
            userInfo: [
                "pdfPath": rawPdfPath,
                "page": currentPage,
                "xRatio": xRatio,
                "yRatio": yRatio,
            ]
        )
    }

    // 检查上次选择的目录并加载数据库
    private func loadAnnotationsFromLastSelectedDirectory() {
        if let savedDatabasePath = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
           let url = URL(string: savedDatabasePath)
        {
            let dataBasePath = url.appendingPathComponent("pdf-annotations.db").path

            // 打开数据库
            guard DatabaseManager.shared.openDatabase(with: directoryManager, at: dataBasePath) else {
                NSLog("❌ AnnotationListView.swift -> AnnotationListView.loadAnnotationsFromLastSelectedDirectory, 无法打开数据库: \(dataBasePath)")

                return
            }

            // 发送通知加载数据库
            NotificationCenter.default.post(
                name: NSNotification.Name("LoadAnnotationsDatabase"),
                object: nil,
                userInfo: ["dataBasePath": dataBasePath]
            )

            NSLog("✅ SceneDelegate.swift -> AnnotationListView.loadAnnotationsFromLastSelectedDirectory, 在上次选择的目录中找到数据库文件: \(dataBasePath)")
        }
    }
}

// 添加 SearchBar 组件
struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func searchBar(_: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)

        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.spellCheckingType = .no
        searchBar.returnKeyType = .done
        searchBar.enablesReturnKeyAutomatically = false
        searchBar.backgroundImage = UIImage()

        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context _: Context) {
        uiView.text = text
    }
}
