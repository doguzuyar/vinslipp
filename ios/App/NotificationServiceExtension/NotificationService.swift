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

        let topic = readTopic()

        // Not in favorites mode: show notification as-is
        guard topic == "favorites" else {
            contentHandler(bestAttemptContent)
            return
        }

        // In favorites mode: only show if there's a matching favorite
        let favorites = readFavorites()
        let userInfo = request.content.userInfo
        let prodIds = (userInfo["productNumbers"] as? String) ?? ""

        let matchedIds: [String]
        if !prodIds.isEmpty && !favorites.isEmpty {
            matchedIds = prodIds.split(separator: ",")
                .map { String($0) }
                .filter { favorites.contains($0) }
        } else {
            matchedIds = []
        }

        if !matchedIds.isEmpty {
            let namesMap = readWineNames()
            let matchedNames = matchedIds.compactMap { namesMap[$0] }
            if !matchedNames.isEmpty {
                bestAttemptContent.title = "Today's releases"
                bestAttemptContent.body = matchedNames.joined(separator: "\n")
            }
            contentHandler(bestAttemptContent)
        } else {
            suppress(bestAttemptContent, identifier: request.identifier, handler: contentHandler)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        guard let handler = pendingContentHandler, let content = pendingContent else { return }
        if shouldSuppress {
            content.title = ""
            content.body = ""
            content.sound = nil
            content.badge = 0
            content.interruptionLevel = .passive
        }
        handler(content)
    }

    private func suppress(
        _ content: UNMutableNotificationContent,
        identifier: String,
        handler: @escaping (UNNotificationContent) -> Void
    ) {
        shouldSuppress = true
        content.title = ""
        content.body = ""
        content.subtitle = ""
        content.sound = nil
        content.badge = 0
        content.interruptionLevel = .passive
        handler(content)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
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
