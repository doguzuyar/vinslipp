import Foundation

struct AuctionData: Codable {
    let summary: AuctionSummary
    let producers: [String: AuctionProducerData]
}

struct AuctionSummary: Codable {
    let total_wines: Int
    let unique_producers: Int
}

struct AuctionProducerData: Codable {
    let total_lots: Int
    let sold: Int
    let sell_rate: Double
    let avg_estimate_sek: Int
    let avg_hammer_sek: Int
    let avg_ratio: Double?
    let premium_percent: Double?
    let vintages: [Int]
    let info: String?
}

struct AuctionProducer: Identifiable {
    var id: String { name }
    let name: String
    let totalLots: Int
    let sold: Int
    let sellRate: Double
    let avgEstimateSek: Int
    let avgHammerSek: Int
    let avgRatio: Double?
    let premiumPercent: Double?
    let vintages: [Int]
    let info: String?

    init(name: String, data: AuctionProducerData) {
        self.name = name
        self.totalLots = data.total_lots
        self.sold = data.sold
        self.sellRate = data.sell_rate
        self.avgEstimateSek = data.avg_estimate_sek
        self.avgHammerSek = data.avg_hammer_sek
        self.avgRatio = data.avg_ratio
        self.premiumPercent = data.premium_percent
        self.vintages = data.vintages
        self.info = data.info
    }
}

// MARK: - Live Wines

struct LiveWinesData: Codable {
    let total_wines: Int
    let bordeaux_count: Int
    let burgundy_count: Int
    let wines: [LiveWine]
}

struct LiveWine: Identifiable {
    var id: String { lot_id }
    let lot_id: String
    let title: String
    let url: String
    let estimate: String
    let hammer_price: String
    let auction: String
    let category: String
    let rating_score: Int
    let rating_reason: String
    let vintage: Int

    var estimateNumeric: Int { estimate.priceNumeric }
    var age: Int? { vintage > 0 ? 2026 - vintage : nil }
}

extension LiveWine: Codable {
    enum CodingKeys: String, CodingKey {
        case lot_id, title, url, estimate, hammer_price, auction, category
        case rating_score, rating_reason, vintage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lot_id = try c.decode(String.self, forKey: .lot_id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        estimate = try c.decodeIfPresent(String.self, forKey: .estimate) ?? "0 SEK"
        hammer_price = try c.decodeIfPresent(String.self, forKey: .hammer_price) ?? ""
        auction = try c.decodeIfPresent(String.self, forKey: .auction) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        rating_score = try c.decodeIfPresent(Int.self, forKey: .rating_score) ?? 0
        rating_reason = try c.decodeIfPresent(String.self, forKey: .rating_reason) ?? ""
        vintage = try c.decodeIfPresent(Int.self, forKey: .vintage) ?? 0
    }
}
