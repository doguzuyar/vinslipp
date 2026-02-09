import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var pendingShortcut: String?
    private var mainTabBarController: MainTabBarController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            pendingShortcut = tabFromShortcut(shortcut)
        }

        // Defer wrapping so Capacitor has time to create the window
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let window = self.window,
                  let webVC = window.rootViewController as? WineCellarViewController else {
                print("⚠️ TabBar: window or WineCellarViewController not ready")
                return
            }
            print("✅ TabBar: wrapping webVC in MainTabBarController")
            // Detach webVC from the window first so it can be added as a child
            window.rootViewController = nil
            let tbc = MainTabBarController(webViewController: webVC)
            window.rootViewController = tbc
            self.mainTabBarController = tbc
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if let tab = pendingShortcut {
            pendingShortcut = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.navigateToTab(tab)
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    // MARK: - Quick Actions (3D Touch / Haptic Touch)

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let tab = tabFromShortcut(shortcutItem)
        navigateToTab(tab)
        completionHandler(true)
    }

    private func tabFromShortcut(_ item: UIApplicationShortcutItem) -> String {
        switch item.type {
        case "com.nybroans.vinslipp.release":
            return "release"
        case "com.nybroans.vinslipp.cellar":
            return "cellar"
        case "com.nybroans.vinslipp.history":
            return "history"
        case "com.nybroans.vinslipp.auction":
            return "auction"
        default:
            return "release"
        }
    }

    private func navigateToTab(_ tab: String) {
        // Update both the native tab selection and the web hash
        mainTabBarController?.selectTab(named: tab)
        mainTabBarController?.webVC.webView?.evaluateJavaScript("""
            window.location.hash='#\(tab)';
            window.dispatchEvent(new HashChangeEvent('hashchange'));
        """)
    }

}
