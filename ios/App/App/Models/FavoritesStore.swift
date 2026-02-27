import Foundation

@MainActor
class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<String> = []

    private static let storageKey = "favorite_wines"

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
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        ids = decoded
    }
}
