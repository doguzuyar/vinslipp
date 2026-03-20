import Foundation

@MainActor
class DataService: ObservableObject {
    @Published var releaseData: ReleaseData?
    @Published var auctionData: AuctionData?
    @Published var isLoading = false
    @Published var isLoadingAuction = false
    @Published var error: String?
    @Published var auctionError: String?
    @Published var liveWinesData: LiveWinesData?
    @Published var isLoadingLiveWines = false
    @Published var liveWinesError: String?

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
            writeWineNamesToAppGroup(releases.wines)
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

    func loadLiveWines() async {
        let isFirstLoad = liveWinesData == nil
        if isFirstLoad {
            isLoadingLiveWines = true
        }
        liveWinesError = nil

        let result: LiveWinesData? = await fetch("\(baseURL)/live_wines.json")
        if let result {
            liveWinesData = result
        } else if isFirstLoad {
            liveWinesError = "Failed to load live wines"
        }
        isLoadingLiveWines = false
    }

    private func writeWineNamesToAppGroup(_ wines: [ReleaseWine]) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: FavoritesStore.appGroup)?
            .appendingPathComponent("wine_names.json") else { return }
        let map = Dictionary(wines.map { ($0.productNumber, $0.wineName) }, uniquingKeysWith: { _, last in last })
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func fetch<T: Decodable>(_ urlString: String) async -> T? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
