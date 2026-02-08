"use client";

import { useState, useEffect, useMemo } from "react";
import type { AuctionData } from "@/types";
import { SortableTable, type Column } from "@/components/SortableTable";

interface AuctionRow {
  name: string;
  total_lots: number;
  sold: number;
  sell_rate: number;
  avg_estimate_sek: number;
  avg_hammer_sek: number;
  avg_ratio: number | null;
  premium_percent: number | null;
  vintages: number[];
}

interface Props {
  search: string;
}

export function AuctionTab({ search }: Props) {
  const [data, setData] = useState<AuctionData | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    fetch("data/auction_stats.json")
      .then((r) => r.json())
      .then((d) => setData(d))
      .catch(() => setError(true));
  }, []);

  const rows: AuctionRow[] = useMemo(() => {
    if (!data) return [];
    return Object.entries(data.producers)
      .map(([name, d]) => ({ name, ...d }))
      .sort((a, b) => b.total_lots - a.total_lots);
  }, [data]);

  const filtered = useMemo(() => {
    if (!search) return rows;
    const q = search.toLowerCase();
    return rows.filter((r) => r.name.toLowerCase().includes(q));
  }, [rows, search]);

  const columns: Column<AuctionRow>[] = useMemo(
    () => [
      { label: "Producer", accessor: (r) => r.name },
      { label: "Lots", accessor: (r) => String(r.total_lots), hiddenOnMobile: true },
      { label: "Sold", accessor: (r) => String(r.sold) },
      {
        label: "Sell %",
        accessor: (r) => `${r.sell_rate}%`,
        hiddenOnMobile: true,
      },
      {
        label: "Avg. Estimate",
        accessor: (r) => `${r.avg_estimate_sek.toLocaleString()} SEK`,
        hiddenOnMobile: true,
      },
      {
        label: "Avg Hammer",
        accessor: (r) => `${r.avg_hammer_sek.toLocaleString()} SEK`,
      },
      {
        label: "Ratio",
        accessor: (r) =>
          r.avg_ratio !== null ? r.avg_ratio.toFixed(3) : "\u2014",
        hiddenOnMobile: true,
        render: (r) => {
          const cls =
            r.avg_ratio === null
              ? ""
              : r.avg_ratio >= 1
                ? "positive"
                : "negative";
          return (
            <span className={cls}>
              {r.avg_ratio !== null ? r.avg_ratio.toFixed(3) : "\u2014"}
            </span>
          );
        },
      },
      {
        label: "Prem. %",
        accessor: (r) =>
          r.premium_percent !== null ? `${r.premium_percent}%` : "\u2014",
        render: (r) => {
          const cls =
            r.premium_percent === null
              ? ""
              : r.premium_percent >= 0
                ? "positive"
                : "negative";
          const val =
            r.premium_percent !== null
              ? `${r.premium_percent >= 0 ? "+" : ""}${r.premium_percent}%`
              : "\u2014";
          return <span className={cls}>{val}</span>;
        },
      },
      {
        label: "Vintages",
        accessor: (r) => r.vintages.join(", "),
        hiddenOnMobile: true,
      },
    ],
    []
  );

  if (error) {
    return (
      <p style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
        Failed to load auction data.
      </p>
    );
  }

  if (!data) {
    return (
      <p style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
        Loading auction data...
      </p>
    );
  }

  return (
    <div className="tab-scroll">
      <SortableTable
        columns={columns}
        data={filtered}
        tableId="auctionProducerTable"
      />
    </div>
  );
}
