import Combine
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate, ObservableObject {

    var window: UIWindow?
    @Published var selectedTab: Int = 0
    @Published var pendingShortcutTab: String?
    let notificationStore = NotificationStore()
    let favoritesStore = FavoritesStore()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        favoritesStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        notificationStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        application.registerForRemoteNotifications()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )

        return true
    }

    @objc private func appDidBecomeActive() {
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] notifications in
            guard let self, !notifications.isEmpty else { return }
            for notification in notifications {
                let content = notification.request.content
                guard !content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                Task { @MainActor in
                    self.notificationStore.addIfNew(title: content.title, body: content.body, date: notification.date)
                }
            }
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            Task { @MainActor in
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
        }
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

    static let sharedDefaults = UserDefaults(suiteName: FavoritesStore.appGroup) ?? .standard

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content

        guard !content.title.isEmpty else {
            completionHandler([])
            return
        }

        Task { @MainActor in
            notificationStore.add(title: content.title, body: content.body)
        }
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        Task { @MainActor in
            notificationStore.add(title: content.title, body: content.body)
            if let tab = content.userInfo["tab"] as? String {
                self.selectedTab = self.tabIndex(from: tab)
            }
        }
        completionHandler()
    }

    // MARK: - Quick Actions

    private static let shortcutPrefix = "com.nybroans.vinslipp."
    private static let validTabs: Set<String> = ["release", "cellar", "blog", "auction", "profile"]

    func tabFromShortcut(_ item: UIApplicationShortcutItem) -> String {
        let name = item.type.replacingOccurrences(of: Self.shortcutPrefix, with: "")
        return Self.validTabs.contains(name) ? name : "release"
    }

    func tabIndex(from name: String) -> Int {
        switch name {
        case "release": return 0
        case "cellar": return 1
        case "auction": return 2
        case "blog": return 3
        case "profile": return 4
        default: return 0
        }
    }

}
