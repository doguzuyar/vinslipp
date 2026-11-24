import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate, ObservableObject {

    var window: UIWindow?
    @Published var selectedTab: Int = 0

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNs Token Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }

    // MARK: - Firebase MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        restoreNotificationPreference()
    }

    private func restoreNotificationPreference() {
        guard let topic = Self.sharedDefaults.string(forKey: "notification_topic"),
              NotificationTopics.allValues.contains(topic) else { return }
        Messaging.messaging().subscribe(toTopic: topic)
    }

    // The topic preference has always lived in the App Group suite; keep reading it there.
    static let appGroup = "group.com.nybroans.vinslipp"
    static let sharedDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard !notification.request.content.title.isEmpty else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        Task { @MainActor in
            if let tab = content.userInfo["tab"] as? String {
                self.selectedTab = self.tabIndex(from: tab)
            }
        }
        completionHandler()
    }

    func tabIndex(from name: String) -> Int {
        switch name {
        case "release": return 0
        case "cellar": return 1
        case "auction": return 2
        case "profile": return 3
        default: return 0
        }
    }

}
