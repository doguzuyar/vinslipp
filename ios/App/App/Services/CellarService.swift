import Foundation
import SwiftUI

@MainActor
class CellarService: ObservableObject {
    @Published var cellarData: CellarData?
    @Published var historyData: [HistoryWine]?
    @Published var isProcessing = false
    @Published var error: String?
    @Published var importedAt: String?

    private let storageKey = "cellar_data"
    private let historyKey = "history_data"
    private let metaKey = "cellar_imported_at"

    init() {
        loadFromStorage()
    }

    // MARK: - Import

    func importFiles(cellarCSV: Data?, wineListCSV: Data? = nil, pricesCSV: Data?) {
        isProcessing = true
        error = nil

        let mainCSV = cellarCSV ?? wineListCSV
        guard let mainData = mainCSV,
              let cellarString = String(data: mainData, encoding: .utf8) else {
            error = "Could not read CSV file"
            isProcessing = false
            return
        }

        let pricesString = pricesCSV.flatMap { String(data: $0, encoding: .utf8) }

        let cellarRows = parseCSV(cellarString)
        let priceRows = pricesString.map { parseCSV($0) } ?? []

        var wineListRows: [[String: String]] = []
        if let wineListData = wineListCSV,
           let wineListString = String(data: wineListData, encoding: .utf8) {
            wineListRows = parseCSV(wineListString)
        }

        let data = processCellar(cellarRows: cellarRows, priceRows: priceRows, wineListRows: wineListRows)
        cellarData = data

        if !wineListRows.isEmpty {
            historyData = processHistory(rows: wineListRows)
        }

        importedAt = DateFormatters.shortTimestamp.string(from: Date())

        saveToStorage()
        isProcessing = false
    }

    func importFromURLs(_ urls: [URL]) {
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
            importFiles(
                cellarCSV: cellarData,
                wineListCSV: wineListData,
                pricesCSV: pricesData
            )
        }
    }

    func clearData() {
        cellarData = nil
        historyData = nil
        importedAt = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: metaKey)
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

    // MARK: - Process Vivino Data

    private func processCellar(cellarRows: [[String: String]], priceRows: [[String: String]], wineListRows: [[String: String]] = []) -> CellarData {
        var noteLookup: [String: String] = [:]
        for row in wineListRows {
            guard let link = row["Link to wine"], !link.isEmpty else { continue }
            let note = row["Personal Note"] ?? ""
            if !note.isEmpty { noteLookup[link] = note }
        }

        var priceLookup: [String: String] = [:]
        for row in priceRows {
            guard let link = row["Link to wine"], !link.isEmpty else { continue }
            priceLookup[link] = row["Wine price"] ?? ""
        }

        var wines: [CellarWine] = []
        var yearCounts: [String: Int] = [:]
        var vintageCounts: [String: Int] = [:]
        var totalBottles = 0
        var totalValue = 0
        var allYears: Set<Int> = []

        for row in cellarRows {
            let link = row["Link to wine"] ?? ""
            let winery = row["Winery"] ?? ""
            let wineName = row["Wine name"] ?? ""
            let vintage = row["Vintage"] ?? ""
            let region = row["Region"] ?? ""
            let style = row["Regional wine style"] ?? ""
            let countStr = row["User cellar count"] ?? "0"
            let totalCount = Int(countStr) ?? 0

            guard totalCount > 0 else { continue }

            let priceRaw = priceLookup[link] ?? ""
            let price = formatPrice(priceRaw)
            let priceNum = priceRaw.priceNumeric

            let note = noteLookup[link] ?? ""
            let drinkYears = note.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.range(of: #"^\d{4}$"#, options: .regularExpression) != nil }

            if drinkYears.isEmpty {
                let year = vintage.isEmpty ? "-" : vintage
                let yearInt = Int(year)
                let color = yearInt.map { AppColors.color(forYear: $0) } ?? "#888888"
                if let yearInt { allYears.insert(yearInt) }
                wines.append(CellarWine(
                    drinkYear: year, winery: winery, wineName: wineName,
                    vintage: vintage, region: region, style: style,
                    price: price, count: totalCount, link: link,
                    color: color
                ))
                yearCounts[year, default: 0] += totalCount
            } else {
                let base = totalCount / drinkYears.count
                let remainder = totalCount % drinkYears.count

                for (idx, yearStr) in drinkYears.enumerated() {
                    let count = base + (idx < remainder ? 1 : 0)
                    guard count > 0 else { continue }
                    let yearInt = Int(yearStr) ?? 2026
                    allYears.insert(yearInt)
                    let color = AppColors.color(forYear: yearInt)

                    wines.append(CellarWine(
                        drinkYear: yearStr, winery: winery, wineName: wineName,
                        vintage: vintage, region: region, style: style,
                        price: price, count: count, link: link,
                        color: color
                    ))
                    yearCounts[yearStr, default: 0] += count
                }
            }

            let vintageKey = vintage.isEmpty ? "-" : vintage
            vintageCounts[vintageKey, default: 0] += totalCount

            totalBottles += totalCount
            totalValue += priceNum * totalCount
        }

        wines.sort {
            if $0.drinkYear != $1.drinkYear { return $0.drinkYear < $1.drinkYear }
            if $0.vintage != $1.vintage { return $0.vintage < $1.vintage }
            return $0.winery < $1.winery
        }

        let palette = AppColors.buildPalette(years: Array(allYears))
        let vintageYears = vintageCounts.keys.compactMap { Int($0) }
        let vPalette = AppColors.buildPalette(years: vintageYears)

        return CellarData(
            wines: wines,
            yearCounts: yearCounts,
            vintageCounts: vintageCounts,
            totalBottles: totalBottles,
            totalValue: totalValue,
            colorPalette: palette,
            vintagePalette: vPalette
        )
    }

    private func processHistory(rows: [[String: String]]) -> [HistoryWine] {
        rows.map { row in
            HistoryWine(
                winery: row["Winery"] ?? "",
                wineName: row["Wine name"] ?? "",
                vintage: row["Vintage"] ?? "",
                region: row["Region"] ?? "",
                country: row["Country"] ?? "",
                style: row["Regional wine style"] ?? "",
                averageRating: row["Average rating"] ?? "",
                scanDate: row["Scan date"] ?? "",
                location: row["Scan/Review Location"] ?? "",
                userRating: row["Your rating"] ?? "",
                wineType: row["Wine type"] ?? "",
                link: row["Link to wine"] ?? ""
            )
        }
    }

    private func formatPrice(_ raw: String) -> String {
        let num = raw.priceNumeric
        return num > 0 ? "\(num) SEK" : ""
    }

    // MARK: - Persistence

    private func saveToStorage() {
        if let cellar = cellarData,
           let encoded = try? JSONEncoder().encode(cellar) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        if let history = historyData,
           let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
        UserDefaults.standard.set(importedAt, forKey: metaKey)
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(CellarData.self, from: data) {
            cellarData = decoded
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HistoryWine].self, from: data) {
            historyData = decoded
        }
        importedAt = UserDefaults.standard.string(forKey: metaKey)
    }
}
