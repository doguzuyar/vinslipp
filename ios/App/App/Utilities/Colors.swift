import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    static let vinslippBurgundy = Color(hex: "4D1421")
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

// MARK: - CSV File Detection

enum CSVFileType {
    case cellar, prices, wineList

    static func detect(from data: Data) -> CSVFileType? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let header = String(text.prefix(500)).lowercased()
        if header.contains("wine price") {
            return .prices
        } else if header.contains("user cellar count") {
            return .cellar
        } else if header.contains("scan date") || header.contains("drinking window") {
            return .wineList
        }
        return nil
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
