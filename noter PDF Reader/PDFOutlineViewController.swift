import PDFKit
import UIKit

class PDFOutlineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIAdaptivePresentationControllerDelegate {
    var pdfView: PDFView?
    private var outlineItems: [PDFOutline] = []
    private let tableView = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "目录"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissOutline)
        )

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OutlineCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        loadOutlineItems()

        // 设置presentation controller的代理为self
        presentationController?.delegate = self
    }

    private func loadOutlineItems() {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              let outline = document.outlineRoot
        else {
            return
        }
        outlineItems = flattenOutline(outline)
        tableView.reloadData()
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

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return outlineItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OutlineCell", for: indexPath)
        let outline = outlineItems[indexPath.row]
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
        let outline = outlineItems[indexPath.row]

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
