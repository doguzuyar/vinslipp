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
    @State private var expandedWineId: UUID?
    @AppStorage("cellar_sortField") private var sortField: CellarSortField = .year
    @AppStorage("cellar_sortDirection") private var sortDirection: SortDirection = .ascending
    @AppStorage("cellar_searchText") private var searchText = ""
    @State private var showFilePicker = false
    @AppStorage("cellar_chartMode") private var showVintage = false
    @AppStorage("cellar_showHistory") private var showHistory = false
    @State private var showAddSheet = false
    @State private var editingEntry: CellarEntry?
    @State private var shareURL: URL?
    @State private var deleteCandidate: CellarEntry?

    private var filtered: [CellarEntry] {
        guard let data = cellarService.cellarData else { return [] }
        var wines = data.wines

        if let year = selectedYear {
            wines = wines.filter { wine in
                if showVintage {
                    return wine.vintage == year
                } else {
                    let yearKey = wine.drinkYear.isEmpty
                        ? (wine.vintage.isEmpty ? "-" : wine.vintage)
                        : wine.drinkYear
                    return yearKey == year
                }
            }
        }

        return sorted(filteredBySearch(wines))
    }

    private var filteredHistory: [CellarEntry] {
        filteredBySearch(cellarService.historyEntries)
    }

    private func filteredBySearch(_ wines: [CellarEntry]) -> [CellarEntry] {
        guard !searchText.isEmpty else { return wines }
        let query = searchText.lowercased()
        return wines.filter {
            $0.winery.lowercased().contains(query) ||
            $0.wineName.lowercased().contains(query) ||
            $0.region.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if let data = cellarService.cellarData {
                if showHistory {
                    VStack(spacing: 0) {
                        historyBar
                        historyList
                        SearchBar(text: $searchText)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            filterBar(data: data)
                            Spacer()
                            statsBar(data: data)
                                .layoutPriority(-1)
                            Spacer()
                            sortBar
                        }

                        HStack(alignment: .top, spacing: 0) {
                            BottleChart(
                                yearCounts: showVintage ? data.vintageCounts : data.yearCounts,
                                colorPalette: showVintage ? data.vintagePalette : data.colorPalette,
                                selectedYear: $selectedYear,
                                vertical: true
                            )
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                            .frame(width: 300)

                            Divider()

                            VStack(spacing: 0) {
                                wineList
                                SearchBar(text: $searchText)
                            }
                        }
                    }
                }
            } else if cellarService.isProcessing {
                VStack {
                    Spacer()
                    ProgressView("Processing...")
                    Spacer()
                }
            } else {
                emptyState
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result, !urls.isEmpty {
                cellarService.importFromURLs(urls)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            WineEditSheet(entry: CellarEntry(), isNew: true) { newEntry in
                cellarService.addEntry(newEntry)
            }
        }
        .sheet(item: $editingEntry) { entry in
            WineEditSheet(
                entry: entry,
                isNew: false,
                onDuplicate: { edited in
                    cellarService.addEntry(edited.duplicated())
                }
            ) { updated in
                cellarService.updateEntry(updated)
            }
        }
        .onChange(of: shareURL) {
            if let url = shareURL {
                let picker = NSSharingServicePicker(items: [url])
                if let contentView = NSApplication.shared.keyWindow?.contentView {
                    picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                }
                shareURL = nil
            }
        }
        .alert(
            "Remove Wine",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )
        ) {
            if let entry = deleteCandidate, entry.count > 1 {
                Button("Remove 1 Bottle") {
                    cellarService.decrementCount(id: entry.id)
                    deleteCandidate = nil
                }
            }
            Button("Move to History") {
                if let entry = deleteCandidate {
                    cellarService.moveToHistory(id: entry.id)
                    deleteCandidate = nil
                }
            }
            Button("Delete Permanently", role: .destructive) {
                if let entry = deleteCandidate {
                    cellarService.removeEntry(id: entry.id)
                    deleteCandidate = nil
                }
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: {
            if let entry = deleteCandidate {
                Text("What would you like to do with \(entry.winery) \(entry.wineName)?")
            }
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
            Text("Add wines from Releases or Auctions, or import your cellar")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Wine", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.systemGray5)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Import Cellar", systemImage: "doc.badge.plus")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.systemGray5)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if let error = cellarService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Ways to build your cellar:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Tap \"Add to Cellar\" on any wine in Releases or Auctions")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Manually add wines with the Add Wine button")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Import a previously exported Vinslipp cellar file")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - Summary Bar

    private func filterBar(data: CellarData) -> some View {
        HStack(spacing: 6) {
            if cellarService.hasHistory {
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
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    if let url = cellarService.exportCSV() {
                        shareURL = url
                    }
                } label: {
                    Label("Export Cellar", systemImage: "square.and.arrow.up")
                }
                Button {
                    showFilePicker = true
                } label: {
                    Label("Import Cellar", systemImage: "doc.badge.plus")
                }
                Divider()
                Button(role: .destructive) {
                    cellarService.clearData()
                    selectedYear = nil
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func statsBar(data: CellarData) -> some View {
        HStack(spacing: 8) {
            Text("\(data.totalBottles) bottles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if data.totalValue > 0 {
                Text("\u{00B7}")
                    .foregroundStyle(.tertiary)
                Text("\(data.totalValue.formatted()) SEK")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
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
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Wine List

    private var wineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { wine in
                    CellarWineRow(
                        wine: wine,
                        isExpanded: expandedWineId == wine.id,
                        onEdit: { editingEntry = wine },
                        onDelete: { deleteCandidate = wine },
                        onIncrement: { cellarService.incrementCount(id: wine.id) },
                        onDecrement: {
                            deleteCandidate = wine
                        }
                    )
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
    }

    // MARK: - History Bar

    private var historyBar: some View {
        HStack(spacing: 6) {
            FilterChip(label: "History", isActive: false) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistory = false
                }
            }

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(Color.systemGray5)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
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
                    HistoryWineRow(
                        wine: wine,
                        isExpanded: expandedWineId == wine.id,
                        onEdit: { editingEntry = wine },
                        onDelete: { cellarService.removeEntry(id: wine.id) },
                        onRestore: { cellarService.incrementCount(id: wine.id) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedWineId = expandedWineId == wine.id ? nil : wine.id
                        }
                    }
                    Divider().padding(.leading, 16)
                }
            }
        }
    }

    // MARK: - Sorting

    private func sorted(_ wines: [CellarEntry]) -> [CellarEntry] {
        wines.sorted { a, b in
            let result: Bool
            switch sortField {
            case .year:
                if showVintage {
                    result = a.vintage < b.vintage
                } else {
                    let aYear = a.drinkYear.isEmpty ? a.vintage : a.drinkYear
                    let bYear = b.drinkYear.isEmpty ? b.vintage : b.drinkYear
                    result = aYear < bYear
                }
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
}

// MARK: - Cellar Wine Row

struct CellarWineRow: View {
    let wine: CellarEntry
    let isExpanded: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

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
                        Text("\u{00d7}\(wine.count)")
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
                        if !wine.country.isEmpty {
                            Text(wine.country)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !wine.wineType.isEmpty {
                            Text(wine.wineType)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if !wine.drinkYear.isEmpty {
                            Text(wine.drinkYear)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if isExpanded {
                CellarWineDetail(
                    wine: wine,
                    onEdit: onEdit,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement
                )
            }
        }
        .background(
            isExpanded ? Color(hex: wine.color).opacity(0.15) : Color.clear
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - History Wine Row

private struct HistoryWineRow: View {
    let wine: CellarEntry
    let isExpanded: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    if !wine.wineType.isEmpty {
                        Text(wine.wineType)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack(spacing: 12) {
                        linkButtons(wine.links)
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        Button(action: onRestore) {
                            Label("Restore to Cellar", systemImage: "arrow.uturn.backward")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    if !wine.notes.isEmpty {
                        Text(wine.notes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 10)
            }
        }
        .background(isExpanded ? Color.systemGray5.opacity(0.5) : Color.clear)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(action: onRestore) {
                Label("Restore to Cellar", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Cellar Wine Detail

struct CellarWineDetail: View {
    let wine: CellarEntry
    let onEdit: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 12) {
                linkButtons(wine.links)

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onDecrement) {
                        Image(systemName: "minus.circle")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .disabled(wine.count <= 0)

                    Text("\(wine.count)")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .frame(minWidth: 20)

                    Button(action: onIncrement) {
                        Image(systemName: "plus.circle")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !wine.notes.isEmpty {
                Text(wine.notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
    }
}

// MARK: - Link Label Helper

@ViewBuilder
private func linkButtons(_ links: [String]) -> some View {
    ForEach(links.filter { !$0.isEmpty }, id: \.self) { linkStr in
        if let url = URL(string: linkStr) {
            Button { LinkOpener.open(url) } label: {
                Label(linkLabel(linkStr), systemImage: "globe")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.plain)
        }
    }
}

private func linkLabel(_ urlString: String) -> String {
    guard let host = URL(string: urlString)?.host?.lowercased() else { return "Link" }
    if host.contains("vivino") { return "Vivino" }
    if host.contains("bukowskis") { return "Bukowskis" }
    if host.contains("systembolaget") { return "Systembolaget" }
    return "Link"
}
