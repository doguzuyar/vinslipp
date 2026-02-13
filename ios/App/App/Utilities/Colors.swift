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
}

enum WineColors {
    static let tabTint = Color(hex: "#1c1917")
    static let tabUnselected = Color(hex: "#78716c")

    static func rowColor(_ hex: String) -> Color {
        Color(hex: hex)
    }
}
