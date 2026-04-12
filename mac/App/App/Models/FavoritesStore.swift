import Foundation

@MainActor
class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<String> = []

    static let appGroup = "group.com.nybroans.vinslipp"
    static let storageKey = "favorite_wines"

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
        if ids.remove(id) == nil {
            ids.insert(id)
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        ids = decoded
    }
}
