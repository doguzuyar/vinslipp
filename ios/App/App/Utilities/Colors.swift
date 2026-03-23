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
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        return f
    }

    static let iso = formatter("yyyy-MM-dd")
    static let shortTimestamp = formatter("MMM d, HH:mm")
    static let monthAbbrev = formatter("MMM")

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
        ("french-red", "French Red"),
        ("french-white", "French White"),
        ("italian-red", "Italian Red"),
        ("italian-white", "Italian White"),
    ]

    static let allValues: [String] = all.map(\.value)
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

    private static let topicFilters: [String: (country: String, wineType: String)] = [
        "french-red": ("France", "Red Wine"),
        "french-white": ("France", "White Wine"),
        "italian-red": ("Italy", "Red Wine"),
        "italian-white": ("Italy", "White Wine"),
    ]

    @MainActor
    static func filter(_ wines: [ReleaseWine], topic: String, favorites: FavoritesStore) -> [ReleaseWine] {
        switch topic {
        case "all":
            return wines
        case "favorites":
            return wines.filter { favorites.isFavorite($0.productNumber) }
        default:
            guard let f = topicFilters[topic] else { return wines }
            return wines.filter { $0.countryEnglish == f.country && $0.wineTypeEnglish == f.wineType }
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
