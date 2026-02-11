import UIKit
import SafariServices
import WebKit
import Capacitor
import FirebaseAuth

protocol NativeTabDelegate: AnyObject {
    func webDidSwitchTab(_ tab: String)
}

class WineCellarViewController: CAPBridgeViewController, WKScriptMessageHandler {
    weak var tabDelegate: NativeTabDelegate?
    private var appleSignInHandler: AppleSignInHandler?

    override func viewDidLoad() {
        super.viewDidLoad()
        let ucc = webView?.configuration.userContentController
        ucc?.add(self, name: "openInApp")
        ucc?.add(self, name: "tabSwitch")
        ucc?.add(self, name: "appleSignIn")
        ucc?.add(self, name: "appleSignOut")
        webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: [.new], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.isLoading),
           let isLoading = change?[.newKey] as? Bool,
           !isLoading {
            injectLinkHandler()
            sendExistingAuthToWeb()
        }
    }

    private func injectLinkHandler() {
        let js = """
        if (!window.__openInAppInstalled) {
            window.__openInAppInstalled = true;
            document.addEventListener('click', function(e) {
                var a = e.target.closest('a[target="_blank"]');
                if (a) {
                    e.preventDefault();
                    e.stopPropagation();
                    window.webkit.messageHandlers.openInApp.postMessage(a.href);
                }
            }, true);
        }
        """
        webView?.evaluateJavaScript(js)
    }

    private func sendExistingAuthToWeb() {
        guard let user = Auth.auth().currentUser else { return }
        let handler = AppleSignInHandler(webView: webView)
        handler.sendUserToWeb(uid: user.uid, displayName: user.displayName ?? "")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "openInApp":
            guard let urlString = message.body as? String,
                  let url = URL(string: urlString) else { return }
            let safari = SFSafariViewController(url: url)
            let presenter = view.window?.rootViewController ?? self
            presenter.present(safari, animated: true)

        case "tabSwitch":
            if let tab = message.body as? String {
                tabDelegate?.webDidSwitchTab(tab)
            }

        case "appleSignIn":
            appleSignInHandler = AppleSignInHandler(webView: webView)
            appleSignInHandler?.startSignIn()

        case "appleSignOut":
            try? Auth.auth().signOut()
            appleSignInHandler = AppleSignInHandler(webView: webView)
            appleSignInHandler?.sendSignOutToWeb()

        default:
            break
        }
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
        let ucc = webView?.configuration.userContentController
        ucc?.removeScriptMessageHandler(forName: "openInApp")
        ucc?.removeScriptMessageHandler(forName: "tabSwitch")
        ucc?.removeScriptMessageHandler(forName: "appleSignIn")
        ucc?.removeScriptMessageHandler(forName: "appleSignOut")
    }
}
