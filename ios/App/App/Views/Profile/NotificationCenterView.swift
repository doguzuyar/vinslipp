import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject var store: NotificationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.unreadCount > 0 {
                        Button("Read All") {
                            withAnimation { store.markAllAsRead() }
                        }
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No notifications yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationList: some View {
        List {
            ForEach(store.notifications) { notification in
                notificationRow(notification)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.delete(notification.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if !notification.isRead {
                            Button {
                                store.markAsRead(notification.id)
                            } label: {
                                Label("Read", systemImage: "envelope.open")
                            }
                            .tint(.accentColor)
                        }
                    }
                    .onTapGesture {
                        if !notification.isRead {
                            withAnimation { store.markAsRead(notification.id) }
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func notificationRow(_ notification: StoredNotification) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
                .opacity(notification.isRead ? 0 : 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .lineLimit(1)
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(notification.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
    }
}
