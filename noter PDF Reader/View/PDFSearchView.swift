import PDFKit
import SwiftUI

struct PDFSearchView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var pdfDocument: PDFDocument?
    // 将状态变量改为 AppStorage 以保持状态
    @AppStorage("lastSearchText") private var searchText: String = ""
    // 使用 UserDefaults 来保存搜索结果
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
                    .autocapitalization(.none) // 禁用自动首字母大写
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

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(getContextString(from: result))
                                        .lineLimit(3)
                                        .foregroundColor(.primary)
                                        .font(.system(size: 14))
                                }
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
        .onAppear {
            // 视图出现时执行搜索，恢复之前的搜索结果
            if !searchText.isEmpty {
                performSearch()
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

                // 保存最后一次搜索时间
                UserDefaults.standard.set(Date(), forKey: "lastSearchTime")
            }
        }
    }
}

// 添加一个帮助方法来获取上下文
private func getContextString(from result: PDFSearchResult) -> String {
    // Since selection is not optional in PDFSearchResult, we don't need to check it
    guard let page = result.selection.pages.first,
          let text = result.selection.string else {
        return result.text
    }

    // 获取整页文本
    let pageText = page.string ?? ""

    // 找到搜索文本在页面中的位置
    guard let range = pageText.range(of: text) else {
        return result.text
    }

    // 计算上下文范围（前后50个字符）
    let contextStart = pageText.index(range.lowerBound, offsetBy: -50, limitedBy: pageText.startIndex) ?? pageText.startIndex
    let contextEnd = pageText.index(range.upperBound, offsetBy: 50, limitedBy: pageText.endIndex) ?? pageText.endIndex

    // 获取上下文文本
    let prefix = String(pageText[contextStart..<range.lowerBound])
    let match = String(pageText[range])
    let suffix = String(pageText[range.upperBound..<contextEnd])

    // 组合上下文，使用 ... 表示截断
    return "\(contextStart > pageText.startIndex ? "..." : "")\(prefix)\(match)\(suffix)\(contextEnd < pageText.endIndex ? "..." : "")"
}
