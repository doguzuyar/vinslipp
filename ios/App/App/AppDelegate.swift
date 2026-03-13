import UIKit
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
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

    // MARK: - Catch background notifications on app open

    @objc private func appDidBecomeActive() {
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] notifications in
            guard let self, !notifications.isEmpty else { return }
            for n in notifications {
                let content = n.request.content
                guard !content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                if self.isFavoritesMode, !self.notificationContainsFavorite(content.userInfo) {
                    continue
                }
                Task { @MainActor in
                    self.notificationStore.addIfNew(title: content.title, body: content.body, date: n.date)
                }
            }
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
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
        if topic == "favorites" {
            for t in NotificationTopics.categoryTopics {
                Messaging.messaging().subscribe(toTopic: t)
            }
        } else {
            Messaging.messaging().subscribe(toTopic: topic)
        }
    }

    static let sharedDefaults = UserDefaults(suiteName: FavoritesStore.appGroup) ?? .standard

    private var isFavoritesMode: Bool {
        Self.sharedDefaults.string(forKey: "notification_topic") == "favorites"
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content

        // Extension may have cleared title/body to suppress
        guard !content.title.isEmpty else {
            completionHandler([])
            return
        }

        if isFavoritesMode, !notificationContainsFavorite(content.userInfo) {
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

        if isFavoritesMode, !notificationContainsFavorite(content.userInfo) {
            completionHandler()
            return
        }
        Task { @MainActor in
            notificationStore.add(title: content.title, body: content.body)
        }
        if let tab = content.userInfo["tab"] as? String {
            DispatchQueue.main.async {
                self.selectedTab = self.tabIndex(from: tab)
            }
        }
        completionHandler()
    }

    private func notificationContainsFavorite(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let ids = userInfo["productNumbers"] as? String, !ids.isEmpty else { return false }
        let favorites = loadFavoritesFromDefaults()
        return ids.split(separator: ",").contains { favorites.contains(String($0)) }
    }

    private func loadFavoritesFromDefaults() -> Set<String> {
        guard let data = Self.sharedDefaults.data(forKey: FavoritesStore.storageKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
        return decoded
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
        case "blog": return 2
        case "auction": return 3
        case "profile": return 4
        default: return 0
        }
    }

}
