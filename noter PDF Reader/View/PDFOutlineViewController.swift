import PDFKit
import UIKit

class PDFOutlineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIAdaptivePresentationControllerDelegate, UISearchBarDelegate {
    var pdfView: PDFView?
    private var outlineItems: [PDFOutline] = []
    private var filteredOutlineItems: [PDFOutline] = [] // 过滤后的目录项
    private let tableView = UITableView()
    private let searchBar = UISearchBar() // 添加搜索栏
    private var searchText: String = "" // 搜索文本

    // 用于持久化搜索状态的文档标识符
    private var documentIdentifier: String {
        guard let document = pdfView?.document else { return "" }
        return document.documentURL?.absoluteString ?? document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "目录"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissOutline)
        )

        // 设置搜索栏
        setupSearchBar()

        // 设置表格视图
        setupTableView()

        // 加载目录项
        loadOutlineItems()

        // 恢复上次的搜索状态
        restoreSearchState()

        // 设置presentation controller的代理为self
        presentationController?.delegate = self
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "搜索目录"
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OutlineCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func loadOutlineItems() {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              let outline = document.outlineRoot
        else {
            return
        }
        outlineItems = flattenOutline(outline)
        filterOutlineItems() // 应用过滤
    }

    private func flattenOutline(_ outline: PDFOutline) -> [PDFOutline] {
        var items: [PDFOutline] = []
        if outline.label != nil {
            items.append(outline)
        }
        for i in 0 ..< outline.numberOfChildren {
            if let child = outline.child(at: i) {
                items.append(contentsOf: flattenOutline(child))
            }
        }
        return items
    }

    // 过滤目录项
    private func filterOutlineItems() {
        if searchText.isEmpty {
            filteredOutlineItems = outlineItems
        } else {
            filteredOutlineItems = outlineItems.filter { outline in
                guard let label = outline.label else { return false }
                return label.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }

    // 保存搜索状态
    private func saveSearchState() {
        let key = "PDFOutlineSearch_\(documentIdentifier)"
        UserDefaults.standard.set(searchText, forKey: key)
    }

    // 恢复搜索状态
    private func restoreSearchState() {
        let key = "PDFOutlineSearch_\(documentIdentifier)"
        if let savedSearch = UserDefaults.standard.string(forKey: key) {
            searchText = savedSearch
            searchBar.text = savedSearch
            filterOutlineItems()
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return filteredOutlineItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OutlineCell", for: indexPath)
        let outline = filteredOutlineItems[indexPath.row]
        var indentLevel = 0
        var parent = outline.parent
        while parent != nil && parent?.label != nil {
            indentLevel += 1
            parent = parent?.parent
        }
        cell.textLabel?.text = outline.label
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.indentationLevel = indentLevel
        cell.indentationWidth = 20
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let outline = filteredOutlineItems[indexPath.row]

        if let pdfView = pdfView, let destination = outline.destination {
            pdfView.go(to: destination)
        }

        // 关闭目录视图
        dismiss(animated: true, completion: nil)

        // 发送通知，表示目录视图已关闭
        NotificationCenter.default.post(
          name: NSNotification.Name("UpdateShowOutlines"),
          object: nil,
          userInfo: ["showOutlines": false]
        )

        NSLog("✅ PDFOutlineViewController.swift -> PDFOutlineViewController.tableView, 发送通知 UpdateShowOutlines")
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        filterOutlineItems()
        saveSearchState() // 保存搜索状态
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // 隐藏键盘
    }

    @objc private func dismissOutline() {
        dismiss(animated: true, completion: nil)

        // 发送通知，表示目录视图已关闭
        NotificationCenter.default.post(
          name: NSNotification.Name("UpdateShowOutlines"),
          object: nil,
          userInfo: ["showOutlines": false]
        )

        NSLog("✅ PDFOutlineViewController.swift -> PDFOutlineViewController.dismissOutline, 发送通知 UpdateShowOutlines")
    }

    // 实现UIAdaptivePresentationControllerDelegate方法
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // 用户手动下拉关闭sheet时触发
        NSLog("✅ PDFOutlineViewController.swift -> presentationControllerDidDismiss, 用户手动下拉关闭了大纲视图")

        // 发送通知更新ShowOutlines状态
        NotificationCenter.default.post(
          name: Notification.Name("UpdateShowOutlines"),
          object: nil,
          userInfo: ["showOutlines": false]
        )
    }
}
