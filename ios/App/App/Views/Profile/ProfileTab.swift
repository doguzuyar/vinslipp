import SwiftUI
import FirebaseAuth
import FirebaseMessaging

struct ProfileTab: View {
    @EnvironmentObject var cellarService: CellarService
    @StateObject private var authManager = AuthManager()
    @AppStorage("notification_topic", store: AppDelegate.sharedDefaults) private var notificationTopic = "none"
    @AppStorage("app_theme") private var appTheme = "dark"
    @State private var showNotifications = false
    @State private var showDeleteConfirm = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if let user = authManager.user {
                signedInView(user: user)
            } else {
                signedOutView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: notificationTopic) { _, newValue in
            for topic in NotificationTopics.allValues {
                Messaging.messaging().unsubscribe(fromTopic: topic)
            }
            if newValue != "none" {
                Messaging.messaging().subscribe(toTopic: newValue)
            }
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

            cellarSyncStatus

            themeButton
            notificationButton

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

            Button {
                showDeleteConfirm = true
            } label: {
                Text("Delete Account")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Delete Account", role: .destructive) {
                cellarService.cancelPendingPush()
                authManager.deleteAccount(
                    onSuccess: { cellarService.forgetCloudAccount() },
                    onError: { err in deleteErrorMessage = err.localizedDescription }
                )
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your account and all associated data. This cannot be undone.")
        }
        .alert("Deletion Failed", isPresented: .constant(deleteErrorMessage != nil)) {
            Button("OK") { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    // MARK: - Cellar Sync Status

    private var cellarSyncStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: syncStatusIcon)
                .font(.caption)
                .foregroundStyle(syncStatusColor)
            Text(syncStatusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var syncStatusIcon: String {
        switch cellarService.syncStatus {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        case .offline: return "icloud.slash"
        }
    }

    private var syncStatusColor: Color {
        switch cellarService.syncStatus {
        case .synced: return .green
        case .error: return .orange
        case .syncing: return .secondary
        case .offline: return .secondary
        }
    }

    private var syncStatusLabel: String {
        switch cellarService.syncStatus {
        case .syncing: return "Syncing cellar..."
        case .synced(let date): return "Cellar synced \(relativeTime(date))"
        case .error(let msg): return "Sync error: \(msg)"
        case .offline: return "Cellar saved on this device"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Theme

    private var themeButton: some View {
        HStack(spacing: 0) {
            ForEach(["dark", "light", "system"], id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { appTheme = option }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: themeIcon(for: option))
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

    private func themeIcon(for option: String) -> String {
        switch option {
        case "dark": return "moon.fill"
        case "light": return "sun.max.fill"
        default: return "gear"
        }
    }

    // MARK: - Notifications

    private var notificationButton: some View {
        ExpandableSettingButton(
            icon: "bell",
            title: "Notifications",
            statusLabel: topicLabel(notificationTopic, in: NotificationTopics.all),
            isExpanded: $showNotifications,
            options: NotificationTopics.all,
            selectedValue: notificationTopic
        ) { value in
            notificationTopic = notificationTopic == value ? "none" : value
        }
    }

    private func topicLabel(_ selected: String, in options: [(value: String, label: String)]) -> String {
        if selected == "none" { return "Off" }
        return options.first { $0.value == selected }?.label ?? "On"
    }
}

// MARK: - Expandable Setting Button

private struct ExpandableSettingButton: View {
    let icon: String
    let title: String
    let statusLabel: String
    @Binding var isExpanded: Bool
    let options: [(value: String, label: String)]
    let selectedValue: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(options, id: \.value) { option in
                        let isSelected = selectedValue == option.value
                        Button {
                            onSelect(option.value)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color.clear)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected ? Color.clear : Color.secondary, lineWidth: 1.5)
                                    )
                                    .frame(width: 18, height: 18)
                                Text(option.label)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: 280)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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

    func deleteAccount(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        appleHandler.onDeleteSuccess = {
            try? Auth.auth().signOut()
            onSuccess()
        }
        appleHandler.onDeleteError = onError
        appleHandler.startDeleteAccount()
    }
}
