import AuthenticationServices
import FirebaseAuth
import CryptoKit
import WebKit

class AppleSignInHandler: NSObject, ASAuthorizationControllerDelegate,
                           ASAuthorizationControllerPresentationContextProviding {

    private weak var webView: WKWebView?
    private var currentNonce: String?

    init(webView: WKWebView?) {
        self.webView = webView
        super.init()
    }

    func startSignIn() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        webView?.window ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let idTokenData = appleCredential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8),
              let nonce = currentNonce else { return }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        // Build display name from Apple credential (only provided on first sign-in)
        let fullName = appleCredential.fullName
        let givenName = fullName?.givenName
        let familyName = fullName?.familyName
        let appleDisplayName = [givenName, familyName].compactMap { $0 }.joined(separator: " ")

        Auth.auth().signIn(with: credential) { [weak self] result, error in
            guard let user = result?.user, error == nil else {
                print("⚠️ Auth: Apple Sign-In error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            let nameToUse = !appleDisplayName.isEmpty ? appleDisplayName : (user.displayName ?? "")

            if !appleDisplayName.isEmpty {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = appleDisplayName
                changeRequest.commitChanges { _ in
                    self?.sendUserToWeb(uid: user.uid, displayName: nameToUse, email: user.email ?? "")
                }
            } else {
                self?.sendUserToWeb(uid: user.uid, displayName: nameToUse, email: user.email ?? "")
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        print("⚠️ Auth: Apple Sign-In cancelled/error: \(error.localizedDescription)")
    }

    func sendUserToWeb(uid: String, displayName: String, email: String = "") {
        let escapedName = displayName.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedEmail = email.replacingOccurrences(of: "\"", with: "\\\"")
        let js = """
        window.__nativeAuthCallback && window.__nativeAuthCallback({
            uid: "\(uid)",
            displayName: "\(escapedName)",
            email: "\(escapedEmail)"
        });
        """
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js)
        }
    }

    func sendSignOutToWeb() {
        let js = "window.__nativeAuthCallback && window.__nativeAuthCallback(null);"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js)
        }
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return randomBytes.map { charset[Int($0) % charset.count] }.map(String.init).joined()
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
