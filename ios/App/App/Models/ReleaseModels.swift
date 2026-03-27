import Foundation

struct ReleaseData: Codable {
    let wines: [ReleaseWine]
    let totalCount: Int
}

struct ReleaseWine: Codable, Identifiable {
    var id: String { productNumber }
    let launchDate: String
    let launchDateFormatted: String
    let producer: String
    let wineName: String
    let vintage: String
    let price: String
    let region: String
    let country: String
    let wineType: String
    let productNumber: String
    let searchLink: String
    let sbLink: String
    let imageUrl: String?
    let ratingScore: Int?
    let ratingReason: String?

    var priceNumeric: Int {
        price.priceNumeric
    }

    private static let countryTranslations: [String: String] = [
        "Frankrike": "France",
        "Italien": "Italy",
        "Spanien": "Spain",
        "Portugal": "Portugal",
        "Grekland": "Greece",
        "Tyskland": "Germany",
        "Ungern": "Hungary",
        "Österrike": "Austria",
        "USA": "USA",
        "Sydafrika": "South Africa",
        "Australien": "Australia",
        "Chile": "Chile",
        "Argentina": "Argentina",
        "Nya Zeeland": "New Zealand",
        "Libanon": "Lebanon",
        "Georgien": "Georgia",
        "Rumänien": "Romania",
        "Kroatien": "Croatia",
        "Schweiz": "Switzerland",
    ]

    var countryEnglish: String {
        Self.countryTranslations[country] ?? country
    }

    private static let wineTypeTranslations: [String: String] = [
        "Rött vin": "Red Wine",
        "Vitt vin": "White Wine",
        "Rosévin": "Rosé Wine",
        "Mousserande vin": "Sparkling Wine",
    ]

    var wineTypeEnglish: String {
        Self.wineTypeTranslations[wineType] ?? "Other"
    }
}
