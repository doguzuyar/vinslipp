import SwiftUI

enum SortField: String, CaseIterable {
    case date, producer, wine, vintage, region, price, rating
}

enum SortDirection: String {
    case ascending, descending
}

struct ReleaseTab: View {
    @ObservedObject var dataService: DataService
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var expandedWineId: String?
    @AppStorage("release_sortField") private var sortField: SortField = .date
    @AppStorage("release_sortDirection") private var sortDirection: SortDirection = .ascending
    @State private var selectedDate: String?
    @AppStorage("release_selectedCountries") private var selectedCountriesData: Data = Data()
    @AppStorage("release_selectedTypes") private var selectedTypesData: Data = Data()
    @AppStorage("release_selectedRating") private var selectedRating = ""
    @AppStorage("release_todayOnly") private var todayOnly = false
    @State private var showPastReleases = false
    @AppStorage("release_searchText") private var searchText = ""
    @State private var todayString = DateFormatters.todayString

    private var selectedCountries: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: selectedCountriesData)) ?? [] }
        nonmutating set { selectedCountriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private var selectedTypes: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: selectedTypesData)) ?? [] }
        nonmutating set { selectedTypesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private var allWines: [ReleaseWine] {
        dataService.releaseData?.wines ?? []
    }

    private var dateColors: [String: String] {
        AppColors.buildDateColors(dates: allWines.map(\.launchDate))
    }

    private var upcomingWines: [ReleaseWine] {
        filtered(allWines.filter { $0.launchDate >= todayString })
    }

    private var pastWines: [ReleaseWine] {
        filtered(allWines.filter { $0.launchDate < todayString })
    }

    private var filteredDateCounts: [String: Int] {
        let wines = filteredExcludingDate(allWines)
        var counts: [String: Int] = [:]
        for w in wines {
            counts[w.launchDate, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        Group {
            if dataService.releaseData != nil {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        filterBar
                        Spacer()
                        sortBar
                    }

                    HStack(alignment: .top, spacing: 0) {
                        MiniCalendar(
                            dateColors: dateColors,
                            filteredDateCounts: filteredDateCounts,
                            selectedDate: $selectedDate,
                            showThreeMonths: true
                        )
                        .padding(.horizontal, 12)
                        .frame(width: 300)

                        Divider()

                        VStack(spacing: 0) {
                            wineList
                            SearchBar(text: $searchText)
                        }
                    }
                }
            } else if dataService.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading wines...")
                    Spacer()
                }
            } else if let error = dataService.error {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await dataService.loadReleases() }
                    }
                    Spacer()
                }
            }
        }
        .task {
            if dataService.releaseData == nil {
                await dataService.loadReleases()
            }
        }
        .onAppear {
            todayString = DateFormatters.todayString
        }
        .onChange(of: selectedDate) { _, newValue in
            todayOnly = newValue == todayString
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            FilterChip(label: "Today", isActive: todayOnly) {
                todayOnly.toggle()
                if todayOnly {
                    selectedDate = todayString
                } else {
                    selectedDate = nil
                }
            }

            FilterChipMenu(
                label: "Country", isActive: !selectedCountries.isEmpty,
                options: countryFilters, selected: selectedCountries
            ) { toggleCountry($0) }

            FilterChipMenu(
                label: "Type", isActive: !selectedTypes.isEmpty,
                options: typeFilters, selected: selectedTypes
            ) { toggleType($0) }

            FilterChipMenu(
                label: "Rating", isActive: !selectedRating.isEmpty,
                options: ["3 Stars", "3+ Stars", "4 Stars"],
                selected: selectedRating.isEmpty ? [] : [selectedRating],
                displayLabel: { ratingLabel(for: $0) }
            ) { selectedRating = selectedRating == $0 ? "" : $0 }

            if hasActiveFilters {
                Button {
                    clearAllFilters()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack(spacing: 4) {
            ForEach(SortField.allCases, id: \.self) { field in
                Button {
                    if sortField == field {
                        sortDirection = sortDirection == .ascending ? .descending : .ascending
                    } else {
                        sortField = field
                        sortDirection = .ascending
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(field.rawValue.capitalized)
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
                ForEach(sorted(upcomingWines)) { wine in
                    wineRow(for: wine)
                    Divider().padding(.leading, 28)
                }

                if !pastWines.isEmpty {
                    Button {
                        withAnimation { showPastReleases.toggle() }
                    } label: {
                        HStack {
                            Text("Past Releases (\(pastWines.count))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: showPastReleases ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.systemGray6.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    if showPastReleases {
                        ForEach(pastWines.sorted { $0.launchDate > $1.launchDate }) { wine in
                            wineRow(for: wine)
                                .opacity(0.6)
                            Divider().padding(.leading, 28)
                        }
                    }
                }
            }
        }
    }

    private func wineRow(for wine: ReleaseWine) -> some View {
        WineRow(
            wine: wine,
            isExpanded: expandedWineId == wine.id,
            rowColor: dateColors[wine.launchDate] ?? "#888888",
            isFavorite: appDelegate.favoritesStore.isFavorite(wine.id)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedWineId = expandedWineId == wine.id ? nil : wine.id
            }
        }
    }

    // MARK: - Filtering & Sorting

    private var hasActiveFilters: Bool {
        todayOnly || !selectedCountries.isEmpty || !selectedTypes.isEmpty || !selectedRating.isEmpty || selectedDate != nil
    }

    private let knownCountries = ["France", "Italy", "Spain", "Portugal", "Greece", "Germany", "Hungary", "Austria", "USA"]

    private var countryFilters: [String] {
        let present = Set(allWines.map(\.countryEnglish))
        var result = knownCountries.filter { present.contains($0) }
        if present.contains(where: { !knownCountries.contains($0) }) {
            result.append("Other")
        }
        return result
    }

    private let knownTypes = ["Red Wine", "White Wine", "Sparkling Wine", "Rose Wine"]

    private var typeFilters: [String] {
        let present = Set(allWines.map(\.wineTypeEnglish))
        var result = knownTypes.filter { present.contains($0) }
        if present.contains("Other") {
            result.append("Other")
        }
        return result
    }

    private func filteredExcludingDate(_ wines: [ReleaseWine]) -> [ReleaseWine] {
        var result = wines

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.producer.lowercased().contains(query) ||
                $0.wineName.lowercased().contains(query) ||
                $0.region.lowercased().contains(query)
            }
        }

        if !selectedCountries.isEmpty {
            let includeOther = selectedCountries.contains("Other")
            result = result.filter {
                selectedCountries.contains($0.countryEnglish) ||
                (includeOther && !knownCountries.contains($0.countryEnglish))
            }
        }

        if !selectedTypes.isEmpty {
            result = result.filter { selectedTypes.contains($0.wineTypeEnglish) }
        }

        if !selectedRating.isEmpty {
            result = result.filter {
                guard let score = $0.ratingScore else { return false }
                switch selectedRating {
                case "4 Stars": return score == 4
                case "3+ Stars": return score >= 3
                case "3 Stars": return score == 3
                default: return true
                }
            }
        }

        return result
    }

    private func filtered(_ wines: [ReleaseWine]) -> [ReleaseWine] {
        var result = filteredExcludingDate(wines)

        if let date = selectedDate {
            result = result.filter { $0.launchDate == date }
        }

        return result
    }

    private func sorted(_ wines: [ReleaseWine]) -> [ReleaseWine] {
        wines.sorted { a, b in
            let result: Bool
            switch sortField {
            case .date:
                result = a.launchDate < b.launchDate
            case .producer:
                result = a.producer.localizedCaseInsensitiveCompare(b.producer) == .orderedAscending
            case .wine:
                result = a.wineName.localizedCaseInsensitiveCompare(b.wineName) == .orderedAscending
            case .vintage:
                result = a.vintage < b.vintage
            case .region:
                result = a.region.localizedCaseInsensitiveCompare(b.region) == .orderedAscending
            case .price:
                result = a.priceNumeric < b.priceNumeric
            case .rating:
                result = (a.ratingScore ?? 0) < (b.ratingScore ?? 0)
            }
            return sortDirection == .ascending ? result : !result
        }
    }

    private func toggleCountry(_ value: String) {
        var s = selectedCountries
        if s.contains(value) { s.remove(value) } else { s.insert(value) }
        selectedCountries = s
    }

    private func toggleType(_ value: String) {
        var s = selectedTypes
        if s.contains(value) { s.remove(value) } else { s.insert(value) }
        selectedTypes = s
    }

    private func clearAllFilters() {
        todayOnly = false
        selectedCountries = []
        selectedTypes = []
        selectedRating = ""
        selectedDate = nil
    }
}

// MARK: - Filter Chip Views

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.07))
                .foregroundColor(isActive ? .white : .gray)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct FilterChipLabel: View {
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(isActive ? .primary : .secondary)
    }
}

struct FilterChipMenu: View {
    let label: String
    let isActive: Bool
    let options: [String]
    let selected: Set<String>
    let displayLabel: ((String) -> String)?
    let onTap: (String) -> Void
    @State private var showPopover = false

    init(label: String, isActive: Bool, options: [String], selected: Set<String>, displayLabel: ((String) -> String)? = nil, onTap: @escaping (String) -> Void) {
        self.label = label
        self.isActive = isActive
        self.options = options
        self.selected = selected
        self.displayLabel = displayLabel
        self.onTap = onTap
    }

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 3) {
                Text(label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7))
            }
            .font(.caption2.weight(.medium))
            .foregroundColor(isActive ? .white : .gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.07))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onTap(option)
                    } label: {
                        HStack {
                            Text(displayLabel?(option) ?? option)
                                .font(.caption)
                            Spacer()
                            if selected.contains(option) {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.semibold))
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .frame(minWidth: 140)
        }
    }
}

func ratingLabel(for rating: String) -> String {
    switch rating {
    case "4 Stars": return "\u{2605}\u{2605}\u{2605}\u{2605}"
    case "3+ Stars": return "\u{2605}\u{2605}\u{2605}+"
    case "3 Stars": return "\u{2605}\u{2605}\u{2605}"
    default: return rating
    }
}
