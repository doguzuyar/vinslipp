import SwiftUI

enum SortField: String, CaseIterable {
    case date, producer, wine, vintage, region, price, rating
}

enum SortDirection {
    case ascending, descending
}

struct ReleaseTab: View {
    @ObservedObject var dataService: DataService
    @State private var expandedWineId: String?
    @State private var sortField: SortField = .date
    @State private var sortDirection: SortDirection = .ascending
    @State private var selectedDate: String?
    @State private var selectedCountries: Set<String> = []
    @State private var selectedTypes: Set<String> = []
    @State private var selectedRatings: Set<Int> = []
    @State private var todayOnly = false
    @State private var showPastReleases = false
    @State private var showFilters = false
    @State private var searchText = ""

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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let data = dataService.releaseData {
                    MiniCalendar(
                        dateColors: data.dateColors,
                        selectedDate: $selectedDate
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

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
            .navigationTitle("Releases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Releases")
                            .font(.headline)
                        if let meta = dataService.metadata {
                            Text("Updated \(meta.releaseUpdated)")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(upcomingWines.count) wines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            if dataService.releaseData == nil {
                await dataService.loadReleases()
            }
        }
        .refreshable {
            await dataService.loadReleases()
        }
        .searchable(text: $searchText, prompt: "Search wines...")
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "Today", isActive: todayOnly) {
                    todayOnly.toggle()
                }

                Menu {
                    ForEach(availableCountries, id: \.self) { country in
                        Button {
                            toggleFilter(country, in: &selectedCountries)
                        } label: {
                            HStack {
                                Text(country)
                                if selectedCountries.contains(country) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if !selectedCountries.isEmpty {
                        Divider()
                        Button("Clear") { selectedCountries.removeAll() }
                    }
                } label: {
                    FilterChipLabel(
                        label: "Country",
                        count: selectedCountries.count
                    )
                }

                Menu {
                    ForEach(availableTypes, id: \.self) { type in
                        Button {
                            toggleFilter(type, in: &selectedTypes)
                        } label: {
                            HStack {
                                Text(type)
                                if selectedTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if !selectedTypes.isEmpty {
                        Divider()
                        Button("Clear") { selectedTypes.removeAll() }
                    }
                } label: {
                    FilterChipLabel(
                        label: "Type",
                        count: selectedTypes.count
                    )
                }

                Menu {
                    ForEach([4, 3, 2], id: \.self) { rating in
                        Button {
                            toggleFilter(rating, in: &selectedRatings)
                        } label: {
                            HStack {
                                Text(String(repeating: "\u{2605}", count: rating))
                                if selectedRatings.contains(rating) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if !selectedRatings.isEmpty {
                        Divider()
                        Button("Clear") { selectedRatings.removeAll() }
                    }
                } label: {
                    FilterChipLabel(
                        label: "Rating",
                        count: selectedRatings.count
                    )
                }

                if hasActiveFilters {
                    Button {
                        clearAllFilters()
                    } label: {
                        Text("Clear all")
                            .font(.caption2)
                            .foregroundStyle(.red)
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
                        ForEach(sorted(pastWines)) { wine in
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
    }

    // MARK: - Filtering & Sorting

    private var hasActiveFilters: Bool {
        todayOnly || !selectedCountries.isEmpty || !selectedTypes.isEmpty || !selectedRatings.isEmpty || selectedDate != nil
    }

    private var availableCountries: [String] {
        let countries = Set(allWines.map(\.countryEnglish)).sorted()
        return countries
    }

    private var availableTypes: [String] {
        let types = Set(allWines.map(\.wineTypeEnglish)).sorted()
        return types
    }

    private func filtered(_ wines: [ReleaseWine]) -> [ReleaseWine] {
        var result = wines

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.producer.lowercased().contains(query) ||
                $0.wineName.lowercased().contains(query) ||
                $0.region.lowercased().contains(query)
            }
        }

        if todayOnly {
            result = result.filter { $0.launchDate == todayString }
        }

        if let date = selectedDate {
            result = result.filter { $0.launchDate == date }
        }

        if !selectedCountries.isEmpty {
            result = result.filter { selectedCountries.contains($0.countryEnglish) }
        }

        if !selectedTypes.isEmpty {
            result = result.filter { selectedTypes.contains($0.wineTypeEnglish) }
        }

        if !selectedRatings.isEmpty {
            result = result.filter {
                guard let score = $0.ratingScore else { return false }
                return selectedRatings.contains(score)
            }
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

    private func toggleFilter<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    private func clearAllFilters() {
        todayOnly = false
        selectedCountries.removeAll()
        selectedTypes.removeAll()
        selectedRatings.removeAll()
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
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
            if count > 0 {
                Text("(\(count))")
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(count > 0 ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
        .foregroundStyle(count > 0 ? .primary : .secondary)
        .clipShape(Capsule())
    }
}
