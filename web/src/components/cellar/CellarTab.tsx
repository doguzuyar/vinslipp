"use client";

import { useState, useMemo, useCallback } from "react";
import type { CellarData, CellarWine } from "@/types";
import { SortableTable, type Column } from "@/components/SortableTable";
import { BottleChart } from "./BottleChart";

interface Props {
  data: CellarData;
}

export function CellarTab({ data }: Props) {
  const [activeYear, setActiveYear] = useState<string | null>(null);

  const filteredWines = useMemo(() => {
    if (!activeYear) return data.wines;
    return data.wines.filter((w) => w.drinkYear === activeYear);
  }, [data.wines, activeYear]);

  const handleYearClick = useCallback((year: string) => {
    setActiveYear((prev) => (prev === year ? null : year));
  }, []);

  const columns: Column<CellarWine>[] = useMemo(
    () => [
      {
        label: "Drink",
        accessor: (w) => w.drinkYear,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.drinkYear}
          </a>
        ),
      },
      {
        label: "Winery",
        accessor: (w) => w.winery,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.winery}
          </a>
        ),
      },
      {
        label: "Wine name",
        accessor: (w) => w.wineName,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.wineName}
          </a>
        ),
      },
      {
        label: "Vintage",
        accessor: (w) => w.vintage,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.vintage}
          </a>
        ),
      },
      {
        label: "Region",
        accessor: (w) => w.region,
        hiddenOnMobile: true,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.region}
          </a>
        ),
      },
      {
        label: "Style",
        accessor: (w) => w.style,
        hiddenOnMobile: true,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.style}
          </a>
        ),
      },
      {
        label: "Price",
        accessor: (w) => w.price,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.price}
          </a>
        ),
      },
      {
        label: "Count",
        accessor: (w) => String(w.count),
        hiddenOnMobile: true,
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.count}
          </a>
        ),
      },
    ],
    []
  );

  const totalValueFormatted = data.totalValue
    .toLocaleString("sv-SE")
    .replace(/\u00a0/g, " ");

  return (
    <div className="tab-scroll">
      <SortableTable
        columns={columns}
        data={filteredWines}
        tableId="cellar-table"
        renderRow={(wine, idx, cells) => (
          <tr
            key={idx}
            className="clickable"
            style={{ backgroundColor: wine.color }}
          >
            {cells}
          </tr>
        )}
      />

      <h2 style={{ marginTop: 32, fontSize: 16, fontWeight: 600, color: "var(--text)" }}>Bottles per Year</h2>
      <BottleChart
        yearCounts={data.yearCounts}
        colorPalette={data.colorPalette}
        activeYear={activeYear}
        onYearClick={handleYearClick}
      />
      <p style={{ fontWeight: 500, marginTop: 16, fontSize: 14, color: "var(--text-muted)" }}>
        {data.totalBottles} bottles &middot; {totalValueFormatted} SEK
      </p>
    </div>
  );
}
