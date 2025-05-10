import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NSLog("应用程序已启动 - didFinishLaunchingWithOptions")
        return true
    }

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        NSLog("配置新场景 - configurationForConnecting")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // 场景被丢弃时的清理工作
    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        NSLog("场景被丢弃 - didDiscardSceneSessions")
    }

    // 处理自定义URL方案
    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return true
    }
}
