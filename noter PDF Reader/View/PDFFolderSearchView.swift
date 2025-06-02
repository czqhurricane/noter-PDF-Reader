import SwiftUI
import PDFKit

struct PDFFolderSearchView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText: String = ""
    @State private var searchResults: [FolderSearchResult] = []
    @State private var isSearching: Bool = false

    var onResultSelected: (String, Int) -> Void // (filePath, pageNumber)

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("搜索PDF文件夹内容", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
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
                            onResultSelected(result.filePath, result.pageNumber)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
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
        .navigationTitle("PDF文件夹搜索")
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
            return
        }

        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async {
            var results: [FolderSearchResult] = []

            // 获取Cache目录
            guard let lastSelectedDirectoryString = UserDefaults.standard.string(forKey: "LastSelectedDirectory"),
                  let lastSelectedDirectoryURL = URL(string: lastSelectedDirectoryString) else {
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
                                        let result = FolderSearchResult(
                                            fileName: fileName,
                                            filePath: filePath,
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
            }
        }
    }

    private func getFilePathFromDatabase(fileName: String) -> String? {
        // 这里需要查询数据库获取文件路径
        // 由于DatabaseManager是单例，我们可以直接使用
        return DatabaseManager.shared.getFilePathByTitle(fileName)
    }
}

struct FolderSearchResult: Identifiable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let pageNumber: Int
    let context: String
}
