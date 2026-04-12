import Combine
import FirebaseCore
import AppKit
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {

    @Published var selectedTab: Int = 0
    @Published var pendingShortcutTab: String?
    let notificationStore = NotificationStore()
    let favoritesStore = FavoritesStore()
    private var cancellables = Set<AnyCancellable>()
    private var hasBundleID: Bool { Bundle.main.bundleIdentifier != nil }

    override init() {
        super.init()
        favoritesStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        notificationStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let plistPath = Bundle.module.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: plistPath) {
            options.bundleID = "com.nybroans.vinslipp"
            FirebaseApp.configure(options: options)
        }

        // UNUserNotificationCenter requires a proper app bundle.
        // Skip when running as a bare SPM executable.
        guard hasBundleID else { return }
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard hasBundleID else { return }
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
        }
    }

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

    // MARK: - Tab Helpers

    static let sharedDefaults = UserDefaults(suiteName: FavoritesStore.appGroup) ?? .standard

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
