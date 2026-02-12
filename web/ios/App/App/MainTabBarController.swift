import UIKit
import WebKit

/// A view that passes all touches through to views behind it.
private class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

class MainTabBarController: UITabBarController, UITabBarControllerDelegate, NativeTabDelegate, UISearchBarDelegate {
    let webVC: WineCellarViewController

    private let searchBar = UISearchBar()
    private var searchBarBottomConstraint: NSLayoutConstraint?

    private let allTabs: [(name: String, title: String, icon: String)] = [
        ("release",  "Release", "clock"),
        ("cellar",   "Cellar",  "cube.box"),
        ("blog",     "Blog",    "doc.text"),
        ("auction",  "Auction", "dollarsign.circle"),
        ("profile",  "Profile", "person.circle"),
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

        setupSearchBar()

        tabBar.isTranslucent = true
        tabBar.tintColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 231/255, green: 229/255, blue: 228/255, alpha: 1)   // #e7e5e4
                : UIColor(red: 28/255, green: 25/255, blue: 23/255, alpha: 1)      // #1c1917
        }
        tabBar.unselectedItemTintColor = UIColor(red: 120/255, green: 113/255, blue: 108/255, alpha: 1) // #78716c

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 12/255, green: 10/255, blue: 9/255, alpha: 0.72)    // dark
                    : UIColor(red: 250/255, green: 250/255, blue: 249/255, alpha: 0.72) // light
            }
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }

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

    override var prefersStatusBarHidden: Bool { true }
    override var childForStatusBarHidden: UIViewController? { nil }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.backgroundColor = .clear
        view.bringSubviewToFront(tabBar)
        view.bringSubviewToFront(searchBar)
        for subview in view.subviews where subview !== webVC.view {
            if tabBar.isDescendant(of: subview) { continue }
            if subview === searchBar { continue }
            subview.backgroundColor = .clear
            subview.isOpaque = false
            subview.isUserInteractionEnabled = false
        }
    }

    // MARK: - Search bar

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search producers..."
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.isHidden = true

        view.addSubview(searchBar)
        searchBarBottomConstraint = searchBar.bottomAnchor.constraint(equalTo: tabBar.topAnchor)
        NSLayoutConstraint.activate([
            searchBarBottomConstraint!,
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard !searchBar.isHidden,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        searchBarBottomConstraint?.isActive = false
        searchBarBottomConstraint = searchBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -frame.height)
        searchBarBottomConstraint?.isActive = true
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        searchBarBottomConstraint?.isActive = false
        searchBarBottomConstraint = searchBar.bottomAnchor.constraint(equalTo: tabBar.topAnchor)
        searchBarBottomConstraint?.isActive = true
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    private func updateSearchBarVisibility() {
        let isAuction = selectedIndex < allTabs.count && allTabs[selectedIndex].name == "auction"
        searchBar.isHidden = !isAuction
        if !isAuction {
            searchBar.text = ""
            searchBar.resignFirstResponder()
        }
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let escaped = searchText.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        webVC.webView?.evaluateJavaScript("""
            window.__nativeAuctionSearch && window.__nativeAuctionSearch('\(escaped)');
        """)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    // MARK: - Tab management

    private func rebuildTabs() {
        viewControllers = allTabs.map { tab in
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
        if let index = allTabs.firstIndex(where: { $0.name == name }) {
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
        guard index < allTabs.count else { return false }

        let tab = allTabs[index].name
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        webVC.webView?.evaluateJavaScript("""
            window.location.hash='#\(tab)';
            window.dispatchEvent(new HashChangeEvent('hashchange'));
        """)
        selectedIndex = index
        updateSearchBarVisibility()
        return false
    }

    // MARK: - NativeTabDelegate (messages from web via WineCellarViewController)

    func webDidSwitchTab(_ tab: String) {
        selectTab(named: tab)
        updateSearchBarVisibility()
    }
}
