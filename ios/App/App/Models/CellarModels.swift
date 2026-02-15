import Foundation

struct CellarWine: Identifiable, Codable {
    var id: String { "\(link)-\(drinkYear)-\(vintage)" }
    let drinkYear: String
    let winery: String
    let wineName: String
    let vintage: String
    let region: String
    let style: String
    let price: String
    let count: Int
    let link: String
    let color: String

    var priceNumeric: Int {
        price.priceNumeric
    }
}

struct CellarData: Codable {
    let wines: [CellarWine]
    let yearCounts: [String: Int]
    let vintageCounts: [String: Int]
    let totalBottles: Int
    let totalValue: Int
    let colorPalette: [String: String]
    let vintagePalette: [String: String]
}

struct HistoryWine: Identifiable, Codable {
    var id: String { link.isEmpty ? "\(winery)-\(wineName)-\(vintage)" : link }
    let winery: String
    let wineName: String
    let vintage: String
    let region: String
    let country: String
    let style: String
    let averageRating: String
    let scanDate: String
    let location: String
    let userRating: String
    let wineType: String
    let link: String
}

enum AppColors {
    static let palette = [
        "#ee9595", "#f8bbd0", "#c890d8", "#e1bee7",
        "#6ab8f5", "#bbdefb", "#58bfb0", "#b2dfdb",
        "#82c888", "#c8e6c9", "#ffd84a", "#fff9c4",
        "#ffb855", "#ffe0b2", "#ee9595",
    ]

    static func color(forYear year: Int) -> String {
        let index = (year - 2026) % palette.count
        return palette[index >= 0 ? index : index + palette.count]
    }

    static func buildPalette(years: [Int]) -> [String: String] {
        var result: [String: String] = [:]
        for year in years {
            result[String(year)] = color(forYear: year)
        }
        return result
    }

    /// Assign colors to sorted release dates (same cycling logic as years)
    static func buildDateColors(dates: [String]) -> [String: String] {
        let sorted = Set(dates).sorted()
        var result: [String: String] = [:]
        for (i, date) in sorted.enumerated() {
            result[date] = palette[i % palette.count]
        }
        return result
    }
}
