import Foundation

struct WineSuggestion: Identifiable, Hashable {
    let id: String
    let winery: String
    let wineName: String
    let vintage: String
    let region: String
    let country: String
    let wineType: String

    init(winery: String, wineName: String, vintage: String, region: String, country: String, wineType: String) {
        self.winery = winery
        self.wineName = wineName
        self.vintage = vintage
        self.region = region
        self.country = country
        self.wineType = wineType
        self.id = "\(winery.lowercased())|\(wineName.lowercased())|\(vintage.lowercased())"
    }

    init(from release: ReleaseWine) {
        self.init(
            winery: release.producer,
            wineName: release.wineName,
            vintage: release.vintage,
            region: release.region,
            country: release.countryEnglish,
            wineType: release.wineTypeEnglish
        )
    }

    init(from entry: CellarEntry) {
        self.init(
            winery: entry.winery,
            wineName: entry.wineName,
            vintage: entry.vintage,
            region: entry.region,
            country: entry.country,
            wineType: entry.wineType
        )
    }

    init(from producer: AuctionProducer) {
        self.init(
            winery: producer.name,
            wineName: "",
            vintage: "",
            region: producer.regions.first?.capitalized ?? "",
            country: "France",
            wineType: "Red Wine"
        )
    }
}

enum WineSuggestionField {
    case winery, wineName, region, country, wineType
}

struct WineSuggestionIndex {
    let suggestions: [WineSuggestion]

    init(releases: [ReleaseWine], cellar: [CellarEntry], auctionProducers: [AuctionProducer] = []) {
        var seen: Set<String> = []
        var result: [WineSuggestion] = []
        for release in releases {
            let suggestion = WineSuggestion(from: release)
            if seen.insert(suggestion.id).inserted {
                result.append(suggestion)
            }
        }
        for entry in cellar where !entry.winery.isEmpty {
            let suggestion = WineSuggestion(from: entry)
            if seen.insert(suggestion.id).inserted {
                result.append(suggestion)
            }
        }
        for producer in auctionProducers where !producer.name.isEmpty {
            let suggestion = WineSuggestion(from: producer)
            if seen.insert(suggestion.id).inserted {
                result.append(suggestion)
            }
        }
        self.suggestions = result
    }

    func match(_ query: String, field: WineSuggestionField, limit: Int = 5) -> [WineSuggestion] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var matches: [WineSuggestion] = []
        for suggestion in suggestions {
            let target = field == .winery ? suggestion.winery : suggestion.wineName
            if target.lowercased().contains(q) {
                matches.append(suggestion)
                if matches.count >= limit { break }
            }
        }
        return matches
    }

    func matchDistinct(_ query: String, field: WineSuggestionField, limit: Int = 5) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var seen: Set<String> = []
        var result: [String] = []
        for suggestion in suggestions {
            let target: String
            switch field {
            case .region: target = suggestion.region
            case .country: target = suggestion.country
            case .wineType: target = suggestion.wineType
            default: continue
            }
            guard !target.isEmpty, target.lowercased().contains(q) else { continue }
            let key = target.lowercased()
            if seen.insert(key).inserted {
                result.append(target)
                if result.count >= limit { break }
            }
        }
        return result
    }
}
