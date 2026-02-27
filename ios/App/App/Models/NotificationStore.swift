import Foundation

struct StoredNotification: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let date: Date
    var isRead: Bool

    init(title: String, body: String, date: Date = .now) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.date = date
        self.isRead = false
    }
}

@MainActor
class NotificationStore: ObservableObject {
    @Published private(set) var notifications: [StoredNotification] = []

    private static let storageKey = "stored_notifications"
    private static let maxCount = 50

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    init() {
        load()
    }

    func add(title: String, body: String) {
        let notification = StoredNotification(title: title, body: body)
        notifications.insert(notification, at: 0)
        if notifications.count > Self.maxCount {
            notifications.removeLast(notifications.count - Self.maxCount)
        }
        save()
    }

    func markAsRead(_ id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
        save()
    }

    func markAllAsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        save()
    }

    func delete(_ id: UUID) {
        notifications.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notifications) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([StoredNotification].self, from: data) else { return }
        notifications = decoded
    }
}
