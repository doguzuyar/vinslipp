import SwiftUI

struct WineRow: View {
    let wine: ReleaseWine
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: wine.rowColor))
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(wine.producer)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        if let score = wine.ratingScore, score > 0 {
                            Text(String(repeating: "\u{2605}", count: score))
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    HStack {
                        Text(wine.wineName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(wine.price)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text(wine.launchDateFormatted)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(wine.vintage)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if !wine.region.isEmpty {
                            Text(wine.region)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Text(wine.wineTypeEnglish)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if isExpanded {
                WineDetail(wine: wine)
            }
        }
        .background(
            isExpanded ? Color(hex: wine.rowColor).opacity(0.15) : Color.clear
        )
    }
}
