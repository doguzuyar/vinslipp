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
    @AppStorage("cellar_searchText") private var searchText = ""
    @State private var showFilePicker = false
    @AppStorage("cellar_chartMode") private var showVintage = false
    @AppStorage("cellar_showHistory") private var showHistory = false
    @AppStorage("cellar_selectedLocation") private var selectedLocation: String = ""

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

    private var filteredHistory: [HistoryWine] {
        guard let history = cellarService.historyData else { return [] }
        var wines = history

        if !selectedLocation.isEmpty {
            wines = wines.filter { $0.location == selectedLocation }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            wines = wines.filter {
                $0.winery.lowercased().contains(query) ||
                $0.wineName.lowercased().contains(query) ||
                $0.region.lowercased().contains(query)
            }
        }

        return wines
    }

    private var uniqueLocations: [String] {
        guard let history = cellarService.historyData else { return [] }
        return Array(Set(history.compactMap { $0.location.isEmpty ? nil : $0.location })).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let data = cellarService.cellarData {
                if showHistory {
                    historyBar
                    historyList
                } else {
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
                }
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

            if let error = cellarService.error {
                Text(error)
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
        HStack(spacing: 6) {
            if cellarService.historyData != nil {
                FilterChip(label: "Cellar", isActive: false) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHistory = true
                    }
                }
            }
            FilterChip(label: showVintage ? "Vintage" : "Drink year", isActive: false) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showVintage.toggle()
                    selectedYear = nil
                }
            }
            Button {
                cellarService.clearData()
                selectedYear = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
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
        }
        .padding(.horizontal, 12)
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
        SearchBar(text: $searchText)
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

    // MARK: - History Bar

    private var historyBar: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(label: "History", isActive: false) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showHistory = false
                        }
                    }
                    Menu {
                        ForEach(uniqueLocations, id: \.self) { location in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedLocation = selectedLocation == location ? "" : location
                                }
                            } label: {
                                HStack {
                                    Text(location)
                                    if selectedLocation == location {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        FilterChipLabel(
                            label: "Location",
                            isActive: !selectedLocation.isEmpty
                        )
                    }
                    if !selectedLocation.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedLocation = ""
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            Text("\(filteredHistory.count) wines")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredHistory) { wine in
                    HistoryWineRow(wine: wine)
                    Divider().padding(.leading, 16)
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

            switch CSVFileType.detect(from: data) {
            case .prices: pricesData = data
            case .cellar: cellarData = data
            case .wineList: wineListData = data
            case nil: cellarData = data
            }
        }

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
                        Text("×\(wine.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
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
                        Text(wine.vintage)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if !wine.region.isEmpty {
                            Text(wine.region)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(wine.drinkYear)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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

// MARK: - History Wine Row

private struct HistoryWineRow: View {
    let wine: HistoryWine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(wine.winery)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(wine.wineName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 8) {
                if !wine.vintage.isEmpty {
                    Text(wine.vintage)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if !wine.region.isEmpty {
                    Text(wine.region)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if !wine.country.isEmpty {
                    Text(wine.country)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
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
