import SwiftUI
import FirebaseAuth
import UniformTypeIdentifiers

struct ProfileTab: View {
    @ObservedObject var cellarService: CellarService
    @StateObject private var authManager = AuthManager()
    @AppStorage("notification_topic") private var notificationTopic = "none"
    @AppStorage("app_theme") private var appTheme = "dark"
    @State private var showNotifications = false
    @State private var showFilePicker = false

    private let notificationOptions: [(value: String, label: String)] = [
        ("french-red", "French Red"),
        ("french-white", "French White"),
        ("italian-red", "Italian Red"),
        ("italian-white", "Italian White"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if let user = authManager.user {
                signedInView(user: user)
            } else {
                signedOutView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: true
        ) { result in
            handleFiles(result)
        }
    }

    // MARK: - Signed Out

    private var signedOutView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Sign in to sync your data across devices")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            SignInWithAppleButton {
                authManager.signIn()
            }
            .frame(width: 220, height: 44)

            themeButton
            notificationButton
            cellarButton

            Spacer()
        }
    }

    // MARK: - Signed In

    private func signedInView(user: User) -> some View {
        VStack(spacing: 20) {
            Spacer()

            let initial = String((user.displayName ?? "?").prefix(1)).uppercased()
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 72, height: 72)
                Text(initial)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(user.displayName ?? "User")
                .font(.title3.weight(.semibold))

            if let email = user.email, !email.isEmpty {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            themeButton
            notificationButton
            cellarButton

            Button {
                authManager.signOut()
            } label: {
                Text("Sign Out")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
    }

    // MARK: - Theme

    private var themeButton: some View {
        HStack(spacing: 0) {
            ForEach(["dark", "light", "system"], id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { appTheme = option }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: option == "dark" ? "moon.fill" : option == "light" ? "sun.max.fill" : "gear")
                            .font(.caption2)
                        Text(option.capitalized)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(appTheme == option ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(appTheme == option ? Color(.systemGray5) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 280)
    }

    // MARK: - Notifications

    private var notificationButton: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation { showNotifications.toggle() }
            } label: {
                HStack {
                    Image(systemName: "bell")
                        .font(.subheadline)
                    Text("Notifications")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(notificationTopic == "none" ? "Off" : notificationOptions.first { $0.value == notificationTopic }?.label ?? "On")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: showNotifications ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: 280)

            if showNotifications {
                VStack(spacing: 4) {
                    ForEach(notificationOptions, id: \.value) { option in
                        Button {
                            notificationTopic = notificationTopic == option.value ? "none" : option.value
                        } label: {
                            HStack {
                                Circle()
                                    .fill(notificationTopic == option.value ? Color.accentColor : Color.clear)
                                    .overlay(
                                        Circle()
                                            .stroke(notificationTopic == option.value ? Color.clear : Color.secondary, lineWidth: 1.5)
                                    )
                                    .frame(width: 18, height: 18)
                                Text(option.label)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(notificationTopic == option.value ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: 280)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Cellar Import

    private var cellarButton: some View {
        Button {
            showFilePicker = true
        } label: {
            HStack {
                Image(systemName: "cube.box")
                    .font(.subheadline)
                Text(cellarService.cellarData != nil ? "Update Vivino data" : "Import Vivino data")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let importedAt = cellarService.importedAt {
                    Text(importedAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: 280)
    }

    // MARK: - File Import

    private func handleFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }

        var cellarData: Data?
        var pricesData: Data?
        var wineListData: Data?

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }

            if let text = String(data: data, encoding: .utf8) {
                let header = String(text.prefix(500)).lowercased()
                if header.contains("wine price") {
                    pricesData = data
                } else if header.contains("user cellar count") {
                    cellarData = data
                } else if header.contains("scan date") || header.contains("drinking window") {
                    wineListData = data
                } else {
                    cellarData = data
                }
            }
        }

        if urls.count == 1 && cellarData == nil {
            cellarData = pricesData ?? wineListData
            pricesData = nil
            wineListData = nil
        }

        if cellarData != nil || wineListData != nil {
            cellarService.importFiles(
                cellarCSV: cellarData,
                wineListCSV: wineListData,
                pricesCSV: pricesData
            )
        }
    }
}

// MARK: - Sign In With Apple Button

private struct SignInWithAppleButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .medium))
                Text("Sign in with Apple")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    private var handle: AuthStateDidChangeListenerHandle?
    private let appleHandler = AppleSignInHandler()

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func signIn() {
        appleHandler.startSignIn()
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}
