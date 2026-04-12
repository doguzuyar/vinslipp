import Foundation

enum WineStatus: String, Codable, CaseIterable {
    case cellar
    case history
}

enum WineSource: String, Codable, CaseIterable {
    case manual
    case release
    case auction
    case imported
}

// MARK: - Cellar Entry

struct CellarEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var status: WineStatus
    var winery: String
    var wineName: String
    var vintage: String
    var region: String
    var country: String
    var style: String
    var wineType: String
    var price: String
    var count: Int
    var drinkYear: String
    var links: [String]
    var userRating: String
    var averageRating: String
    var notes: String
    var source: WineSource
    var addedDate: String

    var priceNumeric: Int {
        price.priceNumeric
    }

    var color: String {
        guard let year = Int(drinkYear) ?? Int(vintage) else { return "#888888" }
        return AppColors.color(forYear: year)
    }

    init(
        id: UUID = UUID(),
        status: WineStatus = .cellar,
        winery: String = "",
        wineName: String = "",
        vintage: String = "",
        region: String = "",
        country: String = "",
        style: String = "",
        wineType: String = "",
        price: String = "",
        count: Int = 1,
        drinkYear: String = "",
        links: [String] = [],
        userRating: String = "",
        averageRating: String = "",
        notes: String = "",
        source: WineSource = .manual,
        addedDate: String = DateFormatters.todayString
    ) {
        self.id = id
        self.status = status
        self.winery = winery
        self.wineName = wineName
        self.vintage = vintage
        self.region = region
        self.country = country
        self.style = style
        self.wineType = wineType
        self.price = price
        self.count = count
        self.drinkYear = drinkYear
        self.links = links
        self.userRating = userRating
        self.averageRating = averageRating
        self.notes = notes
        self.source = source
        self.addedDate = addedDate
    }

    // Supports both legacy "link" (String) and current "links" ([String]) JSON
    enum CodingKeys: String, CodingKey {
        case id, status, winery, wineName, vintage, region, country
        case style, wineType, price, count, drinkYear
        case links, link
        case userRating, averageRating, notes, source, addedDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        status = try c.decode(WineStatus.self, forKey: .status)
        winery = try c.decodeIfPresent(String.self, forKey: .winery) ?? ""
        wineName = try c.decodeIfPresent(String.self, forKey: .wineName) ?? ""
        vintage = try c.decodeIfPresent(String.self, forKey: .vintage) ?? ""
        region = try c.decodeIfPresent(String.self, forKey: .region) ?? ""
        country = try c.decodeIfPresent(String.self, forKey: .country) ?? ""
        style = try c.decodeIfPresent(String.self, forKey: .style) ?? ""
        wineType = try c.decodeIfPresent(String.self, forKey: .wineType) ?? ""
        price = try c.decodeIfPresent(String.self, forKey: .price) ?? ""
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 1
        drinkYear = try c.decodeIfPresent(String.self, forKey: .drinkYear) ?? ""
        userRating = try c.decodeIfPresent(String.self, forKey: .userRating) ?? ""
        averageRating = try c.decodeIfPresent(String.self, forKey: .averageRating) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        source = try c.decodeIfPresent(WineSource.self, forKey: .source) ?? .manual
        addedDate = try c.decodeIfPresent(String.self, forKey: .addedDate) ?? DateFormatters.todayString

        if let arr = try? c.decode([String].self, forKey: .links) {
            links = arr
        } else if let single = try? c.decode(String.self, forKey: .link), !single.isEmpty {
            links = [single]
        } else {
            links = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(status, forKey: .status)
        try c.encode(winery, forKey: .winery)
        try c.encode(wineName, forKey: .wineName)
        try c.encode(vintage, forKey: .vintage)
        try c.encode(region, forKey: .region)
        try c.encode(country, forKey: .country)
        try c.encode(style, forKey: .style)
        try c.encode(wineType, forKey: .wineType)
        try c.encode(price, forKey: .price)
        try c.encode(count, forKey: .count)
        try c.encode(drinkYear, forKey: .drinkYear)
        try c.encode(links, forKey: .links)
        try c.encode(userRating, forKey: .userRating)
        try c.encode(averageRating, forKey: .averageRating)
        try c.encode(notes, forKey: .notes)
        try c.encode(source, forKey: .source)
        try c.encode(addedDate, forKey: .addedDate)
    }
}

// MARK: - Cellar Data

struct CellarData {
    let wines: [CellarEntry]
    let yearCounts: [String: Int]
    let vintageCounts: [String: Int]
    let totalBottles: Int
    let totalValue: Int
    let colorPalette: [String: String]
    let vintagePalette: [String: String]

    init(from entries: [CellarEntry]) {
        let cellarWines = entries.filter { $0.status == .cellar && $0.count > 0 }
        self.wines = cellarWines

        var yearCounts: [String: Int] = [:]
        var vintageCounts: [String: Int] = [:]
        var totalBottles = 0
        var totalValue = 0
        var allYears: Set<Int> = []

        for wine in cellarWines {
            let yearKey = wine.drinkYear.nonEmpty ?? wine.vintage.nonEmpty ?? "-"
            yearCounts[yearKey, default: 0] += wine.count

            let vintageKey = wine.vintage.nonEmpty ?? "-"
            vintageCounts[vintageKey, default: 0] += wine.count

            if let year = Int(yearKey) { allYears.insert(year) }

            totalBottles += wine.count
            totalValue += wine.priceNumeric * wine.count
        }

        self.yearCounts = yearCounts
        self.vintageCounts = vintageCounts
        self.totalBottles = totalBottles
        self.totalValue = totalValue
        self.colorPalette = AppColors.buildPalette(years: Array(allYears))

        let vintageYears = vintageCounts.keys.compactMap { Int($0) }
        self.vintagePalette = AppColors.buildPalette(years: vintageYears)
    }
}

// MARK: - Color Palette

enum AppColors {
    static let palette = [
        "#ee9595", "#f8bbd0", "#c890d8", "#e1bee7",
        "#6ab8f5", "#bbdefb", "#58bfb0", "#b2dfdb",
        "#82c888", "#c8e6c9", "#ffd84a", "#fff9c4",
        "#ffb855", "#ffe0b2",
    ]

    static func color(forYear year: Int) -> String {
        let index = (year - 2026) % palette.count
        return palette[index >= 0 ? index : index + palette.count]
    }

    static func buildPalette(years: [Int]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: years.map { (String($0), color(forYear: $0)) })
    }

    static func buildDateColors(dates: [String]) -> [String: String] {
        let sorted = Set(dates).sorted()
        return Dictionary(uniqueKeysWithValues: sorted.enumerated().map { i, date in
            (date, palette[i % palette.count])
        })
    }
}
