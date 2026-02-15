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
    let vivinoLink: String
    let sbLink: String
    let ratingScore: Int?
    let ratingReason: String?

    var priceNumeric: Int {
        price.priceNumeric
    }

    var launchDateParsed: Date? {
        DateFormatters.iso.date(from: launchDate)
    }

    var countryEnglish: String {
        switch country {
        case "Frankrike": return "France"
        case "Italien": return "Italy"
        case "Spanien": return "Spain"
        case "Portugal": return "Portugal"
        case "Grekland": return "Greece"
        case "Tyskland": return "Germany"
        case "Ungern": return "Hungary"
        case "Österrike": return "Austria"
        case "USA": return "USA"
        case "Sydafrika": return "South Africa"
        case "Australien": return "Australia"
        case "Chile": return "Chile"
        case "Argentina": return "Argentina"
        case "Nya Zeeland": return "New Zealand"
        case "Libanon": return "Lebanon"
        case "Georgien": return "Georgia"
        case "Rumänien": return "Romania"
        case "Kroatien": return "Croatia"
        case "Schweiz": return "Switzerland"
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
