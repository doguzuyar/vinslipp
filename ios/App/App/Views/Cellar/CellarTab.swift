import SwiftUI
import UniformTypeIdentifiers

enum CellarSortField: String, CaseIterable {
    case year, winery, wine, vintage, region, price, count

    var label: String {
        switch self {
        case .year: return "Year"
        case .winery: return "Winery"
        case .wine: return "Wine"
        case .vintage: return "Vintage"
        case .region: return "Region"
        case .price: return "Price"
        case .count: return "Count"
        }
    }
}

struct CellarTab: View {
    @ObservedObject var cellarService: CellarService
    @State private var selectedYear: String?
    @State private var expandedWineId: String?
    @AppStorage("cellar_sortField") private var sortField: CellarSortField = .year
    @AppStorage("cellar_sortDirection") private var sortDirection: SortDirection = .ascending
    @State private var searchText = ""
    @State private var showFilePicker = false
    @AppStorage("cellar_chartMode") private var showVintage = false

    private var filtered: [CellarWine] {
        guard let data = cellarService.cellarData else { return [] }
        var wines = data.wines

        if let year = selectedYear {
            wines = wines.filter { showVintage ? $0.vintage == year : $0.drinkYear == year }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            wines = wines.filter {
                $0.winery.lowercased().contains(query) ||
                $0.wineName.lowercased().contains(query) ||
                $0.region.lowercased().contains(query)
            }
        }

        return sorted(wines)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let data = cellarService.cellarData {
                BottleChart(
                    yearCounts: showVintage ? data.vintageCounts : data.yearCounts,
                    colorPalette: showVintage ? data.vintagePalette : data.colorPalette,
                    selectedYear: $selectedYear
                )
                .padding(.horizontal, 12)
                .padding(.top, 4)

                summaryBar(data: data)

                sortBar

                wineList
            } else if cellarService.isProcessing {
                Spacer()
                ProgressView("Processing CSV...")
                Spacer()
            } else {
                emptyState
            }
        }
        .safeAreaInset(edge: .bottom) {
            if cellarService.cellarData != nil {
                searchBar
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: true
        ) { result in
            handleFiles(result)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Cellar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Import your Vivino export to see your cellar")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showFilePicker = true
            } label: {
                Label("Import Vivino CSV files", systemImage: "doc.badge.plus")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if cellarService.error != nil {
                Text(cellarService.error!)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tip: Drink year planning")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("By default, the chart groups bottles by vintage. To plan when to drink each wine, add target years in the Personal Note field on Vivino (e.g. \"2026, 2028, 2030\") the chart will use those instead.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)

            Spacer()
        }
    }

    // MARK: - Summary Bar

    private func summaryBar(data: CellarData) -> some View {
        HStack {
            Text("\(data.totalBottles) bottles")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            if data.totalValue > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(data.totalValue.formatted()) SEK")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showVintage.toggle()
                    selectedYear = nil
                }
            } label: {
                Text(showVintage ? "Vintage" : "Drink year")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            Button {
                cellarService.clearData()
                selectedYear = nil
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(CellarSortField.allCases, id: \.self) { field in
                    Button {
                        if sortField == field {
                            sortDirection = sortDirection == .ascending ? .descending : .ascending
                        } else {
                            sortField = field
                            sortDirection = .ascending
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(field.label)
                                .font(.system(size: 10, weight: sortField == field ? .bold : .regular))
                            if sortField == field {
                                Image(systemName: sortDirection == .ascending ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundStyle(sortField == field ? .primary : .tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))
            TextField("Search wines...", text: $searchText)
                .font(.body)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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

    // MARK: - Wine List

    private var wineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { wine in
                    CellarWineRow(wine: wine, isExpanded: expandedWineId == wine.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedWineId = expandedWineId == wine.id ? nil : wine.id
                            }
                        }
                    Divider().padding(.leading, 28)
                }
            }
        }
        .contentMargins(.bottom, 16)
    }

    // MARK: - Sorting

    private func sorted(_ wines: [CellarWine]) -> [CellarWine] {
        wines.sorted { a, b in
            let result: Bool
            switch sortField {
            case .year:
                result = showVintage ? a.vintage < b.vintage : a.drinkYear < b.drinkYear
            case .winery:
                result = a.winery.localizedCaseInsensitiveCompare(b.winery) == .orderedAscending
            case .wine:
                result = a.wineName.localizedCaseInsensitiveCompare(b.wineName) == .orderedAscending
            case .vintage:
                result = a.vintage < b.vintage
            case .region:
                result = a.region.localizedCaseInsensitiveCompare(b.region) == .orderedAscending
            case .price:
                result = a.priceNumeric < b.priceNumeric
            case .count:
                result = a.count < b.count
            }
            return sortDirection == .ascending ? result : !result
        }
    }

    // MARK: - File Import

    private func handleFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }

        var cellarData: Data?
        var pricesData: Data?
        var wineListData: Data?

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }

            // Detect file type by headers
            if let text = String(data: data, encoding: .utf8) {
                let header = String(text.prefix(500)).lowercased()
                if header.contains("wine price") {
                    pricesData = data
                } else if header.contains("user cellar count") {
                    cellarData = data
                } else if header.contains("scan date") || header.contains("drinking window") {
                    wineListData = data
                } else {
                    // Fallback: treat as cellar
                    cellarData = data
                }
            }
        }

        // If only one file selected, treat it as cellar
        if urls.count == 1 && cellarData == nil {
            cellarData = pricesData ?? wineListData
            pricesData = nil
            wineListData = nil
        }

        if cellarData != nil || wineListData != nil {
            cellarService.importFiles(
                cellarCSV: cellarData,
                wineListCSV: wineListData,
                pricesCSV: pricesData
            )
        }
    }
}

// MARK: - Cellar Wine Row

struct CellarWineRow: View {
    let wine: CellarWine
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: wine.color))
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(wine.winery)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        if wine.count > 1 {
                            Text("×\(wine.count)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text(wine.wineName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        if !wine.price.isEmpty {
                            Text(wine.price)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 8) {
                        Text(wine.drinkYear)
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
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if isExpanded {
                CellarWineDetail(wine: wine)
            }
        }
        .background(
            isExpanded ? Color(hex: wine.color).opacity(0.15) : Color.clear
        )
    }
}

// MARK: - Cellar Wine Detail

struct CellarWineDetail: View {
    let wine: CellarWine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            if !wine.link.isEmpty, let url = URL(string: wine.link) {
                Link(destination: url) {
                    Label("Vivino", systemImage: "globe")
                        .font(.caption.weight(.medium))
                }
            }

            HStack(spacing: 16) {
                if !wine.style.isEmpty {
                    DetailChip(label: "Style", value: wine.style)
                }
                if !wine.region.isEmpty {
                    DetailChip(label: "Region", value: wine.region)
                }
                DetailChip(label: "Bottles", value: "\(wine.count)")
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
    }
}
