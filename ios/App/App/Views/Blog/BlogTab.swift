import SwiftUI
import FirebaseAuth

struct BlogTab: View {
    @StateObject private var blogService = BlogService()
    @State private var postToDelete: BlogPost?

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        VStack(spacing: 0) {
            if blogService.isLoading {
                Spacer()
                ProgressView("Loading posts...")
                Spacer()
            } else if let error = blogService.error {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await blogService.loadPosts() }
                    }
                }
                Spacer()
            } else if blogService.posts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No blog posts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Click Blog on any wine to write one")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                postList
            }
        }
        .onAppear {
            Task { await blogService.loadPostsIfNeeded() }
        }
        .refreshable {
            await blogService.loadPosts()
        }
        .alert("Delete this post?", isPresented: .init(
            get: { postToDelete != nil },
            set: { if !$0 { postToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task { await blogService.deletePost(post.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(blogService.posts) { post in
                    BlogPostCard(
                        post: post,
                        isOwner: currentUserId == post.userId,
                        onDelete: { postToDelete = post }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .contentMargins(.bottom, 16)
    }
}

// MARK: - Blog Post Card

private struct BlogPostCard: View {
    let post: BlogPost
    let isOwner: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.4))
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 10) {
                // Wine info + delete
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(post.winery)
                            .font(.footnote.weight(.semibold))
                        Text(post.vintage.isEmpty ? post.wineName : "\(post.wineName) \(post.vintage)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isOwner {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Comment
                Text(post.comment)
                    .font(.footnote)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Author + date
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    Text(post.userName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let date = post.createdAt {
                        Text(formatDate(date))
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .padding(.leading, 12)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, HH:mm"
        return fmt.string(from: date)
    }
}
