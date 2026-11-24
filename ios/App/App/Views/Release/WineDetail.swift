import SwiftUI

struct WineDetail: View {
    let wine: ReleaseWine
    @EnvironmentObject var cellarService: CellarService
    @State private var showAddToCellar = false
    @State private var safariURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if let reason = wine.ratingReason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    if let url = URL(string: wine.searchLink) {
                        Button { safariURL = url } label: {
                            Label("Search", systemImage: "globe")
                        }
                    }
                    if let url = URL(string: wine.sbLink) {
                        Button { safariURL = url } label: {
                            Label("Systembolaget", systemImage: "cart")
                        }
                    }
                    Button { showAddToCellar = true } label: {
                        Label("Cellar", systemImage: "plus.circle")
                    }
                    Spacer()
                }
                .font(.caption.weight(.medium))

                HStack(spacing: 16) {
                    if !wine.region.isEmpty {
                        DetailChip(label: "Region", value: wine.region)
                    }
                    if !wine.country.isEmpty {
                        DetailChip(label: "Country", value: wine.countryEnglish)
                    }
                    DetailChip(label: "Type", value: wine.wineTypeEnglish)
                }
            }
            .overlay(alignment: .trailing) {
                if let imageUrl = wine.imageUrl, !imageUrl.isEmpty {
                    GeometryReader { geo in
                        WineImage(urlString: imageUrl)
                            .frame(height: geo.size.height)
                            .position(x: geo.size.width - 40, y: geo.size.height / 2)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showAddToCellar) {
            WineEditSheet(
                entry: CellarEntry(
                    status: .cellar,
                    winery: wine.producer,
                    wineName: wine.wineName,
                    vintage: wine.vintage,
                    region: wine.region,
                    country: wine.countryEnglish,
                    wineType: wine.wineTypeEnglish,
                    price: wine.price,
                    count: 1,
                    drinkYear: "",
                    links: [wine.searchLink],
                    source: .release
                ),
                isNew: true
            ) { entry in
                cellarService.addEntry(entry)
            }
        }
    }
}

private struct WineImage: View {
    let urlString: String
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxHeight: .infinity)
        .task(id: urlString) {
            guard uiImage == nil, let url = URL(string: urlString) else { return }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let img = UIImage(data: data) {
                uiImage = img
            }
        }
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
