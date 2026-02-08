import UIKit
import SafariServices
import WebKit
import Capacitor

class WineCellarViewController: CAPBridgeViewController, WKScriptMessageHandler {
    override func viewDidLoad() {
        super.viewDidLoad()
        webView?.configuration.userContentController.add(self, name: "openInApp")
        webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: [.new], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.isLoading),
           let isLoading = change?[.newKey] as? Bool,
           !isLoading {
            injectLinkHandler()
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

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "openInApp",
              let urlString = message.body as? String,
              let url = URL(string: urlString) else { return }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "openInApp")
    }
}
