import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    private let appGroup = "group.com.nybroans.vinslipp"

    private var pendingContentHandler: ((UNNotificationContent) -> Void)?
    private var pendingContent: UNMutableNotificationContent?
    private var shouldSuppress = false

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        pendingContentHandler = contentHandler
        pendingContent = bestAttemptContent

        let userInfo = request.content.userInfo
        let topic = readTopic()
        let favorites = readFavorites()

        guard topic == "favorites" else {
            contentHandler(bestAttemptContent)
            return
        }

        guard let prodIds = userInfo["productNumbers"] as? String, !prodIds.isEmpty else {
            contentHandler(bestAttemptContent)
            return
        }

        guard !favorites.isEmpty else {
            contentHandler(bestAttemptContent)
            return
        }

        let matchedIds = prodIds.split(separator: ",").filter { favorites.contains(String($0)) }

        if !matchedIds.isEmpty {
            let namesMap = readWineNames()
            let matchedNames = matchedIds.compactMap { namesMap[String($0)] }
            if !matchedNames.isEmpty {
                bestAttemptContent.title = "Today's releases"
                bestAttemptContent.body = matchedNames.joined(separator: "\n")
            }
            contentHandler(bestAttemptContent)
        } else {
            shouldSuppress = true
            bestAttemptContent.sound = nil
            bestAttemptContent.badge = 0
            bestAttemptContent.interruptionLevel = .passive
            contentHandler(bestAttemptContent)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [request.identifier])
        }
    }

    override func serviceExtensionTimeWillExpire() {
        guard let handler = pendingContentHandler, let content = pendingContent else { return }
        if shouldSuppress {
            content.sound = nil
            content.badge = 0
            content.interruptionLevel = .passive
        }
        handler(content)
    }

    private func readTopic() -> String {
        guard let url = containerURL?.appendingPathComponent("notification_topic.txt"),
              let topic = try? String(contentsOf: url, encoding: .utf8) else {
            return "none"
        }
        return topic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readWineNames() -> [String: String] {
        guard let url = containerURL?.appendingPathComponent("wine_names.json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func readFavorites() -> Set<String> {
        guard let url = containerURL?.appendingPathComponent("favorites.json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return decoded
    }
}
