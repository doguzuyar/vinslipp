"use client";

import { useState, useMemo, useCallback } from "react";
import type { CellarData, CellarWine } from "@/types";
import { SortableTable, type Column } from "@/components/SortableTable";
import { useRowPopup, RowPopup } from "@/components/RowPopup";
import { BottleChart } from "./BottleChart";

interface Props {
  data: CellarData;
}

export function CellarTab({ data }: Props) {
  const [activeYear, setActiveYear] = useState<string | null>(null);
  const { expandedId, popupPos, popupRef, scrollRef, handleRowClick } = useRowPopup();

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
        label: "Notes",
        accessor: (w) => w.drinkYear,
      },
      {
        label: "Winery",
        accessor: (w) => w.winery,
      },
      {
        label: "Wine name",
        accessor: (w) => w.wineName,
      },
      {
        label: "Vintage",
        accessor: (w) => w.vintage,
      },
      {
        label: "Region",
        accessor: (w) => w.region,
        hiddenOnMobile: true,
      },
      {
        label: "Style",
        accessor: (w) => w.style,
        hiddenOnMobile: true,
      },
      {
        label: "Price",
        accessor: (w) => w.price,
      },
      {
        label: "Count",
        accessor: (w) => String(w.count),
        hiddenOnMobile: true,
      },
    ],
    []
  );

  const expandedWineData = expandedId ? filteredWines.find((w) => w.link === expandedId) : null;

  const totalValueFormatted = data.totalValue
    .toLocaleString("sv-SE")
    .replace(/\u00a0/g, " ");

  const hasYearData = useMemo(() => {
    return Object.keys(data.yearCounts).some((key) => /^\d{4}$/.test(key));
  }, [data.yearCounts]);

  return (
    <div className="tab-scroll" ref={scrollRef} style={{ position: "relative" }}>
      <SortableTable
        columns={columns}
        data={filteredWines}
        tableId="cellar-table"
        renderRow={(wine, idx, cells) => (
          <tr
            key={idx}
            className="clickable"
            style={{ backgroundColor: wine.color }}
            onClick={(e) => handleRowClick(wine.link, e)}
          >
            {cells}
          </tr>
        )}
      />
      {expandedWineData && popupPos && (
        <RowPopup
          popupRef={popupRef}
          popupPos={popupPos}
          links={[
            { label: "Vivino", href: expandedWineData.link },
            { label: "Blog" },
          ]}
        />
      )}

      {hasYearData && (
        <>
          <h2 style={{ marginTop: 32, fontSize: 16, fontWeight: 600, color: "var(--text)" }}>Bottles per Year</h2>
          <BottleChart
            yearCounts={data.yearCounts}
            colorPalette={data.colorPalette}
            activeYear={activeYear}
            onYearClick={handleYearClick}
          />
        </>
      )}
      <p style={{ fontWeight: 500, marginTop: 16, fontSize: 14, color: "var(--text-muted)" }}>
        {data.totalBottles} bottles{data.totalValue > 0 ? ` \u00b7 ${totalValueFormatted} SEK` : ""}
      </p>
    </div>
  );
}
