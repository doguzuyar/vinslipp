import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    private let appGroup = "group.com.nybroans.vinslipp"
    private let favoritesKey = "favorite_wines"
    private let topicKey = "notification_topic"

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let userInfo = request.content.userInfo
        let defaults = UserDefaults(suiteName: appGroup)

        let topic = defaults?.string(forKey: topicKey) ?? "none"
        guard topic == "favorites" else {
            contentHandler(request.content)
            return
        }

        guard let ids = userInfo["productNumbers"] as? String, !ids.isEmpty else {
            // No product numbers means we can't match favorites, suppress it
            contentHandler(UNNotificationContent())
            return
        }

        let favorites = loadFavorites(from: defaults)
        let hasMatch = ids.split(separator: ",").contains { favorites.contains(String($0)) }

        if hasMatch {
            contentHandler(request.content)
        } else {
            contentHandler(UNNotificationContent())
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Deliver whatever we have if we run out of time
    }

    private func loadFavorites(from defaults: UserDefaults?) -> Set<String> {
        guard let data = defaults?.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return decoded
    }
}
