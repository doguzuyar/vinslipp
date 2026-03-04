import Foundation

@MainActor
class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<String> = []

    static let appGroup = "group.com.nybroans.vinslipp"
    static let storageKey = "favorite_wines"

    static var sharedFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("favorites.json")
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroup) ?? .standard
    }

    init() {
        load()
    }

    func isFavorite(_ id: String) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        defaults.set(data, forKey: Self.storageKey)
        if let url = Self.sharedFileURL {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load() {
        if let url = Self.sharedFileURL, let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            ids = decoded
            return
        }
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        ids = decoded
        // Migrate to shared file
        if let url = Self.sharedFileURL, let encoded = try? JSONEncoder().encode(ids) {
            try? encoded.write(to: url, options: .atomic)
        }
    }
}
