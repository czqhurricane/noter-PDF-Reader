//
//  ShareViewController.swift
//  noter PDF Reader Share
//
//  Created by c on 2025/7/18.
//

import MobileCoreServices
import Social
import UIKit

class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.

        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        // 获取分享的文本内容
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = item.attachments
        {
            for itemProvider in attachments {
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    itemProvider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { text, _ in
                        if let sharedText = text as? String {
                            // 对文本进行URL编码
                            if let encodedText = sharedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                                // NSLog("✅ ShareViewController.swift -> ShareViewController.sendTapped, \(encodedText)")

                                if let url = URL(string: encodedText) {
                                    // 打开主应用
                                    self.openURL(url)
                                }
                            }
                        }

                        // 完成分享操作
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                    return
                }
            }
        }
        // 如果没有文本内容，直接完成
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 设置标题和提示文本
        title = "分享到 noter PDF Reader"
        placeholder = "添加注释（可选）"

        // 设置导航栏按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
    }

    @objc func cancelTapped() {
        // 取消分享操作
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    func openURL(_ url: URL) {
        // 使用 UIApplication.shared.open 打开URL
        let selector = sel_registerName("openURL:")

        // 使用这种方式在扩展中打开主应用
        var responder: UIResponder? = self
        while responder != nil {
            if responder?.responds(to: selector) ?? false {
                // 直接传递 URL 对象
                responder?.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
    }
}
