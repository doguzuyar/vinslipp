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
        Int(price.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
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

enum CellarColors {
    private static let palette = [
        "#e8636b", "#e57399", "#b06cc8", "#c77ddb",
        "#4da6e8", "#6db8f0", "#3db5a6", "#5ccfbe",
        "#5cb85c", "#7fca7f", "#f0c030", "#f5d34a",
        "#f0a030", "#f5b84a", "#e870a0",
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
}
