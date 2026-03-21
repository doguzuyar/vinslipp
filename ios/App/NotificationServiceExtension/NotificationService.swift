import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    private var pendingContentHandler: ((UNNotificationContent) -> Void)?
    private var pendingContent: UNMutableNotificationContent?

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
        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        guard let handler = pendingContentHandler, let content = pendingContent else { return }
        handler(content)
    }
}
