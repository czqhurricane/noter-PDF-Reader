import PDFKit
import SwiftUI

struct PDFSearchView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var pdfDocument: PDFDocument?
    @State private var searchText: String = ""
    @State private var searchResults: [PDFSearchResult] = []
    @State private var isSearching: Bool = false

    var onResultSelected: (PDFSearchResult) -> Void

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("搜索 PDF 内容", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { _ in
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()

            if isSearching {
                ProgressView("搜索中...")
                    .padding()
            } else {
                List {
                    ForEach(searchResults) { result in
                        Button(action: {
                            onResultSelected(result)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text("第\(result.pageLabel)页")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(width: 80, alignment: .leading)

                                Text(result.text)
                                    .lineLimit(2)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(PlainListStyle())

                if searchResults.isEmpty && !searchText.isEmpty {
                    VStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .padding()

                        Text("未找到匹配结果")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("PDF搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func performSearch() {
        guard let document = pdfDocument, !searchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        // 在后台线程执行搜索，避免UI卡顿
        DispatchQueue.global(qos: .userInitiated).async {
            let searchResults = document.findString(searchText, withOptions: .caseInsensitive)

            // 回到主线程更新UI
            DispatchQueue.main.async {
                self.searchResults = searchResults.map { PDFSearchResult(selection: $0) }
                self.isSearching = false
            }
        }
    }
}
