import Foundation

@MainActor
class CellarService: ObservableObject {
    @Published var entries: [CellarEntry] = []
    @Published var isProcessing = false
    @Published var error: String?

    var cellarData: CellarData? {
        let hasCellarWines = entries.contains { $0.status == .cellar && $0.count > 0 }
        return hasCellarWines ? CellarData(from: entries) : nil
    }

    var historyEntries: [CellarEntry] {
        entries.filter { $0.status == .history }
    }

    var hasHistory: Bool {
        entries.contains { $0.status == .history }
    }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cellar.json")
    }

    init() {
        loadFromFile()
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - CRUD

    func addEntry(_ entry: CellarEntry) {
        if entry.status == .history {
            insertHistoryEntry(entry)
        } else {
            entries.append(entry)
        }
        save()
    }

    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func updateEntry(_ entry: CellarEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            save()
        }
    }

    func incrementCount(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].count += 1
            if entries[index].status == .history {
                entries[index].status = .cellar
            }
            save()
        }
    }

    func decrementCount(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }), entries[index].count > 0 {
            entries[index].count -= 1
            save()
        }
    }

    func moveToHistory(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries.remove(at: index)
        entry.status = .history
        entry.count = 0
        entry.addedDate = DateFormatters.todayString
        insertHistoryEntry(entry)
        save()
    }

    private func insertHistoryEntry(_ entry: CellarEntry) {
        if let firstHistoryIdx = entries.firstIndex(where: { $0.status == .history }) {
            entries.insert(entry, at: firstHistoryIdx)
        } else {
            entries.append(entry)
        }
    }

    func moveHistoryEntries(from source: IndexSet, to destination: Int) {
        let indexed = entries.enumerated().filter { $0.element.status == .history }
        let historyIndices = indexed.map { $0.offset }
        var reordered = indexed.map { $0.element }
        reordered.move(fromOffsets: source, toOffset: destination)

        for (i, originalIndex) in historyIndices.enumerated() {
            entries[originalIndex] = reordered[i]
        }
        save()
    }

    func clearData() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Persistence (JSON in Documents)

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func loadFromFile() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([CellarEntry].self, from: data)
        } catch {
            self.error = "Failed to load cellar: \(error.localizedDescription)"
        }
    }

    // MARK: - Migration from old UserDefaults format

    private func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "cellar_migrated_v2"
        guard !defaults.bool(forKey: migrationKey) else { return }
        guard entries.isEmpty else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        struct OldCellarWine: Codable {
            let drinkYear: String
            let winery: String
            let wineName: String
            let vintage: String
            let region: String
            let style: String
            let price: String
            let count: Int
            let link: String
            let color: String
        }
        struct OldCellarData: Codable {
            let wines: [OldCellarWine]
            let yearCounts: [String: Int]
            let vintageCounts: [String: Int]
            let totalBottles: Int
            let totalValue: Int
            let colorPalette: [String: String]
            let vintagePalette: [String: String]
        }
        struct OldHistoryWine: Codable {
            let winery: String
            let wineName: String
            let vintage: String
            let region: String
            let country: String
            let style: String
            let averageRating: String
            let scanDate: String
            let location: String
            let userRating: String
            let wineType: String
            let link: String
        }

        if let data = defaults.data(forKey: "cellar_data"),
           let old = try? JSONDecoder().decode(OldCellarData.self, from: data) {
            for wine in old.wines {
                entries.append(CellarEntry(
                    status: .cellar,
                    winery: wine.winery,
                    wineName: wine.wineName,
                    vintage: wine.vintage,
                    region: wine.region,
                    style: wine.style,
                    price: wine.price,
                    count: wine.count,
                    drinkYear: wine.drinkYear,
                    links: wine.link.isEmpty ? [] : [wine.link],
                    source: .imported
                ))
            }
        }

        if let data = defaults.data(forKey: "history_data"),
           let old = try? JSONDecoder().decode([OldHistoryWine].self, from: data) {
            for wine in old {
                entries.append(CellarEntry(
                    status: .history,
                    winery: wine.winery,
                    wineName: wine.wineName,
                    vintage: wine.vintage,
                    region: wine.region,
                    country: wine.country,
                    style: wine.style,
                    wineType: wine.wineType,
                    links: wine.link.isEmpty ? [] : [wine.link],
                    userRating: wine.userRating,
                    averageRating: wine.averageRating,
                    source: .imported
                ))
            }
        }

        if !entries.isEmpty {
            save()
        }

        defaults.removeObject(forKey: "cellar_data")
        defaults.removeObject(forKey: "history_data")
        defaults.removeObject(forKey: "cellar_imported_at")
        defaults.set(true, forKey: migrationKey)
    }

    // MARK: - CSV Export

    func exportCSV() -> URL? {
        let headers = [
            "Status", "Winery", "Wine Name", "Vintage", "Region", "Country",
            "Wine Type", "Price", "Count", "Drink Year", "Links",
            "Notes", "Source", "Added Date"
        ]

        var lines: [String] = [headers.joined(separator: ",")]

        let cellarEntries = entries.filter { $0.status == .cellar }.sorted { a, b in
            let aYear = a.drinkYear.isEmpty ? a.vintage : a.drinkYear
            let bYear = b.drinkYear.isEmpty ? b.vintage : b.drinkYear
            if aYear != bYear { return aYear < bYear }
            if a.vintage != b.vintage { return a.vintage < b.vintage }
            return a.winery.localizedCaseInsensitiveCompare(b.winery) == .orderedAscending
        }
        let historyEntries = entries.filter { $0.status == .history }
        let sorted = cellarEntries + historyEntries

        for entry in sorted {
            let fields = [
                entry.status.rawValue,
                entry.winery,
                entry.wineName,
                entry.vintage,
                entry.region,
                entry.country,
                entry.wineType,
                entry.price,
                String(entry.count),
                entry.drinkYear,
                entry.links.joined(separator: " | "),
                entry.notes,
                entry.source.rawValue,
                entry.addedDate
            ].map { csvEscape($0) }
            lines.append(fields.joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vinslipp_cellar.csv")

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            self.error = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    // MARK: - CSV Import (Vinslipp format)

    func importFromURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            error = "Cannot access file"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            error = "Could not read the file"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let rows = parseCSV(text)

        guard !rows.isEmpty else {
            error = "No data found in the file"
            return
        }

        if rows[0].keys.contains("Status") && rows[0].keys.contains("Winery") {
            importVinslippCSV(rows)
        } else {
            error = "Unrecognized file format. Use a file exported from Vinslipp."
        }
    }

    func importFromURLs(_ urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            let data = try? Data(contentsOf: url)
            url.stopAccessingSecurityScopedResource()
            if let data, detectVivinoFileType(from: data) != nil {
                importVivinoFromURLs(urls)
                return
            }
        }
        guard let url = urls.first else { return }
        importFromURL(url)
    }

    private func importVinslippCSV(_ rows: [[String: String]]) {
        entries = rows.map { row in
            CellarEntry(
                status: WineStatus(rawValue: row["Status"] ?? "cellar") ?? .cellar,
                winery: row["Winery"] ?? "",
                wineName: row["Wine Name"] ?? "",
                vintage: row["Vintage"] ?? "",
                region: row["Region"] ?? "",
                country: row["Country"] ?? "",
                style: row["Style"] ?? "",
                wineType: row["Wine Type"] ?? "",
                price: row["Price"] ?? "",
                count: Int(row["Count"] ?? "1") ?? 1,
                drinkYear: row["Drink Year"] ?? "",
                links: (row["Links"] ?? row["Link"] ?? "")
                    .split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty },
                userRating: row["User Rating"] ?? "",
                averageRating: row["Average Rating"] ?? "",
                notes: row["Notes"] ?? "",
                source: WineSource(rawValue: row["Source"] ?? "imported") ?? .imported,
                addedDate: row["Added Date"] ?? DateFormatters.todayString
            )
        }
        save()
    }

    // MARK: - Vivino CSV Import

    func importVivinoFromURLs(_ urls: [URL]) {
        var cellarData: Data?
        var pricesData: Data?
        var wineListData: Data?

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }

            switch detectVivinoFileType(from: data) {
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

        guard cellarData != nil || wineListData != nil else {
            error = "No valid Vivino files found"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let cellarString = cellarData.flatMap { String(data: $0, encoding: .utf8) }
        let pricesString = pricesData.flatMap { String(data: $0, encoding: .utf8) }
        let wineListString = wineListData.flatMap { String(data: $0, encoding: .utf8) }

        let cellarRows = cellarString.map { parseCSV($0) } ?? []
        let priceRows = pricesString.map { parseCSV($0) } ?? []
        let wineListRows = wineListString.map { parseCSV($0) } ?? []

        processVivinoCellar(cellarRows: cellarRows, priceRows: priceRows, wineListRows: wineListRows)
    }

    private enum VivinoFileType {
        case cellar, prices, wineList
    }

    private func detectVivinoFileType(from data: Data) -> VivinoFileType? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let header = String(text.prefix(500)).lowercased()
        if header.contains("wine price") { return .prices }
        if header.contains("user cellar count") { return .cellar }
        if header.contains("scan date") || header.contains("drinking window") { return .wineList }
        return nil
    }

    private func processVivinoCellar(cellarRows: [[String: String]], priceRows: [[String: String]], wineListRows: [[String: String]]) {
        var noteLookup: [String: String] = [:]
        var countryLookup: [String: String] = [:]
        var wineTypeLookup: [String: String] = [:]
        for row in wineListRows {
            guard let link = row["Link to wine"], !link.isEmpty else { continue }
            if let note = row["Personal Note"], !note.isEmpty { noteLookup[link] = note }
            if let country = row["Country"], !country.isEmpty { countryLookup[link] = country }
            if let wineType = row["Wine type"], !wineType.isEmpty { wineTypeLookup[link] = wineType }
        }

        var priceLookup: [String: String] = [:]
        for row in priceRows {
            guard let link = row["Link to wine"], !link.isEmpty else { continue }
            priceLookup[link] = row["Wine price"] ?? ""
        }

        var newEntries: [CellarEntry] = []

        for row in cellarRows {
            let link = row["Link to wine"] ?? ""
            let winery = row["Winery"] ?? ""
            let wineName = row["Wine name"] ?? ""
            let vintage = row["Vintage"] ?? ""
            let region = row["Region"] ?? ""
            let style = row["Regional wine style"] ?? ""
            let country = countryLookup[link] ?? ""
            let wineType = wineTypeLookup[link] ?? ""
            let countStr = row["User cellar count"] ?? "0"
            let totalCount = Int(countStr) ?? 0

            guard totalCount > 0 else { continue }

            let priceRaw = priceLookup[link] ?? ""
            let priceNum = priceRaw.priceNumeric
            let price = priceNum > 0 ? "\(priceNum) SEK" : ""

            let note = noteLookup[link] ?? ""
            let drinkYears = note.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.range(of: #"^\d{4}$"#, options: .regularExpression) != nil }

            if drinkYears.isEmpty {
                newEntries.append(CellarEntry(
                    status: .cellar,
                    winery: winery,
                    wineName: wineName,
                    vintage: vintage,
                    region: region,
                    country: country,
                    style: style,
                    wineType: wineType,
                    price: price,
                    count: totalCount,
                    links: link.isEmpty ? [] : [link],
                    source: .imported
                ))
            } else {
                let base = totalCount / drinkYears.count
                let remainder = totalCount % drinkYears.count
                for (idx, yearStr) in drinkYears.enumerated() {
                    let count = base + (idx < remainder ? 1 : 0)
                    guard count > 0 else { continue }
                    newEntries.append(CellarEntry(
                        status: .cellar,
                        winery: winery,
                        wineName: wineName,
                        vintage: vintage,
                        region: region,
                        country: country,
                        style: style,
                        wineType: wineType,
                        price: price,
                        count: count,
                        drinkYear: yearStr,
                        links: link.isEmpty ? [] : [link],
                        source: .imported
                    ))
                }
            }
        }

        // Process history from wine list
        let cellarLinks = Set(newEntries.compactMap { $0.links.first })
        for row in wineListRows {
            let link = row["Link to wine"] ?? ""
            let cellarCount = Int(row["User cellar count"] ?? "0") ?? 0
            if cellarCount > 0 { continue }
            if !link.isEmpty && cellarLinks.contains(link) { continue }

            newEntries.append(CellarEntry(
                status: .history,
                winery: row["Winery"] ?? "",
                wineName: row["Wine name"] ?? "",
                vintage: row["Vintage"] ?? "",
                region: row["Region"] ?? "",
                country: row["Country"] ?? "",
                style: row["Regional wine style"] ?? "",
                wineType: row["Wine type"] ?? "",
                links: link.isEmpty ? [] : [link],
                userRating: row["Your rating"] ?? "",
                averageRating: row["Average rating"] ?? "",
                source: .imported
            ))
        }

        entries = newEntries
        save()
    }

    // MARK: - CSV Parser (RFC 4180)

    private func parseCSV(_ text: String) -> [[String: String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    field.append(c)
                    i += 1
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                    i += 1
                } else if c == "," {
                    current.append(field)
                    field = ""
                    i += 1
                } else if c == "\r" || c == "\n" {
                    if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                    current.append(field)
                    field = ""
                    if !current.allSatisfy({ $0.isEmpty }) {
                        rows.append(current)
                    }
                    current = []
                    i += 1
                } else {
                    field.append(c)
                    i += 1
                }
            }
        }
        current.append(field)
        if !current.allSatisfy({ $0.isEmpty }) {
            rows.append(current)
        }

        guard let headers = rows.first else { return [] }
        return rows.dropFirst().map { row in
            var dict: [String: String] = [:]
            for (idx, header) in headers.enumerated() {
                dict[header] = idx < row.count ? row[idx] : ""
            }
            return dict
        }
    }
}
