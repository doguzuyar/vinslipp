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
            LazyVStack(spacing: 12) {
                ForEach(blogService.posts) { post in
                    BlogPostCard(
                        post: post,
                        isOwner: currentUserId == post.userId,
                        onDelete: { postToDelete = post }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
        VStack(alignment: .leading, spacing: 8) {
            // Header: winery + wine name + delete
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.winery)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 4) {
                        Text(post.wineName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !post.vintage.isEmpty {
                            Text(post.vintage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if isOwner {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Comment
            Text(post.comment)
                .font(.subheadline)
                .lineSpacing(3)

            // Footer: user + date
            HStack(spacing: 8) {
                Text(post.userName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let date = post.createdAt {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, HH:mm"
        return fmt.string(from: date)
    }
}
