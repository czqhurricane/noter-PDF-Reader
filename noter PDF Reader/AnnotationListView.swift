import SwiftUI

struct AnnotationListView: View {
    // 使用共享的 ViewModel 实例
    @ObservedObject private var viewModel = AnnotationListViewModel.shared
    @State private var annotations: [String] = []
    @Environment(\.presentationMode) var presentationMode
    @State private var editMode = EditMode.inactive
    @State private var selectedAnnotations = Set<String>()

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("加载注释中...")
                } else if viewModel.annotations.isEmpty {
                    Text("没有找到注释")
                        .foregroundColor(.gray)
                        .padding()
                } else { List(selection: $selectedAnnotations) {
                    ForEach(viewModel.annotations, id: \.self) { annotation in
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
                                }
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete(perform: deleteAnnotations)
                }.navigationBarTitle("保存的注释", displayMode: .inline)
                    .navigationBarItems(
                        leading: EditButton(),
                        trailing: Button("收起") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                    .environment(\.editMode, $editMode)
                }

                // 自定义底部工具栏
                if editMode.isEditing {
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

    private func deleteAnnotations(at offsets: IndexSet) {
        annotations.remove(atOffsets: offsets)
        UserDefaults.standard.set(annotations, forKey: "SavedAnnotations")
    }

    private func deleteSelectedAnnotations() {
        annotations.removeAll { selectedAnnotations.contains($0) }
        UserDefaults.standard.set(annotations, forKey: "SavedAnnotations")
        selectedAnnotations.removeAll()
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
        let selectedTexts = viewModel.annotations.filter { selectedAnnotations.contains($0) }

        if !selectedTexts.isEmpty {
            // 在主线程上执行剪贴板操作
            DispatchQueue.main.async {
                UIPasteboard.general.string = selectedTexts.joined(separator: "\n\n")

                // 使用 UIImpactFeedbackGenerator 替代 UINotificationFeedbackGenerator
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare() // 提前准备生成器
                generator.impactOccurred() // 触发反馈

                // 备选方案：如果上面的方法不起作用，尝试这个
                // let selectionGenerator = UISelectionFeedbackGenerator()
                // selectionGenerator.prepare()
                // selectionGenerator.selectionChanged()

                // 显示一个临时提示，提供视觉反馈
                let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
                if let keyWindow = keyWindow {
                    let toastLabel = UILabel()
                    toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                    toastLabel.textColor = UIColor.white
                    toastLabel.textAlignment = .center
                    toastLabel.font = UIFont.systemFont(ofSize: 14)
                    toastLabel.text = "已拷贝 \(selectedTexts.count) 条注释"
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

            if FileManager.default.fileExists(atPath: dataBasePath) {
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
}
