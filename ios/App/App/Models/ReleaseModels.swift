import Foundation

struct ReleaseData: Codable {
    let wines: [ReleaseWine]
    let dateColors: [String: String]
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
    let vivinoLink: String
    let sbLink: String
    let ratingScore: Int?
    let ratingReason: String?
    let rowColor: String

    var priceNumeric: Int {
        Int(price.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
    }

    var launchDateParsed: Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: launchDate)
    }

    var countryEnglish: String {
        switch country {
        case "Frankrike": return "France"
        case "Italien": return "Italy"
        case "Spanien": return "Spain"
        case "Tyskland": return "Germany"
        case "USA": return "USA"
        case "Sydafrika": return "South Africa"
        case "Australien": return "Australia"
        case "Chile": return "Chile"
        case "Portugal": return "Portugal"
        case "Argentina": return "Argentina"
        default: return country
        }
    }

    var wineTypeEnglish: String {
        switch wineType {
        case "Rött vin": return "Red"
        case "Vitt vin": return "White"
        case "Rosévin": return "Rosé"
        case "Mousserande vin": return "Sparkling"
        default: return "Other"
        }
    }
}

struct AppMetadata: Codable {
    let releaseUpdated: String
    let auctionUpdated: String
    let generatedAt: String
}
