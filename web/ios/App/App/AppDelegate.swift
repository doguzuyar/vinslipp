import UIKit
import Capacitor
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?
    var pendingShortcut: String?
    private var mainTabBarController: MainTabBarController?
    private var pendingNotificationTab: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Firebase setup
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("⚠️ Push: authorization error: \(error)")
            }
            print("✅ Push: authorization granted: \(granted)")
        }
        application.registerForRemoteNotifications()

        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            pendingShortcut = tabFromShortcut(shortcut)
        }

        // Handle cold-launch from notification
        if let notification = launchOptions?[.remoteNotification] as? [String: Any],
           let tab = notification["tab"] as? String {
            pendingNotificationTab = tab
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

    // MARK: - APNs Token Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ Push: failed to register: \(error)")
    }

    // MARK: - Firebase MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("✅ Push: FCM token: \(fcmToken ?? "nil")")
        restoreNotificationPreference()
    }

    private let allNotificationTopics = ["french-red", "french-white", "italy-red", "italy-white"]

    private func restoreNotificationPreference() {
        guard let topic = UserDefaults.standard.string(forKey: "notificationTopic"),
              allNotificationTopics.contains(topic) else { return }
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("⚠️ Push: restore subscribe error: \(error)")
            } else {
                print("✅ Push: restored subscription to '\(topic)'")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let tab = userInfo["tab"] as? String {
            navigateToTab(tab)
        }
        completionHandler()
    }

    // MARK: - App Lifecycle

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0

        if let tab = pendingShortcut {
            pendingShortcut = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.navigateToTab(tab)
            }
        }
        if let tab = pendingNotificationTab {
            pendingNotificationTab = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.navigateToTab(tab)
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
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
        case "com.nybroans.vinslipp.blog":
            return "blog"
        case "com.nybroans.vinslipp.auction":
            return "auction"
        case "com.nybroans.vinslipp.profile":
            return "profile"
        default:
            return "release"
        }
    }

    private func navigateToTab(_ tab: String) {
        mainTabBarController?.selectTab(named: tab)
        mainTabBarController?.webVC.webView?.evaluateJavaScript("""
            window.location.hash='#\(tab)';
            window.dispatchEvent(new HashChangeEvent('hashchange'));
        """)
    }

}
