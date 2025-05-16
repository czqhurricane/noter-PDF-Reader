import SwiftUI

struct AnnotationListView: View {
    @State private var annotations: [String] = []
    @Environment(\.presentationMode) var presentationMode
    @State private var editMode = EditMode.inactive
    @State private var selectedAnnotations = Set<String>()

    var body: some View {
       // ... existing code ...
        NavigationView {
            VStack {
                List(selection: $selectedAnnotations) {
                ForEach(annotations, id: \.self) { annotation in
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
                                    Text("复制")
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                    }
                    .padding(.vertical, 8)
                }
                .onDelete(perform: deleteAnnotations)
            }
                .navigationBarTitle("保存的注释", displayMode: .inline)
                .navigationBarItems(
                    leading: EditButton(),
                    trailing: Button("收起") {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .environment(\.editMode, $editMode)

                // 自定义底部工具栏
                if editMode.isEditing {
                    HStack(spacing: 20) {
                        Button(action: copySelectedAnnotations) {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 20))
                                Text("复制")
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
            .onAppear {
                loadAnnotations()
            }
        }
// ... existing code ...
    }

    private func loadAnnotations() {
        annotations = UserDefaults.standard.stringArray(forKey: "SavedAnnotations") ?? []

        NSLog("✅ AnnotationListView.swift -> AnnotationListView.loadAnnotations, 从 UserDefaults 加载\(annotations.count)个注释")
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
        let selectedTexts = annotations.filter { selectedAnnotations.contains($0) }

        if !selectedTexts.isEmpty {
            DispatchQueue.main.async {
                UIPasteboard.general.string = selectedTexts.joined(separator: "\n\n")

                // 添加触觉反馈
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
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
}
