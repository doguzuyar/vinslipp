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
}

enum CellarColors {
    private static let palette = [
        "#f3abab", "#f8bbd0", "#d4a3dc", "#e1bee7",
        "#7ec4f8", "#bbdefb", "#6bc4ba", "#b2dfdb",
        "#96d098", "#c8e6c9", "#ffe066", "#fff9c4",
        "#ffc570", "#ffe0b2", "#f8a0bc",
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
