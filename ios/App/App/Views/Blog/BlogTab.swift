import SwiftUI
import FirebaseAuth

struct BlogTab: View {
    @StateObject private var blogService = BlogService()
    @State private var postToDelete: BlogPost?
    @AppStorage("blog_myPostsOnly") private var myPostsOnly = false

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private var displayedPosts: [BlogPost] {
        if myPostsOnly, let uid = currentUserId {
            return blogService.posts.filter { $0.userId == uid }
        }
        return blogService.posts
    }

    private var groupedByWine: [(key: String, winery: String, wineName: String, vintage: String, posts: [BlogPost])] {
        let grouped = Dictionary(grouping: displayedPosts) { $0.wineId }
        return grouped.map { (wineId, posts) in
            let first = posts[0]
            let sorted = posts.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            return (key: wineId, winery: first.winery, wineName: first.wineName, vintage: first.vintage, posts: sorted)
        }
        .sorted { group1, group2 in
            let date1 = group1.posts.first?.createdAt ?? .distantPast
            let date2 = group2.posts.first?.createdAt ?? .distantPast
            return date1 > date2
        }
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
                filterBar
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            FilterChip(label: myPostsOnly ? "My posts" : "All posts", isActive: myPostsOnly) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    myPostsOnly.toggle()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Post List

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(groupedByWine, id: \.key) { group in
                    WineGroupCard(
                        winery: group.winery,
                        wineName: group.wineName,
                        vintage: group.vintage,
                        posts: group.posts,
                        currentUserId: currentUserId,
                        onDelete: { post in postToDelete = post }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .contentMargins(.bottom, 16)
    }
}

// MARK: - Wine Group Card

private struct WineGroupCard: View {
    let winery: String
    let wineName: String
    let vintage: String
    let posts: [BlogPost]
    let currentUserId: String?
    let onDelete: (BlogPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(winery)
                        .font(.footnote.weight(.semibold))
                    Text(vintage.isEmpty ? wineName : "\(wineName) \(vintage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(posts.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, 14)
                }
                CommentRow(
                    post: post,
                    isOwner: currentUserId == post.userId,
                    onDelete: { onDelete(post) }
                )
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let post: BlogPost
    let isOwner: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.comment)
                .font(.footnote)
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

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
                if isOwner {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formatDate(_ date: Date) -> String {
        DateFormatters.shortTimestamp.string(from: date)
    }
}
