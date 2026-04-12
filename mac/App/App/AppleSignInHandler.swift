import AuthenticationServices
import CryptoKit
import FirebaseAuth
import AppKit

class AppleSignInHandler: NSObject, ASAuthorizationControllerDelegate,
                           ASAuthorizationControllerPresentationContextProviding {

    private var currentNonce: String?
    var onSignIn: ((String, String, String) -> Void)?
    private var pendingDeletion = false
    var onDeleteSuccess: (() -> Void)?
    var onDeleteError: ((Error) -> Void)?

    func startDeleteAccount() {
        pendingDeletion = true
        performRequest(scopes: [])
    }

    func startSignIn() {
        performRequest(scopes: [.fullName, .email])
    }

    private func performRequest(scopes: [ASAuthorization.Scope]) {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = scopes
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        if pendingDeletion {
            pendingDeletion = false
            guard let authCodeData = appleCredential.authorizationCode,
                  let authCode = String(data: authCodeData, encoding: .utf8) else {
                onDeleteError?(NSError(domain: "AppleSignIn", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not get authorization code."]))
                return
            }
            Task {
                do {
                    try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
                    try await Auth.auth().currentUser?.delete()
                    await MainActor.run { self.onDeleteSuccess?() }
                } catch {
                    await MainActor.run { self.onDeleteError?(error) }
                }
            }
            return
        }

        guard let idTokenData = appleCredential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8),
              let nonce = currentNonce else { return }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        let appleDisplayName = [appleCredential.fullName?.givenName,
                                appleCredential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        Auth.auth().signIn(with: credential) { [weak self] result, error in
            guard let user = result?.user, error == nil else { return }
            let email = user.email ?? ""

            guard !appleDisplayName.isEmpty else {
                self?.onSignIn?(user.uid, user.displayName ?? "", email)
                return
            }

            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = appleDisplayName
            changeRequest.commitChanges { _ in
                self?.onSignIn?(user.uid, appleDisplayName, email)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
