import os.log
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupLogging()

        // 初始化 DirectoryAccessManager
        DirectoryAccessManager.shared.restoreSavedBookmarks()

        NSLog("✅ AppDelegate.swift -> AppDelegate.application, 应用程序已启动 - didFinishLaunchingWithOptions")

        return true
    }

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        NSLog("✅ AppDelegate.swift -> AppDelegate.application, 配置新场景 - configurationForConnecting")

        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // 场景被丢弃时的清理工作
    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        NSLog("✅ AppDelegate.swift -> AppDelegate.application, 配置新场景 - configurationForConnecting")
    }

    // 处理自定义URL方案
    func application(_: UIApplication, open _: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return true
    }

    private func setupLogging() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFile = docsDir.appendingPathComponent("noterPDFReaderDebug.log")

        // 创建空日志文件
        try? "".write(to: logFile, atomically: true, encoding: .utf8)

        // 重定向标准错误输出
        freopen(logFile.path.cString(using: .ascii), "a+", stderr)
    }
}
