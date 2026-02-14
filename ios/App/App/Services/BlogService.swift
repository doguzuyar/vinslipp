import Foundation
import FirebaseFirestore
import FirebaseAuth

struct BlogPost: Identifiable {
    let id: String
    let wineId: String
    let wineName: String
    let winery: String
    let vintage: String
    let userId: String
    let userName: String
    let comment: String
    let createdAt: Date?
    let moderationStatus: String?
}

@MainActor
class BlogService: ObservableObject {
    @Published var posts: [BlogPost] = []
    @Published var isLoading = false
    @Published var error: String?

    private let db = Firestore.firestore()
    private var lastFetchedAt: Date?
    private let cacheSeconds: TimeInterval = 1800

    func loadPostsIfNeeded() async {
        if let last = lastFetchedAt, Date().timeIntervalSince(last) < cacheSeconds {
            return
        }
        await loadPosts()
    }

    func loadPosts() async {
        isLoading = posts.isEmpty
        error = nil

        do {
            let snapshot = try await db.collection("blog_posts")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            let fetched: [BlogPost] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard data["moderationStatus"] as? String == "pass" else { return nil }
                let timestamp = data["createdAt"] as? Timestamp
                return BlogPost(
                    id: doc.documentID,
                    wineId: data["wineId"] as? String ?? "",
                    wineName: data["wineName"] as? String ?? "",
                    winery: data["winery"] as? String ?? "",
                    vintage: data["vintage"] as? String ?? "",
                    userId: data["userId"] as? String ?? "",
                    userName: data["userName"] as? String ?? "",
                    comment: data["comment"] as? String ?? "",
                    createdAt: timestamp?.dateValue(),
                    moderationStatus: data["moderationStatus"] as? String
                )
            }

            posts = fetched
            lastFetchedAt = Date()
        } catch {
            if posts.isEmpty {
                self.error = "Failed to load blog posts"
            }
            print("BlogService error: \(error)")
        }
        isLoading = false
    }

    func addPost(wineId: String, wineName: String, winery: String, vintage: String, comment: String, displayName: String? = nil) async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        do {
            try await db.collection("blog_posts").addDocument(data: [
                "wineId": wineId,
                "wineName": wineName,
                "winery": winery,
                "vintage": vintage,
                "userId": user.uid,
                "userName": displayName ?? user.displayName ?? "Vinslipp User",
                "comment": comment,
                "createdAt": FieldValue.serverTimestamp(),
            ])
            return true
        } catch {
            print("Add post error: \(error)")
            return false
        }
    }

    func deletePost(_ postId: String) async {
        do {
            try await db.collection("blog_posts").document(postId).delete()
            posts.removeAll { $0.id == postId }
        } catch {
            print("Delete error: \(error)")
        }
    }
}
