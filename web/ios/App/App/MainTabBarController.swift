import UIKit
import WebKit

class MainTabBarController: UITabBarController, UITabBarControllerDelegate, WKScriptMessageHandler {
    let webVC: WineCellarViewController
    private var isUnlocked = false

    private let allTabs: [(name: String, title: String, icon: String)] = [
        ("release",  "Release", "clock"),
        ("cellar",   "Cellar",  "cube.box"),
        ("history",  "History", "doc.on.clipboard"),
        ("auction",  "Auction", "dollarsign.circle"),
    ]

    init(webViewController: WineCellarViewController) {
        self.webVC = webViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        isUnlocked = UserDefaults.standard.bool(forKey: "unlocked")
        rebuildTabs()

        // Add the webview covering everything, just below the native tab bar.
        // Accessing webVC.view triggers its viewDidLoad which creates the WKWebView.
        addChild(webVC)
        view.insertSubview(webVC.view, belowSubview: tabBar)
        webVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            webVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        webVC.didMove(toParent: self)

        // Register JS → native message handlers
        let ucc = webVC.webView!.configuration.userContentController
        ucc.add(self, name: "tabSwitch")
        ucc.add(self, name: "unlockState")
    }

    // MARK: - Tab management

    private func visibleTabs() -> [(name: String, title: String, icon: String)] {
        return isUnlocked
            ? allTabs
            : allTabs.filter { $0.name == "release" || $0.name == "auction" }
    }

    private func rebuildTabs() {
        viewControllers = visibleTabs().map { tab in
            let vc = UIViewController()
            vc.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.icon),
                tag: 0
            )
            return vc
        }
    }

    /// Select the native tab matching a hash name (e.g. "release", "auction").
    func selectTab(named name: String) {
        if let index = visibleTabs().firstIndex(where: { $0.name == name }) {
            selectedIndex = index
        }
    }

    // MARK: - UITabBarControllerDelegate

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        guard let vcs = viewControllers,
              let index = vcs.firstIndex(of: viewController) else { return true }
        let tabs = visibleTabs()
        guard index < tabs.count else { return true }

        let tab = tabs[index].name
        webVC.webView?.evaluateJavaScript("""
            window.location.hash='#\(tab)';
            window.dispatchEvent(new HashChangeEvent('hashchange'));
        """)
        return true
    }

    // MARK: - WKScriptMessageHandler (messages from web)

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "tabSwitch":
            // Web switched tab (swipe, keyboard, etc.) → update native selection
            if let tab = message.body as? String {
                selectTab(named: tab)
            }

        case "unlockState":
            // Cellar/history tabs unlocked or locked
            if let body = message.body as? [String: Any],
               let unlocked = body["unlocked"] as? Bool {
                let wasUnlocked = isUnlocked
                isUnlocked = unlocked
                UserDefaults.standard.set(unlocked, forKey: "unlocked")
                if wasUnlocked != unlocked {
                    let current = visibleTabs().indices.contains(selectedIndex)
                        ? visibleTabs()[selectedIndex].name
                        : "release"
                    rebuildTabs()
                    selectTab(named: current)
                }
            }

        default:
            break
        }
    }

    deinit {
        webVC.webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: "tabSwitch")
        webVC.webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: "unlockState")
    }
}
