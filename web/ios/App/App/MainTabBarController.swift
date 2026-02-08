import UIKit
import WebKit

/// A view that passes all touches through to views behind it.
private class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

class MainTabBarController: UITabBarController, UITabBarControllerDelegate, NativeTabDelegate {
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
        webVC.tabDelegate = self

        tabBar.isTranslucent = true
        tabBar.tintColor = UIColor(red: 28/255, green: 25/255, blue: 23/255, alpha: 1)
        tabBar.unselectedItemTintColor = UIColor(red: 120/255, green: 113/255, blue: 108/255, alpha: 1)

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(red: 250/255, green: 250/255, blue: 249/255, alpha: 0.72)
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }

        isUnlocked = UserDefaults.standard.bool(forKey: "unlocked")
        rebuildTabs()

        // Web view fills the entire area, content scrolls behind the translucent tab bar
        addChild(webVC)
        view.insertSubview(webVC.view, at: 0)
        webVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            webVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        webVC.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.backgroundColor = .clear
        view.bringSubviewToFront(tabBar)
        for subview in view.subviews where subview !== webVC.view {
            // Skip any view that contains the tab bar (the tab bar or its wrapper)
            if tabBar.isDescendant(of: subview) { continue }
            subview.backgroundColor = .clear
            subview.isOpaque = false
            subview.isUserInteractionEnabled = false
        }
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
            vc.view = PassthroughView()
            vc.view.backgroundColor = .clear
            vc.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.icon),
                tag: 0
            )
            return vc
        }
    }

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
              let index = vcs.firstIndex(of: viewController) else { return false }
        let tabs = visibleTabs()
        guard index < tabs.count else { return false }

        let tab = tabs[index].name
        webVC.webView?.evaluateJavaScript("""
            window.location.hash='#\(tab)';
            window.dispatchEvent(new HashChangeEvent('hashchange'));
        """)
        selectedIndex = index
        return false
    }

    // MARK: - NativeTabDelegate (messages from web via WineCellarViewController)

    func webDidSwitchTab(_ tab: String) {
        selectTab(named: tab)
    }

    func webDidChangeUnlockState(_ unlocked: Bool) {
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
}
