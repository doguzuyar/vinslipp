import Foundation

struct ReleaseData: Codable {
    let wines: [ReleaseWine]
    let totalCount: Int
}

struct ReleaseWine: Identifiable {
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
    let imageUrl: String?
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
        case "Rött vin": return "Red Wine"
        case "Vitt vin": return "White Wine"
        case "Rosévin": return "Rosé Wine"
        case "Mousserande vin": return "Sparkling Wine"
        default: return "Other"
        }
    }
}

extension ReleaseWine: Codable {
    enum CodingKeys: String, CodingKey {
        case launchDate, launchDateFormatted, producer, wineName, vintage
        case price, region, country, wineType, productNumber
        case vivinoLink, sbLink, imageUrl, ratingScore, ratingReason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        launchDate = try c.decode(String.self, forKey: .launchDate)
        launchDateFormatted = try c.decode(String.self, forKey: .launchDateFormatted)
        producer = try c.decode(String.self, forKey: .producer)
        wineName = try c.decode(String.self, forKey: .wineName)
        vintage = try c.decode(String.self, forKey: .vintage)
        price = try c.decode(String.self, forKey: .price)
        region = try c.decode(String.self, forKey: .region)
        country = try c.decode(String.self, forKey: .country)
        wineType = try c.decode(String.self, forKey: .wineType)
        productNumber = try c.decode(String.self, forKey: .productNumber)
        vivinoLink = try c.decode(String.self, forKey: .vivinoLink)
        sbLink = try c.decode(String.self, forKey: .sbLink)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        ratingScore = try c.decodeIfPresent(Int.self, forKey: .ratingScore)
        ratingReason = try c.decodeIfPresent(String.self, forKey: .ratingReason)
    }
}
