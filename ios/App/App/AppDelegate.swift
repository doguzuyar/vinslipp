import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate, ObservableObject {

    var window: UIWindow?
    @Published var selectedTab: Int = 0
    private var pendingShortcut: String?
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

        // Shortcut and notification handling moved to UIScene lifecycle for iOS 26+

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

    private func restoreNotificationPreference() {
        guard let topic = UserDefaults.standard.string(forKey: "notification_topic"),
              NotificationTopics.allValues.contains(topic) else { return }
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
            DispatchQueue.main.async {
                self.selectedTab = self.tabIndex(from: tab)
            }
        }
        completionHandler()
    }

    // MARK: - App Lifecycle

    func applicationDidBecomeActive(_ application: UIApplication) {
        let tab = pendingShortcut ?? pendingNotificationTab
        pendingShortcut = nil
        pendingNotificationTab = nil
        if let tab {
            DispatchQueue.main.async {
                self.selectedTab = self.tabIndex(from: tab)
            }
        }
    }

    // MARK: - Quick Actions (3D Touch / Haptic Touch)

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let tab = tabFromShortcut(shortcutItem)
        DispatchQueue.main.async {
            self.selectedTab = self.tabIndex(from: tab)
        }
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

    private func tabIndex(from name: String) -> Int {
        switch name {
        case "release": return 0
        case "cellar": return 1
        case "blog": return 2
        case "auction": return 3
        case "profile": return 4
        default: return 0
        }
    }

}
