import SwiftUI

enum AuctionSortField: String, CaseIterable {
    case producer, lots, sold, sellRate, estimate, hammer, ratio, premium

    var label: String {
        switch self {
        case .producer: return "Producer"
        case .lots: return "Lots"
        case .sold: return "Sold"
        case .sellRate: return "Sell %"
        case .estimate: return "Est."
        case .hammer: return "Hammer"
        case .ratio: return "Ratio"
        case .premium: return "Prem."
        }
    }
}

enum LiveSortField: String, CaseIterable {
    case title, category, estimate, rating

    var label: String {
        switch self {
        case .title: return "Title"
        case .category: return "Category"
        case .estimate: return "Est."
        case .rating: return "Rating"
        }
    }
}

struct AuctionTab: View {
    @ObservedObject var dataService: DataService
    @AppStorage("auction_searchText") private var searchText = ""
    @State private var expandedProducerId: String?
    @AppStorage("auction_sortField") private var sortField: AuctionSortField = .lots
    @AppStorage("auction_sortDirection") private var sortDirection: SortDirection = .descending
    @AppStorage("auction_showLive") private var showLive = false
    @AppStorage("live_sortField") private var liveSortField: LiveSortField = .rating
    @AppStorage("live_sortDirection") private var liveSortDirection: SortDirection = .descending
    @AppStorage("live_selectedCountriesData") private var liveSelectedCountriesData: Data = {
        (try? JSONEncoder().encode(Set(["France"]))) ?? Data()
    }()
    @AppStorage("live_selectedTypesData") private var liveSelectedTypesData: Data = {
        (try? JSONEncoder().encode(Set(["Bordeaux", "Burgundy"]))) ?? Data()
    }()
    @AppStorage("live_selectedRating") private var liveSelectedRating = ""
    @AppStorage("auction_selectedCountriesData") private var auctionSelectedCountriesData: Data = {
        (try? JSONEncoder().encode(Set(["France"]))) ?? Data()
    }()

    private var liveSelectedCountries: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: liveSelectedCountriesData)) ?? [] }
        nonmutating set { liveSelectedCountriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private var liveSelectedTypes: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: liveSelectedTypesData)) ?? [] }
        nonmutating set { liveSelectedTypesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private var auctionSelectedCountries: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: auctionSelectedCountriesData)) ?? [] }
        nonmutating set { auctionSelectedCountriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private var auctionCountryFilters: [String] { ["France"] }
    private var liveCountryFilters: [String] { ["France"] }
    private var liveTypeFilters: [String] { ["Bordeaux", "Burgundy"] }

    private var hasActiveLiveFilters: Bool {
        !liveSelectedCountries.isEmpty || !liveSelectedTypes.isEmpty || !liveSelectedRating.isEmpty
    }

    private var producers: [AuctionProducer] {
        guard let data = dataService.auctionData else { return [] }
        return data.producers.map { AuctionProducer(name: $0.key, data: $0.value) }
    }

    private var filtered: [AuctionProducer] {
        let list = searchText.isEmpty ? producers : producers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return sorted(list)
    }

    private var filteredLiveWines: [LiveWine] {
        guard let data = dataService.liveWinesData else { return [] }
        var result = data.wines

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.title.lowercased().contains(query) }
        }

        if !liveSelectedTypes.isEmpty {
            result = result.filter {
                liveSelectedTypes.contains($0.category.capitalized)
            }
        }

        if !liveSelectedRating.isEmpty {
            result = result.filter {
                switch liveSelectedRating {
                case "4 Stars": return $0.rating_score == 4
                case "3+ Stars": return $0.rating_score >= 3
                case "3 Stars": return $0.rating_score == 3
                default: return true
                }
            }
        }

        return sortedLive(result)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showLive {
                liveContent
            } else {
                aggregateContent
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showLive ? dataService.liveWinesData != nil : dataService.auctionData != nil {
                searchBar
            }
        }
        .task {
            if dataService.auctionData == nil {
                await dataService.loadAuction()
            }
            if showLive && dataService.liveWinesData == nil {
                await dataService.loadLiveWines()
            }
        }
    }

    // MARK: - Aggregate Content

    @ViewBuilder
    private var aggregateContent: some View {
        if let data = dataService.auctionData {
            summaryBar(data: data)

            VStack(spacing: 0) {
                filterBar
                sortBar
                producerList
            }
            .padding(.top, -15)
        } else if dataService.isLoadingAuction {
            Spacer()
            ProgressView("Loading auction data...")
            Spacer()
        } else if let error = dataService.auctionError {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await dataService.loadAuction() }
                }
            }
            Spacer()
        }
    }

    // MARK: - Live Content

    @ViewBuilder
    private var liveContent: some View {
        if let data = dataService.liveWinesData {
            liveHeader(data: data)

            VStack(spacing: 0) {
                filterBar
                liveSortBar
                liveList
            }
            .padding(.top, -15)
        } else if dataService.isLoadingLiveWines {
            Spacer()
            ProgressView("Loading live wines...")
            Spacer()
        } else if let error = dataService.liveWinesError {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await dataService.loadLiveWines() }
                }
            }
            Spacer()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        SearchBar(
            text: $searchText,
            placeholder: showLive ? "Search wines..." : "Search producers..."
        )
    }

    // MARK: - Summary Bar

    private func summaryBar(data: AuctionData) -> some View {
        HStack {
            Text("\(data.summary.unique_producers) producers")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(data.summary.total_wines) lots")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .offset(y: -40)
    }

    private func liveHeader(data: LiveWinesData) -> some View {
        HStack {
            Text("\(data.bordeaux_count) Bx \u{00B7} \(data.burgundy_count) Burg")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(data.total_wines) lots")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .offset(y: -40)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "Live", isActive: showLive) {
                    showLive.toggle()
                    if showLive && dataService.liveWinesData == nil {
                        Task { await dataService.loadLiveWines() }
                    }
                }

                if showLive {
                    Menu {
                        ForEach(liveCountryFilters, id: \.self) { country in
                            Button {
                                toggleLiveCountry(country)
                            } label: {
                                HStack {
                                    Text(country)
                                    if liveSelectedCountries.contains(country) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        FilterChipLabel(
                            label: "Country",
                            isActive: !liveSelectedCountries.isEmpty
                        )
                    }

                    Menu {
                        ForEach(liveTypeFilters, id: \.self) { type in
                            Button {
                                toggleLiveType(type)
                            } label: {
                                HStack {
                                    Text(type)
                                    if liveSelectedTypes.contains(type) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        FilterChipLabel(
                            label: "Type",
                            isActive: !liveSelectedTypes.isEmpty
                        )
                    }

                    Menu {
                        ForEach(["3 Stars", "3+ Stars", "4 Stars"], id: \.self) { rating in
                            Button {
                                liveSelectedRating = liveSelectedRating == rating ? "" : rating
                            } label: {
                                HStack {
                                    Text(ratingLabel(for: rating))
                                    if liveSelectedRating == rating {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        FilterChipLabel(
                            label: "Rating",
                            isActive: !liveSelectedRating.isEmpty
                        )
                    }

                    if hasActiveLiveFilters {
                        Button {
                            clearLiveFilters()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Menu {
                        ForEach(auctionCountryFilters, id: \.self) { country in
                            Button {
                                toggleAuctionCountry(country)
                            } label: {
                                HStack {
                                    Text(country)
                                    if auctionSelectedCountries.contains(country) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        FilterChipLabel(
                            label: "Country",
                            isActive: !auctionSelectedCountries.isEmpty
                        )
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
                ForEach(AuctionSortField.allCases, id: \.self) { field in
                    Button {
                        if sortField == field {
                            sortDirection = sortDirection == .ascending ? .descending : .ascending
                        } else {
                            sortField = field
                            sortDirection = field == .producer ? .ascending : .descending
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

    private var liveSortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(LiveSortField.allCases, id: \.self) { field in
                    Button {
                        if liveSortField == field {
                            liveSortDirection = liveSortDirection == .ascending ? .descending : .ascending
                        } else {
                            liveSortField = field
                            liveSortDirection = field == .title ? .ascending : .descending
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(field.label)
                                .font(.system(size: 10, weight: liveSortField == field ? .bold : .regular))
                            if liveSortField == field {
                                Image(systemName: liveSortDirection == .ascending ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundStyle(liveSortField == field ? .primary : .tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Producer List

    private var producerList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { producer in
                    ProducerRow(producer: producer, isExpanded: expandedProducerId == producer.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedProducerId = expandedProducerId == producer.id ? nil : producer.id
                            }
                        }
                    Divider().padding(.leading, 28)
                }
            }
        }
        .contentMargins(.bottom, 16)
        .refreshable {
            await dataService.loadAuction()
        }
    }

    // MARK: - Live List

    private var liveList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredLiveWines) { wine in
                    LiveWineRow(wine: wine)
                    Divider().padding(.leading, 28)
                }
            }
        }
        .contentMargins(.bottom, 16)
        .refreshable {
            await dataService.loadLiveWines()
        }
    }

    // MARK: - Sorting

    private func sorted(_ list: [AuctionProducer]) -> [AuctionProducer] {
        list.sorted { a, b in
            let result: Bool
            switch sortField {
            case .producer:
                result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .lots:
                result = a.totalLots < b.totalLots
            case .sold:
                result = a.sold < b.sold
            case .sellRate:
                result = a.sellRate < b.sellRate
            case .estimate:
                result = a.avgEstimateSek < b.avgEstimateSek
            case .hammer:
                result = a.avgHammerSek < b.avgHammerSek
            case .ratio:
                result = (a.avgRatio ?? 0) < (b.avgRatio ?? 0)
            case .premium:
                result = (a.premiumPercent ?? -999) < (b.premiumPercent ?? -999)
            }
            return sortDirection == .ascending ? result : !result
        }
    }

    private func toggleAuctionCountry(_ value: String) {
        var s = auctionSelectedCountries
        if s.contains(value) { s.remove(value) } else { s.insert(value) }
        auctionSelectedCountries = s
    }

    private func toggleLiveCountry(_ value: String) {
        var s = liveSelectedCountries
        if s.contains(value) { s.remove(value) } else { s.insert(value) }
        liveSelectedCountries = s
    }

    private func toggleLiveType(_ value: String) {
        var s = liveSelectedTypes
        if s.contains(value) { s.remove(value) } else { s.insert(value) }
        liveSelectedTypes = s
    }

    private func clearLiveFilters() {
        liveSelectedCountries = []
        liveSelectedTypes = []
        liveSelectedRating = ""
    }

    private func sortedLive(_ list: [LiveWine]) -> [LiveWine] {
        list.sorted { a, b in
            let result: Bool
            switch liveSortField {
            case .title:
                result = a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .category:
                result = a.category < b.category
            case .estimate:
                result = a.estimateNumeric < b.estimateNumeric
            case .rating:
                result = a.rating_score < b.rating_score
            }
            return liveSortDirection == .ascending ? result : !result
        }
    }
}

// MARK: - Producer Row

struct ProducerRow: View {
    let producer: AuctionProducer
    let isExpanded: Bool

    private var barColor: Color {
        guard let ratio = producer.avgRatio else { return .gray }
        return ratio >= 1 ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(producer.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        if let ratio = producer.avgRatio {
                            Text(String(format: "%.3f", ratio))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(ratio >= 1 ? .green : .red)
                        }
                    }
                    HStack {
                        Text("\(producer.totalLots) lots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(producer.avgHammerSek.formatted()) SEK")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text("\(producer.sold)/\(producer.totalLots) sold")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.0f%%", producer.sellRate))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        if let prem = producer.premiumPercent {
                            Text("\(prem >= 0 ? "+" : "")\(String(format: "%.1f", prem))%")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(prem >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if isExpanded {
                ProducerDetail(producer: producer)
            }
        }
        .background(
            isExpanded ? barColor.opacity(0.15) : Color.clear
        )
    }
}

// MARK: - Producer Detail

struct ProducerDetail: View {
    let producer: AuctionProducer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 16) {
                DetailChip(label: "Sold", value: "\(producer.sold)/\(producer.totalLots)")
                DetailChip(label: "Sell Rate", value: String(format: "%.0f%%", producer.sellRate))
                DetailChip(label: "Avg Est.", value: "\(producer.avgEstimateSek.formatted()) SEK")
                DetailChip(label: "Avg Hammer", value: "\(producer.avgHammerSek.formatted()) SEK")
            }

            if !producer.vintages.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vintages")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Text(producer.vintages.sorted().map(String.init).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
    }
}

// MARK: - Live Wine Row

struct LiveWineRow: View {
    let wine: LiveWine
    @State private var safariURL: URL?

    private var barColor: Color { .vinslippBurgundy }

    private var starsText: String {
        String(repeating: "\u{2605}", count: wine.rating_score)
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(wine.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(starsText)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                HStack {
                    Text(wine.category.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(wine.estimate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(wine.rating_reason)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Spacer()
                    if let age = wine.age {
                        Text("\(age) years")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            safariURL = URL(string: wine.url)
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}
