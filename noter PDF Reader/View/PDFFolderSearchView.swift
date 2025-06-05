import SwiftUI

struct PDFFolderSearchView: View {
    @Environment(\.presentationMode) private var presentationMode
    // 使用 AppStorage 持久化搜索文本
    @AppStorage("lastFolderSearchText") private var searchText: String = ""
    @State private var searchResults: [FolderSearchResult] = []
    @State private var isSearching: Bool = false
    // 添加防抖定时器
    @State private var searchTimer: Timer?

    var onResultSelected: (String, Int, String) -> Void // 添加 context 参数

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("搜索 PDF 文件夹内容", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
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
                            // 传递 context 参数
                            onResultSelected(result.filePath, result.pageNumber, result.context)
                        }) {
                            HStack {
                                Text(result.fileName)
                                    .font(.headline)
                                    .foregroundColor(.blue)

                                Spacer()

                                Text("第\(result.pageNumber)页")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Text(result.context)
                                .lineLimit(3)
                                .foregroundColor(.primary)
                                .font(.system(size: 14))
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
            // 视图出现时恢复搜索结果
            loadPersistedSearchResults()
        }
        .onDisappear {
            // 视图消失时保存搜索结果和取消定时器
            saveSearchResults()
            searchTimer?.invalidate()
        }
        .navigationTitle("PDF 文件夹搜索")
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
            var results: [FolderSearchResult] = []

            // 获取Cache目录
            guard let lastSelectedDirectoryString = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
                  let lastSelectedDirectoryURL = URL(string: lastSelectedDirectoryString)
            else {
                DispatchQueue.main.async {
                    self.isSearching = false
                }
                return
            }

            let cacheDirectory = lastSelectedDirectoryURL.appendingPathComponent("Cache")

            // 搜索所有txt文件
            do {
                let txtFiles = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

                for txtFile in txtFiles where txtFile.pathExtension == "txt" {
                    let content = try String(contentsOf: txtFile, encoding: .utf8)
                    let lines = content.components(separatedBy: "\n")

                    for line in lines {
                        if line.lowercased().contains(searchText.lowercased()) {
                            // 解析页码
                            if let colonIndex = line.firstIndex(of: ":") {
                                let pageString = String(line[..<colonIndex])
                                if let pageNumber = Int(pageString) {
                                    let fileName = txtFile.deletingPathExtension().lastPathComponent

                                    // 从数据库获取文件路径
                                    if let filePath = getFilePathFromDatabase(fileName: fileName) {
                                        let convertedPath = PathConverter.convertNoterPagePath(filePath, rootDirectoryURL: lastSelectedDirectoryURL)

                                        let result = FolderSearchResult(
                                            fileName: fileName,
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
                }
            } catch {
                NSLog("❌ PDFFolderSearchView.swift -> PDFFolderSearchView.performSearch, 搜索失败: \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
                self.saveSearchResults() // 搜索完成后保存结果
            }
        }
    }

    // 保存搜索结果到UserDefaults
    private func saveSearchResults() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(searchResults.map { SerializableFolderSearchResult(from: $0) }) {
            UserDefaults.standard.set(encoded, forKey: "persistedFolderSearchResults")
        }
    }

    // 从UserDefaults加载搜索结果
    private func loadPersistedSearchResults() {
        guard let data = UserDefaults.standard.data(forKey: "persistedFolderSearchResults") else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([SerializableFolderSearchResult].self, from: data) {
            searchResults = decoded.map { $0.toFolderSearchResult() }
        }
    }

    private func getFilePathFromDatabase(fileName: String) -> String? {
        // 这里需要查询数据库获取文件路径
        // 由于DatabaseManager是单例，我们可以直接使用
        return DatabaseManager.shared.getFilePathByTitle(fileName)
    }
}

// 可序列化的FolderSearchResult结构
struct SerializableFolderSearchResult: Codable {
    let fileName: String
    let filePath: String
    let pageNumber: Int
    let context: String

    init(from result: FolderSearchResult) {
        fileName = result.fileName
        filePath = result.filePath
        pageNumber = result.pageNumber
        context = result.context
    }

    func toFolderSearchResult() -> FolderSearchResult {
        return FolderSearchResult(
            fileName: fileName,
            filePath: filePath,
            pageNumber: pageNumber,
            context: context
        )
    }
}

struct FolderSearchResult: Identifiable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let pageNumber: Int
    let context: String
}
