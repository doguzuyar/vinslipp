"use client";

import { useMemo } from "react";
import type { HistoryWine } from "@/types";
import { SortableTable, type Column } from "@/components/SortableTable";

interface Props {
  wines: HistoryWine[];
  selectedLocation: string;
}

export function HistoryTab({ wines, selectedLocation }: Props) {
  const columns: Column<HistoryWine>[] = useMemo(
    () => [
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
        render: (w) => (
          <a href={w.link} target="_blank" rel="noreferrer">
            {w.style}
          </a>
        ),
      },
    ],
    []
  );

  return (
    <div className="tab-scroll">
      <SortableTable
        columns={columns}
        data={wines}
        tableId="history-table"
        renderRow={(wine, idx, cells) => (
          <tr
            key={idx}
            className="clickable"
            style={{ backgroundColor: "var(--bg-alt)" }}
          >
            {cells}
          </tr>
        )}
      />
      <p style={{ fontWeight: 500, marginTop: 16, fontSize: 14, color: "var(--text-muted)" }}>
        {wines.length} wines{selectedLocation ? ` consumed at ${selectedLocation}` : ""}
      </p>
    </div>
  );
}
