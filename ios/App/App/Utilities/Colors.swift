import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let base = UIColor(
            red: CGFloat((int >> 16) & 0xFF) / 255.0,
            green: CGFloat((int >> 8) & 0xFF) / 255.0,
            blue: CGFloat(int & 0xFF) / 255.0,
            alpha: 1
        )
        // The palettes are pastels picked for the dark theme; on white they nearly vanish,
        // so light mode gets a deeper version of each bright colour. Dark mode is unchanged.
        self.init(uiColor: UIColor { traits in
            guard traits.userInterfaceStyle == .light else { return base }
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard base.getHue(&h, saturation: &s, brightness: &b, alpha: &a), b > 0.6 else { return base }
            return UIColor(hue: h, saturation: max(s, 0.55), brightness: 0.75, alpha: a)
        })
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

    // Fixed Gregorian/POSIX so yyyy-MM-dd matches the data's launch dates on any device calendar.
    static let iso: DateFormatter = {
        let f = formatter("yyyy-MM-dd")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()
    static let monthAbbrev = formatter("MMM")

    static var todayString: String {
        iso.string(from: Date())
    }
}

// MARK: - Price Parsing

extension String {
    /// Whole amount of a price like "2 000 SEK", "1,200" or "149.50 SEK".
    /// A separator before exactly three digits groups thousands; one or two digits are decimals.
    var priceNumeric: Int {
        let compact = replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard let range = compact.range(of: #"\d+(?:[.,]\d+)*"#, options: .regularExpression) else { return 0 }
        var number = String(compact[range])
        var decimals = 0.0
        if let tail = number.range(of: #"[.,]\d{1,2}$"#, options: .regularExpression) {
            decimals = Double("0." + number[tail].dropFirst()) ?? 0
            number.removeSubrange(tail)
        }
        let whole = Double(number.filter(\.isNumber)) ?? 0
        return Int((whole + decimals).rounded())
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

// MARK: - No Results

/// Shown over a list that a search or filter left empty.
struct NoResultsView: View {
    let searchText: String

    var body: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "No Matches",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Nothing matches the current filters.")
            )
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

// MARK: - Top Band

/// Some headers are pulled up into the empty band beside the Dynamic Island (and into the
/// iPad tab bar row). A screen without that band, like the iPhone Duo inner display, would
/// push them off the top, so there this is false. Measured once in ContentView.
private struct HasTopBandKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var hasTopBand: Bool {
        get { self[HasTopBandKey.self] }
        set { self[HasTopBandKey.self] = newValue }
    }
}
