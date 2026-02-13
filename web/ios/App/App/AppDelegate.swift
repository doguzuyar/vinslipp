import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?
    var pendingShortcut: String?
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
            // TODO: Wire up tab navigation via SwiftUI environment
            print("📱 Notification tap: navigate to \(tab)")
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
            // TODO: Wire up tab navigation via SwiftUI environment
            print("📱 3D Touch shortcut: navigate to \(tab)")
        }
        if let tab = pendingNotificationTab {
            pendingNotificationTab = nil
            print("📱 Notification cold launch: navigate to \(tab)")
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    // MARK: - Quick Actions (3D Touch / Haptic Touch)

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let tab = tabFromShortcut(shortcutItem)
        // TODO: Wire up tab navigation via SwiftUI environment
        print("📱 3D Touch shortcut: navigate to \(tab)")
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

}
