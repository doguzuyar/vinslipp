import Foundation

@MainActor
class DataService: ObservableObject {
    @Published var releaseData: ReleaseData?
    @Published var metadata: AppMetadata?
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = "https://vinslipp.app/data"

    func loadReleases() async {
        isLoading = true
        error = nil

        async let releaseFetch: ReleaseData? = fetch("\(baseURL)/releases.json")
        async let metaFetch: AppMetadata? = fetch("\(baseURL)/metadata.json")

        let (releases, meta) = await (releaseFetch, metaFetch)
        releaseData = releases
        metadata = meta

        if releases == nil {
            error = "Failed to load wine data"
        }
        isLoading = false
    }

    private func fetch<T: Codable>(_ urlString: String) async -> T? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Fetch error for \(urlString): \(error)")
            return nil
        }
    }
}
