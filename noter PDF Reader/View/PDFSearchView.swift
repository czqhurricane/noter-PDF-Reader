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
    // 添加防抖定时器
    @State private var searchTimer: Timer?

    var onResultSelected: (String, Int, String) -> Void

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.gray)

                TextField("搜索 PDF 内容", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none) // 禁用自动首字母大写
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { _ in
                        // 取消之前的定时器
                        searchTimer?.invalidate()

                        // 创建新的防抖定时器
                        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                            performSearch()
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        searchTimer?.invalidate()
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
                            // 先调用回调函数
                            onResultSelected(result.filePath, result.pageNumber, result.context)
                        }) {
                            HStack {
                                Text("第\(result.pageNumber)页")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(width: 80, alignment: .leading)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.context)
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
            // Get path string instead of URL
            guard let lastPDFPath = UserDefaults.standard.string(forKey: "LastPDFSearchFile"),
                  let currentPDFPath = pdfDocument?.documentURL?.path
            else {
                performSearch()
                return
            }

            // Compare path strings
            if lastPDFPath != currentPDFPath {
                performSearch()
            } else {
                loadPersistedSearchResults()
            }
        }
        .onDisappear {
            // 视图消失时保存搜索结果和取消定时器
            saveSearchResults()
            searchTimer?.invalidate()
        }
        .navigationTitle("PDF 搜索")
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
        guard !searchText.isEmpty else {
            searchResults = []
            saveSearchResults() // 清空时也保存
            return
        }

        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async {
            var results: [PDFSearchResult] = []

            // 获取 Cache 目录
            guard let lastSelectedDirectoryString = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
                  let lastSelectedDirectoryURL = URL(string: lastSelectedDirectoryString),
                  let document = pdfDocument,
                  let documentURL = document.documentURL
            else {
                DispatchQueue.main.async {
                    self.isSearching = false
                }

                return
            }

            let cacheDirectory = lastSelectedDirectoryURL.appendingPathComponent("Cache")

            // 确保Cache目录存在
            do {
                if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
                    try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("❌ PDFSearchView.swift -> PDFSearchView.performSearch, 创建 Cache 目录失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isSearching = false
                }
                return
            }

            // 获取PDF文件名（不含扩展名）
            let pdfFileName = documentURL.deletingPathExtension().lastPathComponent
            let txtFileURL = cacheDirectory.appendingPathComponent("\(pdfFileName).txt")

            // 检查txt文件是否存在，不存在则创建
            if !FileManager.default.fileExists(atPath: txtFileURL.path) {
                // 创建txt文件
                createTxtFile(from: document, at: txtFileURL)
            }

            // 从txt文件中搜索
            do {
                let content = try String(contentsOf: txtFileURL, encoding: .utf8)
                let lines = content.components(separatedBy: "\n")

                for line in lines {
                    if line.lowercased().contains(searchText.lowercased()) {
                        // 解析页码和内容
                        if let colonIndex = line.firstIndex(of: ":") {
                            let pageString = String(line[..<colonIndex])
                            if let pageNumber = Int(pageString) {
                                if let filePath = getFilePathFromDatabase(fileName: pdfFileName) {
                                    let convertedPath = PathConverter.convertNoterPagePath(filePath, rootDirectoryURL: lastSelectedDirectoryURL)

                                    let result = PDFSearchResult(
                                        fileName: pdfFileName,
                                        filePath: convertedPath,
                                        pageNumber: pageNumber,
                                        context: line
                                    )
                                    results.append(result)
                                }
                            }
                        }
                    }
                }
            } catch {
                NSLog("❌ PDFSearchView.swift -> PDFSearchView.performSearch, 读取 txt 文件失败: \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
                self.saveSearchResults() // 搜索完成后保存结果
                UserDefaults.standard.set(documentURL.path, forKey: "LastPDFSearchFile")
            }
        }
    }

    // 创建 txt 文件，存储 PDF 内容
    private func createTxtFile(from document: PDFDocument, at fileURL: URL) {
        var content = ""

        // 遍历所有页面
        for i in 0 ..< document.pageCount {
            if let page = document.page(at: i),
               let pageText = page.string
            {
                // 格式：页码:内容
                content += "\(i):\(pageText)\n"
            }
        }

        // 写入文件
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("❌ PDFSearchView.swift -> PDFSearchView.createTxtFile, 创建 txt 文件失败: \(error.localizedDescription)")
        }
    }

    // 保存搜索结果到UserDefaults
    private func saveSearchResults() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(searchResults.map { SerializablePDFSearchResult(from: $0) }) {
            UserDefaults.standard.set(encoded, forKey: "persistedPDFSearchResults")
        }
    }

    // 从UserDefaults加载搜索结果
    private func loadPersistedSearchResults() {
        guard let data = UserDefaults.standard.data(forKey: "persistedPDFSearchResults") else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([SerializablePDFSearchResult].self, from: data) {
            searchResults = decoded.map { $0.toPDFSearchResult() }
        }
    }

    private func getFilePathFromDatabase(fileName: String) -> String? {
        // 这里需要查询数据库获取文件路径
        // 由于DatabaseManager是单例，我们可以直接使用
        return DatabaseManager.shared.getFilePathByTitle(fileName)
    }
}

// 可序列化的PDFSearchResult结构
struct SerializablePDFSearchResult: Codable {
    let fileName: String
    let filePath: String
    let pageNumber: Int
    let context: String

    init(from result: PDFSearchResult) {
        fileName = result.fileName
        filePath = result.filePath
        pageNumber = result.pageNumber
        context = result.context
    }

    func toPDFSearchResult() -> PDFSearchResult {
        return PDFSearchResult(
            fileName: fileName,
            filePath: filePath,
            pageNumber: pageNumber,
            context: context
        )
    }
}
