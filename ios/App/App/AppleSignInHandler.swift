import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import UIKit

class AppleSignInHandler: NSObject, ASAuthorizationControllerDelegate,
                           ASAuthorizationControllerPresentationContextProviding {

    private var currentNonce: String?
    var onSignInError: ((Error) -> Void)?
    private var pendingDeletion = false
    var onReauthenticated: (() -> Void)?
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
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let window = scene?.keyWindow ?? scene?.windows.first { return window }
        return scene.map { ASPresentationAnchor(windowScene: $0) } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        if pendingDeletion {
            pendingDeletion = false
            guard let user = Auth.auth().currentUser,
                  let authCodeData = appleCredential.authorizationCode,
                  let authCode = String(data: authCodeData, encoding: .utf8),
                  let idTokenData = appleCredential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                onDeleteError?(NSError(domain: "AppleSignIn", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not verify your Apple ID. Please try again."]))
                return
            }
            let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: nil)
            Task {
                do {
                    // Firebase requires a recent login to delete; reauth before anything irreversible.
                    try await user.reauthenticate(with: credential)
                    await MainActor.run { self.onReauthenticated?() }
                    try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
                    // Cloud data goes last, so a failed step above leaves it intact.
                    let db = Firestore.firestore()
                    try await db.collection("cellar").document(user.uid).delete()
                    // Posts from the retired Blog; best effort, so it can't stop the deletion halfway.
                    if let posts = try? await db.collection("blog_posts").whereField("userId", isEqualTo: user.uid).getDocuments() {
                        for doc in posts.documents { try? await doc.reference.delete() }
                    }
                    try await user.delete()
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
            guard let user = result?.user, error == nil else {
                if let error { self?.onSignInError?(error) }
                return
            }
            // Apple only sends the name on the first sign-in, so keep it on the Firebase profile.
            guard !appleDisplayName.isEmpty else { return }
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = appleDisplayName
            changeRequest.commitChanges { _ in }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        // Reset so a cancelled deletion doesn't turn the next sign-in into a delete.
        let wasDeleting = pendingDeletion
        pendingDeletion = false
        guard (error as? ASAuthorizationError)?.code != .canceled else { return }
        if wasDeleting {
            onDeleteError?(error)
        } else {
            onSignInError?(error)
        }
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
