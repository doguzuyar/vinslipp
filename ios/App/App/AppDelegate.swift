import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate, ObservableObject {

    var window: UIWindow?
    @Published var selectedTab: Int = 0
    @Published var pendingShortcutTab: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        application.registerForRemoteNotifications()

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            pendingShortcutTab = tabFromShortcut(shortcut)
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = ShortcutSceneDelegate.self
        return config
    }

    // MARK: - APNs Token Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    // MARK: - Firebase MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        restoreNotificationPreference()
    }

    private func restoreNotificationPreference() {
        guard let topic = UserDefaults.standard.string(forKey: "notification_topic"),
              NotificationTopics.allValues.contains(topic) else { return }
        Messaging.messaging().subscribe(toTopic: topic)
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

    // MARK: - Quick Actions

    func tabFromShortcut(_ item: UIApplicationShortcutItem) -> String {
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

    func tabIndex(from name: String) -> Int {
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
