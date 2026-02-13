import SwiftUI

struct WineDetail: View {
    let wine: ReleaseWine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            if let reason = wine.ratingReason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                if !wine.vivinoLink.isEmpty {
                    Link(destination: URL(string: wine.vivinoLink)!) {
                        Label("Vivino", systemImage: "globe")
                            .font(.caption.weight(.medium))
                    }
                }
                if !wine.sbLink.isEmpty {
                    Link(destination: URL(string: wine.sbLink)!) {
                        Label("Systembolaget", systemImage: "cart")
                            .font(.caption.weight(.medium))
                    }
                }
            }

            HStack(spacing: 16) {
                DetailChip(label: "Nr", value: wine.productNumber)
                if !wine.country.isEmpty {
                    DetailChip(label: "Country", value: wine.countryEnglish)
                }
                DetailChip(label: "Type", value: wine.wineTypeEnglish)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
    }
}

struct DetailChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
