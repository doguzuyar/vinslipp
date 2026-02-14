import SwiftUI

enum SortField: String, CaseIterable {
    case date, producer, wine, vintage, region, price, rating
}

enum SortDirection: String {
    case ascending, descending
}

struct ReleaseTab: View {
    @ObservedObject var dataService: DataService
    @State private var expandedWineId: String?
    @AppStorage("release_sortField") private var sortField: SortField = .date
    @AppStorage("release_sortDirection") private var sortDirection: SortDirection = .ascending
    @State private var selectedDate: String?
    @AppStorage("release_selectedCountries") private var selectedCountriesData: Data = Data()
    @AppStorage("release_selectedTypes") private var selectedTypesData: Data = Data()
    @AppStorage("release_selectedRating") private var selectedRating = ""
    @AppStorage("release_todayOnly") private var todayOnly = false
    @State private var showPastReleases = false
    @State private var showFilters = false
    @AppStorage("release_searchText") private var searchText = ""

    private var selectedCountries: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: selectedCountriesData)) ?? [] }
        nonmutating set { selectedCountriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private var selectedTypes: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: selectedTypesData)) ?? [] }
        nonmutating set { selectedTypesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var allWines: [ReleaseWine] {
        dataService.releaseData?.wines ?? []
    }

    private var upcomingWines: [ReleaseWine] {
        filtered(allWines.filter { $0.launchDate >= todayString })
    }

    private var pastWines: [ReleaseWine] {
        filtered(allWines.filter { $0.launchDate < todayString })
    }

    /// Filtered wines excluding the date filter — used for calendar dot counts
    private var filteredDateCounts: [String: Int] {
        let wines = filteredExcludingDate(allWines)
        var counts: [String: Int] = [:]
        for w in wines {
            counts[w.launchDate, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        VStack(spacing: 0) {
            if let data = dataService.releaseData {
                MiniCalendar(
                    dateColors: data.dateColors,
                    filteredDateCounts: filteredDateCounts,
                    selectedDate: $selectedDate
                )
                .padding(.horizontal, 12)
                .offset(y: -15)

                filterBar

                sortBar

                wineList
            } else if dataService.isLoading {
                Spacer()
                ProgressView("Loading wines...")
                Spacer()
            } else if let error = dataService.error {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await dataService.loadReleases() }
                    }
                }
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if dataService.releaseData != nil {
                searchBar
            }
        }
        .task {
            if dataService.releaseData == nil {
                await dataService.loadReleases()
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            todayOnly = newValue == todayString
        }
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "Today", isActive: todayOnly) {
                    todayOnly.toggle()
                    if todayOnly {
                        selectedDate = todayString
                    } else {
                        selectedDate = nil
                    }
                }

                Menu {
                    ForEach(countryFilters, id: \.self) { country in
                        Button {
                            toggleCountry(country)
                        } label: {
                            HStack {
                                Text(country)
                                if selectedCountries.contains(country) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChipLabel(
                        label: "Country",
                        isActive: !selectedCountries.isEmpty
                    )
                }

                Menu {
                    ForEach(typeFilters, id: \.self) { type in
                        Button {
                            toggleType(type)
                        } label: {
                            HStack {
                                Text(type)
                                if selectedTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChipLabel(
                        label: "Type",
                        isActive: !selectedTypes.isEmpty
                    )
                }

                Menu {
                    ForEach(["3 Stars", "3+ Stars", "4 Stars"], id: \.self) { rating in
                        Button {
                            selectedRating = selectedRating == rating ? "" : rating
                        } label: {
                            HStack {
                                Text(ratingLabel(for: rating))
                                if selectedRating == rating {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChipLabel(
                        label: "Rating",
                        isActive: !selectedRating.isEmpty
                    )
                }

                if hasActiveFilters {
                    Button {
                        clearAllFilters()
                    } label: {
                        Image(systemName: "eraser")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Wine List

    private var wineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sorted(upcomingWines)) { wine in
                    WineRow(wine: wine, isExpanded: expandedWineId == wine.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedWineId = expandedWineId == wine.id ? nil : wine.id
                            }
                        }
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
                        .background(Color(.systemGray6).opacity(0.5))
                    }

                    if showPastReleases {
                        ForEach(pastWines.sorted { $0.launchDate > $1.launchDate }) { wine in
                            WineRow(wine: wine, isExpanded: expandedWineId == wine.id)
                                .opacity(0.6)
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
        }
        .contentMargins(.bottom, 16)
        .refreshable {
            await dataService.loadReleases()
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

    private let knownTypes = ["Red", "White", "Sparkling", "Rosé"]

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

    private func ratingLabel(for rating: String) -> String {
        switch rating {
        case "4 Stars": return "★★★★"
        case "3+ Stars": return "★★★+"
        case "3 Stars": return "★★★"
        default: return rating
        }
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
                .background(isActive ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                .foregroundStyle(isActive ? .primary : .secondary)
                .clipShape(Capsule())
        }
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
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
        .foregroundStyle(isActive ? .primary : .secondary)
        .clipShape(Capsule())
    }
}

