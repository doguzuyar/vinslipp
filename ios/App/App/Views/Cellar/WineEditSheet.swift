import SwiftUI

struct WineEditSheet: View {
    @State var entry: CellarEntry
    let isNew: Bool
    let onSave: (CellarEntry) -> Void
    let onDuplicate: ((CellarEntry) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataService: DataService
    @EnvironmentObject private var cellarService: CellarService

    @State private var priceAmount: String
    @State private var priceCurrency: String
    @FocusState private var focusedField: Field?
    @State private var enabled: Set<Field> = []

    enum Field: Hashable { case winery, wineName, region, country, wineType }

    static let currencies = ["SEK", "USD", "EUR"]

    private var suggestionIndex: WineSuggestionIndex {
        WineSuggestionIndex(
            releases: dataService.releaseData?.wines ?? [],
            cellar: cellarService.entries
        )
    }

    private func isActive(_ field: Field) -> Bool {
        focusedField == field && enabled.contains(field)
    }

    private var winerySuggestions: [WineSuggestion] {
        isActive(.winery) ? suggestionIndex.match(entry.winery, field: .winery) : []
    }

    private var wineNameSuggestions: [WineSuggestion] {
        isActive(.wineName) ? suggestionIndex.match(entry.wineName, field: .wineName) : []
    }

    private var regionSuggestions: [String] {
        isActive(.region) ? suggestionIndex.matchDistinct(entry.region, field: .region) : []
    }

    private var countrySuggestions: [String] {
        isActive(.country) ? suggestionIndex.matchDistinct(entry.country, field: .country) : []
    }

    private var wineTypeSuggestions: [String] {
        isActive(.wineType) ? suggestionIndex.matchDistinct(entry.wineType, field: .wineType) : []
    }

    private func apply(_ suggestion: WineSuggestion) {
        entry.winery = suggestion.winery
        entry.wineName = suggestion.wineName
        if entry.vintage.isEmpty { entry.vintage = suggestion.vintage }
        if !suggestion.region.isEmpty { entry.region = suggestion.region }
        if !suggestion.country.isEmpty { entry.country = suggestion.country }
        if !suggestion.wineType.isEmpty { entry.wineType = suggestion.wineType }
        enabled.remove(.winery)
        enabled.remove(.wineName)
    }

    private func applyValue(_ field: Field, _ keyPath: WritableKeyPath<CellarEntry, String>, _ value: String) {
        entry[keyPath: keyPath] = value
        enabled.remove(field)
    }

    private func typing(_ field: Field, _ keyPath: WritableKeyPath<CellarEntry, String>) -> Binding<String> {
        Binding(
            get: { entry[keyPath: keyPath] },
            set: {
                entry[keyPath: keyPath] = $0
                enabled.insert(field)
            }
        )
    }

    private var cleanedEntry: CellarEntry {
        var cleaned = entry
        cleaned.price = priceAmount.isEmpty ? "" : "\(priceAmount) \(priceCurrency)"
        cleaned.links = cleaned.links.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return cleaned
    }

    init(
        entry: CellarEntry,
        isNew: Bool,
        onDuplicate: ((CellarEntry) -> Void)? = nil,
        onSave: @escaping (CellarEntry) -> Void
    ) {
        self._entry = State(initialValue: entry)
        self.isNew = isNew
        self.onDuplicate = onDuplicate
        self.onSave = onSave
        let (amount, currency) = Self.parsePrice(entry.price)
        self._priceAmount = State(initialValue: amount)
        self._priceCurrency = State(initialValue: currency)
    }

    private static func parsePrice(_ price: String) -> (String, String) {
        let trimmed = price.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter { $0.isNumber }
        let upper = trimmed.uppercased()
        for cur in currencies where upper.contains(cur) {
            return (digits, cur)
        }
        return (digits, "SEK")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Wine") {
                    TextField("Winery", text: typing(.winery, \.winery))
                        .focused($focusedField, equals: .winery)
                    ForEach(winerySuggestions) { suggestion in
                        Button { apply(suggestion) } label: {
                            suggestionRow(suggestion)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Wine Name", text: typing(.wineName, \.wineName))
                        .focused($focusedField, equals: .wineName)
                    ForEach(wineNameSuggestions) { suggestion in
                        Button { apply(suggestion) } label: {
                            suggestionRow(suggestion)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Vintage", text: $entry.vintage)
                        .keyboardType(.numberPad)
                }

                Section("Origin") {
                    TextField("Region", text: typing(.region, \.region))
                        .focused($focusedField, equals: .region)
                    ForEach(regionSuggestions, id: \.self) { value in
                        Button { applyValue(.region, \.region, value) } label: {
                            stringSuggestionRow(value)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Country", text: typing(.country, \.country))
                        .focused($focusedField, equals: .country)
                    ForEach(countrySuggestions, id: \.self) { value in
                        Button { applyValue(.country, \.country, value) } label: {
                            stringSuggestionRow(value)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Wine Type", text: typing(.wineType, \.wineType))
                        .focused($focusedField, equals: .wineType)
                    ForEach(wineTypeSuggestions, id: \.self) { value in
                        Button { applyValue(.wineType, \.wineType, value) } label: {
                            stringSuggestionRow(value)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Cellar") {
                    Picker("Status", selection: $entry.status) {
                        ForEach(WineStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Bottles")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            if entry.count > 0 { entry.count -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                        }
                        .disabled(entry.count <= 0)
                        Text("\(entry.count)")
                            .font(.body.weight(.semibold).monospacedDigit())
                            .frame(minWidth: 30)
                        Button {
                            entry.count += 1
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                        }
                    }

                    HStack {
                        TextField("Price", text: $priceAmount)
                            .keyboardType(.numberPad)
                        Picker("", selection: $priceCurrency) {
                            ForEach(Self.currencies, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    TextField("Drink Year", text: $entry.drinkYear)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Tasting notes, storage location...", text: $entry.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if entry.links.isEmpty {
                        Text("No links added")
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(entry.links.indices, id: \.self) { index in
                        HStack {
                            TextField("URL", text: $entry.links[index])
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button {
                                entry.links.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        entry.links.append("")
                    } label: {
                        Label("Add Link", systemImage: "plus")
                            .font(.subheadline)
                    }
                } header: {
                    Text("Links")
                }

                if !isNew {
                    Section {
                        HStack {
                            Text("Source")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.source.rawValue.capitalized)
                                .foregroundStyle(.tertiary)
                        }
                        HStack {
                            Text("Added")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.addedDate)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if !isNew, let onDuplicate {
                    Section {
                        Button {
                            onDuplicate(cleanedEntry)
                            dismiss()
                        } label: {
                            Label("Duplicate Wine", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Wine" : "Edit Wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(cleanedEntry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(entry.winery.isEmpty && entry.wineName.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func stringSuggestionRow(_ s: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(s)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
    }

    @ViewBuilder
    private func suggestionRow(_ s: WineSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(s.winery)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(s.wineName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !s.vintage.isEmpty {
                    Text(s.vintage)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                if !s.region.isEmpty {
                    Text(s.region)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.leading, 8)
    }
}
