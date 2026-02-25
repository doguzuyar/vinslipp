import UIKit

class ShortcutSceneDelegate: UIResponder, UIWindowSceneDelegate {

    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            completionHandler(false)
            return
        }
        let tab = appDelegate.tabFromShortcut(shortcutItem)
        DispatchQueue.main.async {
            appDelegate.pendingShortcutTab = tab
        }
        completionHandler(true)
    }
}
