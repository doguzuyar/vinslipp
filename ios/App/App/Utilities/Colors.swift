import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255.0,
            green: Double((int >> 8) & 0xFF) / 255.0,
            blue: Double(int & 0xFF) / 255.0
        )
    }

    static let vinslippBordeaux = Color(hex: "4D1421")
    static let vinslippBurgundy = Color(hex: "722F37")
}

// MARK: - Shared Date Formatters

enum DateFormatters {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let shortTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()

    static let monthAbbrev: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    static var todayString: String {
        iso.string(from: Date())
    }
}

// MARK: - Price Parsing

extension String {
    var priceNumeric: Int {
        Int(replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
    }

    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Notification Topics

enum NotificationTopics {
    static let all: [(value: String, label: String)] = [
        ("favorites", "Favorites"),
        ("french-red", "French Red"),
        ("french-white", "French White"),
        ("italian-red", "Italian Red"),
        ("italian-white", "Italian White"),
    ]

    static let allValues: [String] = all.map(\.value)

    /// FCM category topics (all topics except "favorites").
    static let categoryTopics: [String] = all.map(\.value).filter { $0 != "favorites" }
}

// MARK: - Swipe Topics

enum SwipeTopics {
    static let all: [(value: String, label: String)] = [
        ("all", "All Wines"),
        ("favorites", "Favorites"),
        ("french-red", "French Red"),
        ("french-white", "French White"),
        ("italian-red", "Italian Red"),
        ("italian-white", "Italian White"),
    ]

    @MainActor
    static func filter(_ wines: [ReleaseWine], topic: String, favorites: FavoritesStore) -> [ReleaseWine] {
        switch topic {
        case "all":
            return wines
        case "favorites":
            return wines.filter { favorites.isFavorite($0.productNumber) }
        case "french-red":
            return wines.filter { $0.countryEnglish == "France" && $0.wineTypeEnglish == "Red Wine" }
        case "french-white":
            return wines.filter { $0.countryEnglish == "France" && $0.wineTypeEnglish == "White Wine" }
        case "italian-red":
            return wines.filter { $0.countryEnglish == "Italy" && $0.wineTypeEnglish == "Red Wine" }
        case "italian-white":
            return wines.filter { $0.countryEnglish == "Italy" && $0.wineTypeEnglish == "White Wine" }
        default:
            return wines
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search wines..."

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))
            TextField(placeholder, text: $text)
                .font(.body)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
