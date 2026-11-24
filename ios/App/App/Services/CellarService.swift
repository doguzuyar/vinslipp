import Foundation
import UIKit
import FirebaseFirestore
import FirebaseAuth

enum CloudCellarError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to back up your cellar"
        }
    }
}

enum CloudSyncStatus: Equatable {
    case offline
    case syncing
    case synced(Date)
    case error(String)
}

@MainActor
class CellarService: ObservableObject {
    @Published var entries: [CellarEntry] = []
    @Published var isProcessing = false
    @Published var error: String?
    @Published var syncStatus: CloudSyncStatus = .offline

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var pendingPushTask: Task<Void, Never>?
    private var suppressAutoPush = false
    private var pushesPaused = false

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
        setupAuthListener()
        // The upload waits a second for more edits; don't let closing the app drop it.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.flushPendingPush() }
        }
    }

    private func flushPendingPush() {
        guard pendingPushTask != nil else { return }
        pendingPushTask?.cancel()
        pendingPushTask = nil
        Task { await runPush() }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    // MARK: - CRUD

    func addEntry(_ entry: CellarEntry) {
        let entry = Self.consistent(entry, was: entry.status)
        noteChange(entry.id)
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

    /// Same rules as moveToHistory and incrementCount: history holds no bottles, a wine moved
    /// back to the cellar has at least one, and a cellar wine with none is history (the cellar
    /// list hides empty wines, so it would vanish from both lists).
    private static func consistent(_ entry: CellarEntry, was oldStatus: WineStatus) -> CellarEntry {
        var entry = entry
        if entry.status == .history {
            entry.count = 0
        } else if entry.count == 0 {
            if oldStatus == .history { entry.count = 1 } else { entry.status = .history }
        }
        return entry
    }

    func updateEntry(_ entry: CellarEntry) {
        noteChange(entry.id)
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = Self.consistent(entry, was: entries[index].status)
            save()
        }
    }

    func incrementCount(id: UUID) {
        noteChange(id)
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].count += 1
            if entries[index].status == .history {
                entries[index].status = .cellar
            }
            save()
        }
    }

    func decrementCount(id: UUID) {
        noteChange(id)
        if let index = entries.firstIndex(where: { $0.id == id }), entries[index].count > 0 {
            entries[index].count -= 1
            save()
        }
    }

    func moveToHistory(id: UUID) {
        noteChange(id)
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

    /// Stores a hand-picked order for a group of cellar wines: each id gets its
    /// position in `ids` as its manualOrder.
    func setCellarOrder(_ ids: [UUID]) {
        for (position, id) in ids.enumerated() {
            guard let index = entries.firstIndex(where: { $0.id == id }) else { continue }
            entries[index].manualOrder = position
        }
        save()
    }

    func clearData() {
        entries = []
        save()
    }

    /// Stops uploads so none can recreate cellar/{uid} while the account is being deleted.
    func cancelPendingPush() {
        pendingPushTask?.cancel()
        pendingPushTask = nil
        pushesPaused = true
    }

    /// Account deletion failed or was abandoned: uploads may run again.
    func resumePushes() {
        pushesPaused = false
    }

    /// After account deletion the local cellar stays on the device but no longer belongs to any
    /// account, so the next sign-in treats it as fresh device data instead of another user's.
    func forgetCloudAccount() {
        UserDefaults.standard.removeObject(forKey: Self.lastSyncedUidKey)
        pushesPaused = false
        syncStatus = .offline
    }

    // MARK: - Persistence (JSON in Documents)

    private func save() {
        saveLocal()
        if !suppressAutoPush {
            schedulePush()
        }
    }

    private func saveLocal() {
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
            // The next save would overwrite the unreadable file, so keep a copy first.
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("cellar-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            self.error = "Failed to load cellar: \(error.localizedDescription). A copy was kept as \(backup.lastPathComponent)."
        }
    }

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
            "Notes", "Source", "Added Date",
            "Style", "User Rating", "Average Rating", "Manual Order"
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
                entry.addedDate,
                entry.style,
                entry.userRating,
                entry.averageRating,
                entry.manualOrder.map(String.init) ?? ""
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
        guard !rows.isEmpty else {
            error = "No wines found in the file. Nothing was changed."
            return
        }
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
                addedDate: row["Added Date"] ?? DateFormatters.todayString,
                manualOrder: Int(row["Manual Order"] ?? "")
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

        // An unreadable export yields no rows; never let that replace the cellar.
        guard !newEntries.isEmpty else {
            error = "No wines found in the Vivino files. Nothing was changed."
            return
        }
        entries = newEntries
        save()
    }

    // MARK: - Cloud Sync (Firestore, automatic)

    private func userCellarDocRef() throws -> DocumentReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw CloudCellarError.notSignedIn
        }
        return Firestore.firestore()
            .collection("cellar")
            .document(uid)
    }

    private func setupAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if user != nil {
                    await self.syncOnSignIn()
                } else {
                    self.pendingPushTask?.cancel()
                    self.pendingPushTask = nil
                    self.syncStatus = .offline
                }
            }
        }
    }

    private static let lastSyncedUidKey = "cellar_last_synced_uid"
    private static let signedOutChangesKey = "cellar_signed_out_changes"

    /// Remembers a wine added or edited while signed out, so the next sign-in keeps it.
    private func noteChange(_ id: UUID) {
        guard Auth.auth().currentUser == nil else { return }
        var ids = UserDefaults.standard.stringArray(forKey: Self.signedOutChangesKey) ?? []
        if !ids.contains(id.uuidString) { ids.append(id.uuidString) }
        UserDefaults.standard.set(ids, forKey: Self.signedOutChangesKey)
    }

    private func syncOnSignIn() async {
        syncStatus = .syncing
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                syncStatus = .offline
                return
            }
            let cloud = try await fetchCloudEntries()
            let previousUid = UserDefaults.standard.string(forKey: Self.lastSyncedUidKey)
            let isFirstSyncOnDevice = previousUid == nil

            // nil means this account has never backed up; an existing but empty
            // cellar is a deliberate Clear All and must not be refilled from this device.
            guard let cloud else {
                if !entries.isEmpty && (isFirstSyncOnDevice || previousUid == uid) {
                    try await pushAll()
                } else {
                    suppressAutoPush = true
                    entries = []
                    saveLocal()
                    suppressAutoPush = false
                }
                UserDefaults.standard.set(uid, forKey: Self.lastSyncedUidKey)
                syncStatus = .synced(Date())
                return
            }
            let changedWhileSignedOut = Set(UserDefaults.standard.stringArray(forKey: Self.signedOutChangesKey) ?? [])
            if isFirstSyncOnDevice && !entries.isEmpty {
                // First sign-in on this device with both local and cloud data:
                // union by id so wines added while signed-out aren't lost.
                // Cloud wins on id conflicts.
                let cloudIds = Set(cloud.map(\.id))
                let merged = cloud + entries.filter { !cloudIds.contains($0.id) }
                suppressAutoPush = true
                entries = merged
                saveLocal()
                suppressAutoPush = false
                if merged.count != cloud.count {
                    try await pushAll()
                }
            } else if previousUid == uid && !changedWhileSignedOut.isEmpty {
                // Same account again: the cloud is the truth, except for wines added or
                // edited here while signed out, which win and are uploaded.
                let local = entries.filter { changedWhileSignedOut.contains($0.id.uuidString) }
                let localIds = Set(local.map(\.id))
                suppressAutoPush = true
                entries = cloud.filter { !localIds.contains($0.id) } + local
                saveLocal()
                suppressAutoPush = false
                try await pushAll()
            } else {
                // Subsequent sign-in (or account switch): cloud is the truth
                // so deletions made on other devices propagate, and a previous
                // account's local cellar is never uploaded into a different account.
                suppressAutoPush = true
                entries = cloud
                saveLocal()
                suppressAutoPush = false
            }

            UserDefaults.standard.removeObject(forKey: Self.signedOutChangesKey)
            UserDefaults.standard.set(uid, forKey: Self.lastSyncedUidKey)
            syncStatus = .synced(Date())
        } catch CloudCellarError.notSignedIn {
            syncStatus = .offline
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func schedulePush() {
        guard Auth.auth().currentUser != nil else { return }
        pendingPushTask?.cancel()
        pendingPushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.runPush()
        }
    }

    private func runPush() async {
        guard Auth.auth().currentUser != nil else { return }
        syncStatus = .syncing
        do {
            try await pushAll()
            syncStatus = .synced(Date())
        } catch CloudCellarError.notSignedIn {
            syncStatus = .offline
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func pushAll() async throws {
        guard !pushesPaused else { return }
        let ref = try userCellarDocRef()
        let payload: [String: Any] = [
            "entries": entries.map { encodeForCloud($0) },
            "updatedAt": FieldValue.serverTimestamp(),
            "schemaVersion": 1
        ]
        try await ref.setData(payload)
    }

    private func fetchCloudEntries() async throws -> [CellarEntry]? {
        let ref = try userCellarDocRef()
        let snapshot = try await ref.getDocument()
        guard let data = snapshot.data(),
              let arr = data["entries"] as? [[String: Any]] else { return nil }
        return arr.compactMap { decodeFromCloud(dict: $0) }
    }

    private func encodeForCloud(_ entry: CellarEntry) -> [String: Any] {
        var dict: [String: Any] = [
            "id": entry.id.uuidString,
            "status": entry.status.rawValue,
            "winery": entry.winery,
            "wineName": entry.wineName,
            "vintage": entry.vintage,
            "region": entry.region,
            "country": entry.country,
            "style": entry.style,
            "wineType": entry.wineType,
            "price": entry.price,
            "count": entry.count,
            "drinkYear": entry.drinkYear,
            "links": entry.links,
            "userRating": entry.userRating,
            "averageRating": entry.averageRating,
            "notes": entry.notes,
            "source": entry.source.rawValue,
            "addedDate": entry.addedDate
        ]
        if let manualOrder = entry.manualOrder {
            dict["manualOrder"] = manualOrder
        }
        return dict
    }

    private func decodeFromCloud(dict d: [String: Any]) -> CellarEntry? {
        guard let idStr = d["id"] as? String, let id = UUID(uuidString: idStr) else { return nil }
        return CellarEntry(
            id: id,
            status: WineStatus(rawValue: d["status"] as? String ?? "cellar") ?? .cellar,
            winery: d["winery"] as? String ?? "",
            wineName: d["wineName"] as? String ?? "",
            vintage: d["vintage"] as? String ?? "",
            region: d["region"] as? String ?? "",
            country: d["country"] as? String ?? "",
            style: d["style"] as? String ?? "",
            wineType: d["wineType"] as? String ?? "",
            price: d["price"] as? String ?? "",
            count: d["count"] as? Int ?? 1,
            drinkYear: d["drinkYear"] as? String ?? "",
            links: d["links"] as? [String] ?? [],
            userRating: d["userRating"] as? String ?? "",
            averageRating: d["averageRating"] as? String ?? "",
            notes: d["notes"] as? String ?? "",
            source: WineSource(rawValue: d["source"] as? String ?? "imported") ?? .imported,
            addedDate: d["addedDate"] as? String ?? DateFormatters.todayString,
            manualOrder: d["manualOrder"] as? Int
        )
    }

    // MARK: - CSV Parser (RFC 4180)

    private func parseCSV(_ text: String) -> [[String: String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        // Excel saves with a byte-order mark, which would hide the first header name.
        let chars = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
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
                } else if c.isNewline {
                    // Swift reads "\r\n" as one Character, so compare with isNewline, not "\n".
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
