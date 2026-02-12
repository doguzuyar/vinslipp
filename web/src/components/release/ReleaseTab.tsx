"use client";

import { useState, useMemo, useEffect } from "react";
import type { ReleaseData, ReleaseWine } from "@/types";
import type { AuthUser } from "@/lib/firebase";
import { SortableTable, type Column } from "@/components/SortableTable";
import { useRowPopup, RowPopup } from "@/components/RowPopup";
import { BlogModal, type BlogWine } from "@/components/blog/BlogModal";
import { RatingStars } from "./RatingStars";
import { MiniCalendar } from "./MiniCalendar";

interface Props {
  data: ReleaseData;
  activeRating: number;
  ratingMinMode: boolean;
  todayOnly: boolean;
  matchCountry: ((country: string) => boolean) | null;
  matchType: ((wineType: string) => boolean) | null;
  hasRatings: boolean;
  setTodayOnly: (v: boolean) => void;
  user: AuthUser | null;
}

export function ReleaseTab({
  data,
  activeRating,
  ratingMinMode,
  todayOnly,
  matchCountry,
  matchType,
  hasRatings,
  setTodayOnly,
  user,
}: Props) {
  const [pastVisible, setPastVisible] = useState(false);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [blogWine, setBlogWine] = useState<BlogWine | null>(null);
  const { expandedId, popupPos, popupRef, scrollRef, handleRowClick } = useRowPopup();

  const today = useMemo(() => new Date().toISOString().slice(0, 10), []);

  // Clear calendar selection when Today's is toggled on
  useEffect(() => {
    if (todayOnly) setSelectedDate(null);
  }, [todayOnly]);

  const handleSelectDate = (date: string | null) => {
    if (date === today) {
      setSelectedDate(null);
      setTodayOnly(!todayOnly);
    } else {
      setTodayOnly(false);
      setSelectedDate(date);
    }
  };

  const filteredWines = useMemo(() => {
    let wines = data.wines;

    if (matchCountry) {
      wines = wines.filter((w) => matchCountry(w.country));
    }

    if (matchType) {
      wines = wines.filter((w) => matchType(w.wineType));
    }

    if (selectedDate) {
      wines = wines.filter((w) => w.launchDate === selectedDate);
    } else if (todayOnly) {
      wines = wines.filter((w) => w.launchDate === today);
    } else if (!pastVisible) {
      wines = wines.filter((w) => w.launchDate >= today);
    }

    if (activeRating > 0) {
      wines = wines.filter((w) => {
        const score = w.ratingScore || 0;
        return ratingMinMode ? score >= activeRating : score === activeRating;
      });
    }

    return wines;
  }, [data.wines, pastVisible, todayOnly, activeRating, ratingMinMode, today, matchCountry, matchType, selectedDate]);

  const isFiltered = activeRating > 0 || todayOnly || !!matchCountry || !!matchType || !!selectedDate;

  const pastCount = useMemo(
    () => data.wines.filter((w) => w.launchDate < today).length,
    [data.wines, today]
  );

  const columns: Column<ReleaseWine>[] = useMemo(
    () => [
      {
        label: "Date",
        accessor: (w) => w.launchDateFormatted,
      },
      {
        label: "Winery",
        accessor: (w) => w.producer,
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
        label: "Price",
        accessor: (w) => w.price,
      },
      ...(hasRatings
        ? [
            {
              label: "AI",
              accessor: (w: ReleaseWine) =>
                w.ratingScore ? "\u2605".repeat(w.ratingScore) : "...",
              render: (w: ReleaseWine) =>
                w.ratingScore ? (
                  <RatingStars score={w.ratingScore} />
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

  const expandedWineData = expandedId ? filteredWines.find((w) => w.productNumber === expandedId) : null;

  const { filteredDateColors, filteredDateCounts } = useMemo(() => {
    const counts: Record<string, number> = {};
    const hasFilter = !!matchCountry || !!matchType || activeRating > 0;
    for (const w of data.wines) {
      if (hasFilter) {
        if (matchCountry && !matchCountry(w.country)) continue;
        if (matchType && !matchType(w.wineType)) continue;
        if (activeRating > 0) {
          const score = w.ratingScore || 0;
          if (ratingMinMode ? score < activeRating : score !== activeRating) continue;
        }
      }
      counts[w.launchDate] = (counts[w.launchDate] || 0) + 1;
    }
    const colors: Record<string, string> = {};
    for (const d of Object.keys(counts)) {
      if (data.dateColors[d]) colors[d] = data.dateColors[d];
    }
    return { filteredDateColors: hasFilter ? colors : data.dateColors, filteredDateCounts: counts };
  }, [data.wines, data.dateColors, matchCountry, matchType, activeRating, ratingMinMode]);

  const calendarPinned = todayOnly || !!selectedDate;

  const calendar = (
    <MiniCalendar
      dateColors={filteredDateColors}
      dateCounts={filteredDateCounts}
      selectedDate={todayOnly ? today : selectedDate}
      onSelectDate={handleSelectDate}
    />
  );

  const tableContent = (
    <>
      <SortableTable
        columns={columns}
        data={filteredWines}
        tableId="release-table"
        renderRow={(wine, idx, cells) => (
          <tr
            key={idx}
            className="clickable"
            style={{ backgroundColor: wine.rowColor }}
            onClick={(e) => handleRowClick(wine.productNumber, e)}
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
            { label: "Vivino", href: expandedWineData.vivinoLink },
            { label: "Systembolaget", href: expandedWineData.sbLink },
            { label: "Blog", onClick: () => setBlogWine({ id: expandedWineData.productNumber, name: expandedWineData.wineName, winery: expandedWineData.producer, vintage: expandedWineData.vintage }) },
          ]}
        >
          {expandedWineData.ratingReason && (
            <div>
              <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 4, textTransform: "uppercase", letterSpacing: "0.05em" }}>AI Comment</div>
              <div style={{ fontSize: 12, fontStyle: "italic", color: "var(--text-muted)" }}>
                {expandedWineData.ratingReason}
              </div>
            </div>
          )}
        </RowPopup>
      )}
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
    </>
  );

  if (calendarPinned) {
    return (
      <div style={{ display: "flex", flexDirection: "column", flex: 1, minHeight: 0 }}>
        <div className="tab-scroll" ref={scrollRef} style={{ position: "relative" }}>
          {tableContent}
        </div>
        <div className="calendar-pinned">
          {calendar}
        </div>
        {blogWine && <BlogModal wine={blogWine} user={user} onClose={() => setBlogWine(null)} />}
      </div>
    );
  }

  return (
    <div className="tab-scroll" ref={scrollRef} style={{ position: "relative" }}>
      {tableContent}
      {calendar}
      {blogWine && <BlogModal wine={blogWine} user={user} onClose={() => setBlogWine(null)} />}
    </div>
  );
}
