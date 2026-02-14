import Foundation

@MainActor
class DataService: ObservableObject {
    @Published var releaseData: ReleaseData?
    @Published var auctionData: AuctionData?
    @Published var isLoading = false
    @Published var isLoadingAuction = false
    @Published var error: String?
    @Published var auctionError: String?

    private let baseURL = "https://vinslipp.app/data"

    func loadReleases() async {
        let isFirstLoad = releaseData == nil
        if isFirstLoad {
            isLoading = true
        }
        error = nil

        let releases: ReleaseData? = await fetch("\(baseURL)/releases.json")

        if let releases {
            releaseData = releases
        } else if isFirstLoad {
            error = "Failed to load wine data"
        }
        isLoading = false
    }

    func loadAuction() async {
        let isFirstLoad = auctionData == nil
        if isFirstLoad {
            isLoadingAuction = true
        }
        auctionError = nil

        let result: AuctionData? = await fetch("\(baseURL)/auction_stats.json")
        if let result {
            auctionData = result
        } else if isFirstLoad {
            auctionError = "Failed to load auction data"
        }
        isLoadingAuction = false
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
