import SwiftUI

struct AnnotationListView: View {
    @State private var annotations: [String] = []
    @Environment(\.presentationMode) var presentationMode
    @State private var editMode = EditMode.inactive
    @State private var selectedAnnotations = Set<String>()

    var body: some View {
        NavigationView {
            List(selection: $selectedAnnotations) {
                ForEach(annotations, id: \.self) { annotation in
                    VStack(alignment: .leading) {
                        Text(extractedAnnotation(annotation))
                            .font(.body)
                            .lineLimit(2)
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
            .onAppear {
                loadAnnotations()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if editMode.isEditing {
                        HStack(spacing: 20) {
                            Button(action: copySelectedAnnotations) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("复制")
                                }
                            }
                            Spacer()
                            Button(action: deleteSelectedAnnotations) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("删除")
                                }
                            }
                        }.padding(.horizontal)
                    }
                }
            }
        }
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

    private func copySelectedAnnotations() {
        let selectedTexts = annotations.filter { selectedAnnotations.contains($0) }
        if !selectedTexts.isEmpty {
            UIPasteboard.general.string = selectedTexts.joined(separator: "\n\n")
        }
    }
}
