import { parseCSV } from "./csv";
import type { CellarData, CellarWine, HistoryData, HistoryWine } from "@/types";

const COLOR_PALETTE = [
  "#f3abab", "#f8bbd0", "#d4a3dc", "#e1bee7", "#7ec4f8",
  "#bbdefb", "#6bc4ba", "#b2dfdb", "#96d098", "#c8e6c9",
  "#ffe066", "#fff9c4", "#ffc570", "#ffe0b2", "#f8a0bc",
];

function getYearColor(year: string): string {
  const num = parseInt(year, 10);
  if (isNaN(num)) return "#ffffff";
  const index = ((num - 2026) % COLOR_PALETTE.length + COLOR_PALETTE.length) % COLOR_PALETTE.length;
  return COLOR_PALETTE[index];
}

/**
 * Process cellar.csv (required) + user_prices.csv (optional) into CellarData.
 */
export function processCellar(
  cellarCsv: string,
  userPricesCsv: string | null,
): CellarData {
  const cellarRows = parseCSV(cellarCsv);
  if (cellarRows.length === 0) {
    throw new Error("cellar.csv appears empty (no data rows)");
  }

  // Build price lookup from user_prices.csv (keyed by "Link to wine")
  const priceLookup = new Map<string, { price: string; drinkYear: string }>();
  if (userPricesCsv) {
    for (const row of parseCSV(userPricesCsv)) {
      const link = row["Link to wine"] ?? "";
      if (link) {
        const rawPrice = (row["Wine price"] ?? "").replace("SEK ", "");
        priceLookup.set(link, {
          price: rawPrice ? `${rawPrice} SEK` : "",
          drinkYear: (row["Personal Note"] ?? "").trim(),
        });
      }
    }
  }

  // Merge and distribute bottles across drink years
  const wines: CellarWine[] = [];

  for (const wine of cellarRows) {
    const link = wine["Link to wine"] ?? "";
    const priceData = priceLookup.get(link) ?? { price: "", drinkYear: "" };
    const totalCount = parseInt(wine["User cellar count"] ?? "1", 10) || 1;

    const years = priceData.drinkYear
      ? priceData.drinkYear.split(",").map((y) => y.trim()).filter(Boolean)
      : [""];

    const base = Math.floor(totalCount / years.length);
    const remainder = totalCount % years.length;

    for (let i = 0; i < years.length; i++) {
      const count = base + (i < remainder ? 1 : 0);
      if (count <= 0) continue;
      wines.push({
        drinkYear: years[i],
        winery: wine["Winery"] ?? "",
        wineName: wine["Wine name"] ?? "",
        vintage: wine["Vintage"] ?? "",
        region: wine["Region"] ?? "",
        style: wine["Regional wine style"] ?? "",
        price: priceData.price,
        count,
        link,
        color: getYearColor(years[i]),
      });
    }
  }

  // Sort: drink year ASC, vintage ASC, winery ASC
  wines.sort((a, b) => {
    const ya = a.drinkYear ? parseInt(a.drinkYear, 10) : 9999;
    const yb = b.drinkYear ? parseInt(b.drinkYear, 10) : 9999;
    if (ya !== yb) return ya - yb;
    const va = a.vintage ? parseInt(a.vintage, 10) : 9999;
    const vb = b.vintage ? parseInt(b.vintage, 10) : 9999;
    if (va !== vb) return va - vb;
    return a.winery.toLowerCase().localeCompare(b.winery.toLowerCase());
  });

  // Aggregate
  const yearCounts: Record<string, number> = {};
  let totalBottles = 0;
  let totalValue = 0;

  for (const w of wines) {
    const key = w.drinkYear || "—";
    yearCounts[key] = (yearCounts[key] ?? 0) + w.count;
    totalBottles += w.count;
    const priceNum = parseInt(w.price.replace(" SEK", ""), 10);
    if (!isNaN(priceNum)) totalValue += priceNum * w.count;
  }

  // Build color palette for all years present
  const colorPalette: Record<string, string> = {};
  for (const year of Object.keys(yearCounts)) {
    colorPalette[year] = getYearColor(year);
  }

  return { wines, yearCounts, totalBottles, totalValue, colorPalette };
}

/**
 * Process full_wine_list.csv into HistoryData with all wines.
 */
export function processHistory(fullWineListCsv: string): HistoryData {
  const rows = parseCSV(fullWineListCsv);
  if (rows.length === 0) {
    throw new Error("full_wine_list.csv appears empty (no data rows)");
  }

  const wines: HistoryWine[] = rows.map((row) => ({
    scanDate: row["Scan date"] ?? "",
    winery: row["Winery"] ?? "",
    wineName: row["Wine name"] ?? "",
    vintage: row["Vintage"] ?? "",
    region: row["Region"] ?? "",
    style: row["Regional wine style"] ?? "",
    link: row["Link to wine"] ?? "",
    scanLocation: row["Scan/Review Location"] ?? "",
  }));

  // Sort by scan date, most recent first
  wines.sort((a, b) => (b.scanDate || "").localeCompare(a.scanDate || ""));

  // Extract unique locations
  const locationSet = new Set<string>();
  for (const w of wines) {
    if (w.scanLocation) locationSet.add(w.scanLocation);
  }
  const locations = [...locationSet].sort();

  return { wines, locations, totalCount: wines.length };
}
