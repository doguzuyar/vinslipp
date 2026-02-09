"use client";

import { useState, useMemo } from "react";
import type { ReleaseData, ReleaseWine } from "@/types";
import { SortableTable, type Column } from "@/components/SortableTable";
import { RatingStars } from "./RatingStars";

interface Props {
  data: ReleaseData;
  activeRating: number;
  ratingMinMode: boolean;
  todayOnly: boolean;
  matchCountry: ((country: string) => boolean) | null;
  matchType: ((wineType: string) => boolean) | null;
  hasRatings: boolean;
}

export function ReleaseTab({
  data,
  activeRating,
  ratingMinMode,
  todayOnly,
  matchCountry,
  matchType,
  hasRatings,
}: Props) {
  const [pastVisible, setPastVisible] = useState(false);

  const today = useMemo(() => new Date().toISOString().slice(0, 10), []);

  const filteredWines = useMemo(() => {
    let wines = data.wines;

    // Filter by country
    if (matchCountry) {
      wines = wines.filter((w) => matchCountry(w.country));
    }

    // Filter by type
    if (matchType) {
      wines = wines.filter((w) => matchType(w.wineType));
    }

    // Filter today only
    if (todayOnly) {
      wines = wines.filter((w) => w.launchDate === today);
    } else if (!pastVisible) {
      wines = wines.filter((w) => w.launchDate >= today);
    }

    // Filter by rating
    if (activeRating > 0) {
      wines = wines.filter((w) => {
        const score = w.ratingScore || 0;
        return ratingMinMode ? score >= activeRating : score === activeRating;
      });
    }

    return wines;
  }, [data.wines, pastVisible, todayOnly, activeRating, ratingMinMode, today, matchCountry, matchType]);

  const isFiltered = activeRating > 0 || todayOnly || !!matchCountry || !!matchType;

  const pastCount = useMemo(
    () => data.wines.filter((w) => w.launchDate < today).length,
    [data.wines, today]
  );

  const columns: Column<ReleaseWine>[] = useMemo(
    () => [
      {
        label: "Date",
        accessor: (w) => w.launchDateFormatted,
        render: (w) => (
          <a href={w.vivinoLink} target="_blank" rel="noreferrer">
            {w.launchDateFormatted}
          </a>
        ),
      },
      {
        label: "Winery",
        accessor: (w) => w.producer,
        render: (w) => (
          <a href={w.vivinoLink} target="_blank" rel="noreferrer">
            {w.producer}
          </a>
        ),
      },
      {
        label: "Wine name",
        accessor: (w) => w.wineName,
        render: (w) => (
          <a href={w.vivinoLink} target="_blank" rel="noreferrer">
            {w.wineName}
          </a>
        ),
      },
      {
        label: "Vintage",
        accessor: (w) => w.vintage,
        render: (w) => (
          <a href={w.vivinoLink} target="_blank" rel="noreferrer">
            {w.vintage}
          </a>
        ),
      },
      {
        label: "Region",
        accessor: (w) => w.region,
        hiddenOnMobile: true,
        render: (w) => (
          <a href={w.sbLink} target="_blank">
            {w.region}
          </a>
        ),
      },
      {
        label: "Price",
        accessor: (w) => w.price,
        render: (w) => (
          <a href={w.sbLink} target="_blank">
            {w.price}
          </a>
        ),
      },
      ...(hasRatings
        ? [
            {
              label: "AI",
              accessor: (w: ReleaseWine) =>
                w.ratingScore ? "\u2605".repeat(w.ratingScore) : "...",
              render: (w: ReleaseWine) =>
                w.ratingScore ? (
                  <RatingStars score={w.ratingScore} reason={w.ratingReason} />
                ) : (
                  <span style={{ color: "var(--text-muted)", fontStyle: "italic" }}>
                    ...
                  </span>
                ),
            },
          ]
        : []),
    ],
    [hasRatings]
  );

  return (
    <div className="tab-scroll">
      <SortableTable
        columns={columns}
        data={filteredWines}
        tableId="release-table"
        renderRow={(wine, idx, cells) => (
          <tr
            key={idx}
            className="clickable"
            style={{ backgroundColor: wine.rowColor }}
          >
            {cells}
          </tr>
        )}
      />
      <p style={{ fontWeight: 500, marginTop: 16, fontSize: 14, color: "var(--text-muted)" }}>
        {isFiltered ? `${filteredWines.length} of ${data.totalCount}` : data.totalCount} wines &middot;{" "}
        <span
          style={{
            cursor: "pointer",
            color: "var(--text-muted)",
            fontWeight: 400,
            fontSize: 13,
            transition: "color 0.15s ease",
          }}
          onClick={() => setPastVisible((v) => !v)}
        >
          {pastVisible ? "\u25BC" : "\u25B6"}{" "}
          {pastVisible ? "Hide past releases" : "Show past releases"}{" "}
          ({pastCount})
        </span>
      </p>
    </div>
  );
}
