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

struct AuctionTab: View {
    @ObservedObject var dataService: DataService
    @State private var searchText = ""
    @State private var expandedProducerId: String?
    @AppStorage("auction_sortField") private var sortField: AuctionSortField = .lots
    @AppStorage("auction_sortDirection") private var sortDirection: SortDirection = .descending

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

    var body: some View {
        VStack(spacing: 0) {
            if let data = dataService.auctionData {
                summaryBar(data: data)
                sortBar
                producerList
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
        .safeAreaInset(edge: .bottom) {
            searchBar
        }
        .task {
            if dataService.auctionData == nil {
                await dataService.loadAuction()
            }
        }
        .refreshable {
            await dataService.loadAuction()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))
            TextField("Search producers...", text: $searchText)
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

    // MARK: - Summary Bar

    private func summaryBar(data: AuctionData) -> some View {
        HStack {
            Text("\(data.summary.unique_producers) producers")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(data.summary.total_wines) lots")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(String(format: "%.0f%% sold", data.summary.sell_rate_percent))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
                                .font(.caption.monospaced())
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
