export interface CellarWine {
  drinkYear: string;
  winery: string;
  wineName: string;
  vintage: string;
  region: string;
  style: string;
  price: string;
  count: number;
  link: string;
  color: string;
}

export interface CellarData {
  wines: CellarWine[];
  yearCounts: Record<string, number>;
  totalBottles: number;
  totalValue: number;
  colorPalette: Record<string, string>;
}

export interface ReleaseWine {
  launchDate: string;
  launchDateFormatted: string;
  producer: string;
  wineName: string;
  vintage: string;
  price: string;
  region: string;
  country: string;
  wineType: string;
  productNumber: string;
  vivinoLink: string;
  sbLink: string;
  ratingScore: number | null;
  ratingReason: string;
  rowColor: string;
}

export interface ReleaseData {
  wines: ReleaseWine[];
  dateColors: Record<string, string>;
  totalCount: number;
}

export interface HistoryWine {
  scanDate: string;
  winery: string;
  wineName: string;
  vintage: string;
  region: string;
  style: string;
  link: string;
  scanLocation: string;
}

export interface HistoryData {
  wines: HistoryWine[];
  locations: string[];
  totalCount: number;
}

export interface Metadata {
  releaseUpdated: string;
  auctionUpdated: string;
  generatedAt: string;
}

export interface AuctionProducer {
  name: string;
  total_lots: number;
  sold: number;
  unsold: number;
  sell_rate: number;
  avg_estimate_sek: number;
  avg_hammer_sek: number;
  avg_ratio: number | null;
  premium_percent: number | null;
  vintages: number[];
}

export interface AuctionData {
  producers: Record<string, Omit<AuctionProducer, "name">>;
  summary: {
    total_producers: number;
    total_lots: number;
  };
}
