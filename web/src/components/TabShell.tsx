"use client";

import { useState, useEffect, useCallback, useRef, useMemo } from "react";
import type { CellarData, ReleaseData, HistoryData, Metadata } from "@/types";
import { DarkModeToggle } from "./DarkModeToggle";
import { CellarTab } from "./cellar/CellarTab";
import { ReleaseTab } from "./release/ReleaseTab";
import { HistoryTab } from "./history/HistoryTab";
import { AuctionTab } from "./auction/AuctionTab";
import { UploadButton } from "./UploadButton";
import { getUserData, saveUserData, clearAllUserData } from "@/lib/db";

const TABS = ["release", "cellar", "history", "auction"] as const;
type TabName = (typeof TABS)[number];

const TAB_LABELS: Record<TabName, string> = {
  release: "Release",
  cellar: "Cellar",
  history: "History",
  auction: "Auction",
};

function TabIcon({ tab, size = 22 }: { tab: TabName; size?: number }) {
  const s = { width: size, height: size, strokeWidth: 1.5, stroke: "currentColor", fill: "none", strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (tab === "release") return (
    <svg viewBox="0 0 24 24" {...s}><circle cx="12" cy="12" r="9"/><path d="M12 8v4l3 3"/></svg>
  );
  if (tab === "cellar") return (
    <svg viewBox="0 0 24 24" {...s}><path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
  );
  if (tab === "history") return (
    <svg viewBox="0 0 24 24" {...s}><path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
  );
  return (
    <svg viewBox="0 0 24 24" {...s}><path d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
  );
}

const KNOWN_COUNTRIES: Record<string, string> = {
  Frankrike: "France", Italien: "Italy", Spanien: "Spain",
  Tyskland: "Germany", USA: "USA",
};

const TYPE_LABELS: Record<string, string> = {
  "Rött vin": "Red", "Vitt vin": "White",
  Rosévin: "Rosé", "Mousserande vin": "Sparkling",
};

const searchInputStyle = {
  padding: "8px 14px",
  border: "1px solid var(--border)",
  borderRadius: 10,
  fontSize: 13,
  background: "var(--input-bg)",
  color: "var(--text)",
  outline: "none",
  transition: "border-color 0.15s ease, box-shadow 0.15s ease",
} as const;

interface Props {
  releases: ReleaseData;
  metadata: Metadata;
}

export function TabShell({ releases, metadata }: Props) {
  const [activeTab, setActiveTab] = useState<TabName>("release");
  const [activeRating, setActiveRating] = useState(0);
  const [ratingMinMode, setRatingMinMode] = useState(false);
  const [auctionSearch, setAuctionSearch] = useState("");
  const [todayOnly, setTodayOnly] = useState(false);
  const [selectedCountry, setSelectedCountry] = useState("");
  const [selectedType, setSelectedType] = useState("");
  const [filterOpen, setFilterOpen] = useState(false);
  const filterRef = useRef<HTMLDivElement>(null);
  const [isMobile, setIsMobile] = useState(false);
  const [isNativeApp, setIsNativeApp] = useState(false);

  // Client-side wine data (loaded from IndexedDB)
  const [cellarData, setCellarData] = useState<CellarData | null>(null);
  const [historyData, setHistoryData] = useState<HistoryData | null>(null);
  const [importedAt, setImportedAt] = useState<string | null>(null);
  const [historyLocation, setHistoryLocation] = useState("");
  const [historyFilterOpen, setHistoryFilterOpen] = useState(false);
  const historyFilterRef = useRef<HTMLDivElement>(null);

  // URL hash sync + mobile detection + native app detection + IndexedDB load
  useEffect(() => {
    const native = !!(window as /* eslint-disable-line */ any).webkit?.messageHandlers?.tabSwitch;
    setIsNativeApp(native);
    if (native) document.body.classList.add("native-app");

    setSelectedCountry(localStorage.getItem("filterCountry") || "");
    setSelectedType(localStorage.getItem("filterType") || "");
    setHistoryLocation(localStorage.getItem("historyLocation") || "");
    const hash = window.location.hash.replace("#", "") as TabName;
    if (TABS.includes(hash)) setActiveTab(hash);

    // Load persisted wine data from IndexedDB
    getUserData<CellarData>("cellar").then(setCellarData);
    getUserData<HistoryData>("history").then(setHistoryData);
    getUserData<{ importedAt: string }>("meta").then((m) => setImportedAt(m?.importedAt ?? null));

    // Listen for hash changes (e.g. from native tab bar or Quick Actions)
    function onHashChange() {
      const h = window.location.hash.replace("#", "") as TabName;
      if (TABS.includes(h)) setActiveTab(h);
    }
    window.addEventListener("hashchange", onHashChange);

    const mq = window.matchMedia("(max-width: 768px)");
    setIsMobile(mq.matches);
    const handler = (e: MediaQueryListEvent) => setIsMobile(e.matches);
    mq.addEventListener("change", handler);
    return () => {
      window.removeEventListener("hashchange", onHashChange);
      mq.removeEventListener("change", handler);
    };
  }, []);

  // Persist filter selections
  useEffect(() => {
    localStorage.setItem("filterCountry", selectedCountry);
    localStorage.setItem("filterType", selectedType);
  }, [selectedCountry, selectedType]);

  useEffect(() => {
    localStorage.setItem("historyLocation", historyLocation);
  }, [historyLocation]);

  const visibleTabs: readonly TabName[] = TABS;

  // Import handler: save to IndexedDB and update state
  const handleImport = useCallback(async (cellar: CellarData, history: HistoryData) => {
    const d = new Date();
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    const now = `${months[d.getMonth()]} ${String(d.getDate()).padStart(2,"0")}, ${String(d.getHours()).padStart(2,"0")}:${String(d.getMinutes()).padStart(2,"0")}`;
    setCellarData(cellar);
    setHistoryData(history);
    setImportedAt(now);
    await saveUserData("cellar", cellar);
    await saveUserData("history", history);
    await saveUserData("meta", { importedAt: now });
  }, []);

  const handleClearData = useCallback(async () => {
    setCellarData(null);
    setHistoryData(null);
    setImportedAt(null);
    await clearAllUserData();
  }, []);

  const switchTab = useCallback((tab: TabName) => {
    setActiveTab(tab);
    window.history.replaceState(null, "", "#" + tab);
    // Sync native tab bar when web-side navigation occurs
    (window as /* eslint-disable-line */ any).webkit?.messageHandlers?.tabSwitch?.postMessage(tab);
  }, []);

  // Keyboard navigation
  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if ((e.target as HTMLElement).tagName === "INPUT") return;
      const idx = visibleTabs.indexOf(activeTab);
      if (e.key === "ArrowRight" && idx < visibleTabs.length - 1) switchTab(visibleTabs[idx + 1]);
      if (e.key === "ArrowLeft" && idx > 0) switchTab(visibleTabs[idx - 1]);
    }
    document.addEventListener("keydown", handleKey);
    return () => document.removeEventListener("keydown", handleKey);
  }, [activeTab, switchTab, visibleTabs]);

  // Swipe gesture navigation
  const touchRef = useRef<{ x: number; y: number } | null>(null);
  useEffect(() => {
    function onTouchStart(e: TouchEvent) {
      touchRef.current = { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    function onTouchEnd(e: TouchEvent) {
      if (!touchRef.current) return;
      const dx = e.changedTouches[0].clientX - touchRef.current.x;
      const dy = e.changedTouches[0].clientY - touchRef.current.y;
      touchRef.current = null;
      if (Math.abs(dx) < 60 || Math.abs(dy) > Math.abs(dx)) return;
      const idx = visibleTabs.indexOf(activeTab);
      if (dx < 0 && idx < visibleTabs.length - 1) switchTab(visibleTabs[idx + 1]);
      if (dx > 0 && idx > 0) switchTab(visibleTabs[idx - 1]);
    }
    document.addEventListener("touchstart", onTouchStart, { passive: true });
    document.addEventListener("touchend", onTouchEnd, { passive: true });
    return () => {
      document.removeEventListener("touchstart", onTouchStart);
      document.removeEventListener("touchend", onTouchEnd);
    };
  }, [activeTab, switchTab, visibleTabs]);

  const timestamps: Record<TabName, string> = {
    release: metadata.releaseUpdated,
    cellar: importedAt ?? "",
    history: importedAt ?? "",
    auction: metadata.auctionUpdated,
  };

  function handleRatingFilter(stars: number, min?: boolean) {
    const isSame = min
      ? ratingMinMode && activeRating === stars
      : !ratingMinMode && activeRating === stars;
    if (isSame) {
      setActiveRating(0);
      setRatingMinMode(false);
    } else {
      setActiveRating(stars);
      setRatingMinMode(!!min);
    }
  }

  // Derive available country/type chips from data
  const countryOptions = useMemo(() => {
    const counts: Record<string, number> = {};
    for (const w of releases.wines) {
      const key = KNOWN_COUNTRIES[w.country] || "Other";
      counts[key] = (counts[key] || 0) + 1;
    }
    const known = Object.values(KNOWN_COUNTRIES).filter((c) => counts[c]);
    if (counts["Other"]) known.push("Other");
    return known;
  }, [releases.wines]);

  const typeOptions = useMemo(() => {
    const seen = new Set<string>();
    for (const w of releases.wines) seen.add(w.wineType);
    const ordered = ["Red", "White", "Rosé", "Sparkling"];
    const result: string[] = [];
    for (const label of ordered) {
      const sv = Object.entries(TYPE_LABELS).find(([, v]) => v === label)?.[0];
      if (sv && seen.has(sv)) result.push(label);
    }
    const hasOther = [...seen].some((sv) => !TYPE_LABELS[sv]);
    if (hasOther) result.push("Other");
    return result;
  }, [releases.wines]);

  const RATED_COMBOS = new Set(["France:Red", "France:White", "Italy:Red", "Italy:White"]);
  const hasRatings = RATED_COMBOS.has(`${selectedCountry}:${selectedType}`);

  // Close filter dropdown on click outside
  useEffect(() => {
    if (!filterOpen) return;
    function handleClick(e: MouseEvent) {
      if (filterRef.current && !filterRef.current.contains(e.target as Node)) {
        setFilterOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [filterOpen]);

  // Close history filter dropdown on click outside
  useEffect(() => {
    if (!historyFilterOpen) return;
    function handleClick(e: MouseEvent) {
      if (historyFilterRef.current && !historyFilterRef.current.contains(e.target as Node)) {
        setHistoryFilterOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [historyFilterOpen]);

  // Map English label back to Swedish for filtering
  function countryToSwedish(label: string): string {
    if (label === "Other") return "__other__";
    return Object.entries(KNOWN_COUNTRIES).find(([, v]) => v === label)?.[0] || label;
  }
  function typeToSwedish(label: string): string {
    if (label === "Other") return "__other__";
    return Object.entries(TYPE_LABELS).find(([, v]) => v === label)?.[0] || label;
  }

  const hasActiveFilters = selectedCountry !== "" || selectedType !== "" || activeRating > 0;

  const historyLocations = useMemo(() => historyData?.locations ?? [], [historyData]);
  const filteredHistoryWines = useMemo(() => {
    if (!historyData) return [];
    if (!historyLocation) return historyData.wines;
    return historyData.wines.filter((w) => w.scanLocation === historyLocation);
  }, [historyData, historyLocation]);

  return (
    <>
      {/* Fixed header */}
      <div style={{ flexShrink: 0, position: "relative", zIndex: 10 }}>
      {/* Top bar */}
      <div
        style={{
          display: "flex",
          gap: 4,
          marginBottom: isMobile ? 12 : 20,
          alignItems: "center",
          position: "relative",
          flexWrap: "wrap",
          zIndex: 100,
        }}
      >
        {/* Tab pills - desktop only */}
        {!isMobile && (
          <div
            style={{
              display: "flex",
              gap: 2,
              background: "var(--bg-alt)",
              borderRadius: 10,
              padding: 3,
            }}
          >
            {visibleTabs.map((tab) => (
              <button
                key={tab}
                onClick={() => switchTab(tab)}
                style={{
                  padding: "7px 18px",
                  background:
                    activeTab === tab
                      ? "var(--tab-active-bg)"
                      : "transparent",
                  border: "none",
                  cursor: "pointer",
                  fontSize: 13,
                  fontWeight: activeTab === tab ? 500 : 400,
                  color:
                    activeTab === tab
                      ? "var(--tab-active-text)"
                      : "var(--text-muted)",
                  borderRadius: 8,
                  transition: "all 0.15s ease",
                }}
              >
                {TAB_LABELS[tab]}
              </button>
            ))}
          </div>
        )}

        {/* Upload Vivino data - desktop only (cellar tab) */}
        {activeTab === "cellar" && cellarData && !isMobile && (
          <div
            style={{
              position: "absolute",
              left: "50%",
              transform: "translateX(-50%)",
            }}
          >
            <UploadButton onImportComplete={handleImport} onClearData={handleClearData} />
          </div>
        )}

        {/* History: Upload + Filter - desktop only */}
        {activeTab === "history" && historyData && !isMobile && (
          <div
            ref={historyFilterRef}
            style={{
              position: "absolute",
              left: "50%",
              transform: "translateX(-50%)",
              display: "flex",
              gap: 6,
              alignItems: "center",
            }}
          >
            <UploadButton onImportComplete={handleImport} onClearData={handleClearData} />
            <button
              onClick={() => setHistoryFilterOpen((v) => !v)}
              style={{
                padding: "6px 14px",
                border: "none",
                background: historyLocation || historyFilterOpen
                  ? "var(--tab-active-bg)"
                  : "var(--bg-alt)",
                color: historyLocation || historyFilterOpen
                  ? "var(--tab-active-text)"
                  : "var(--text-muted)",
                cursor: "pointer",
                borderRadius: 8,
                fontSize: 12,
                fontWeight: 500,
                transition: "all 0.15s ease",
              }}
            >
              Filter{historyLocation ? " \u2022" : ""}
            </button>
            {historyFilterOpen && (
              <div
                style={{
                  position: "absolute",
                  top: "calc(100% + 8px)",
                  left: "50%",
                  transform: "translateX(-50%)",
                  background: "var(--bg)",
                  border: "1px solid var(--border)",
                  borderRadius: 12,
                  padding: 12,
                  zIndex: 300,
                  minWidth: 220,
                  boxShadow: "0 4px 20px rgba(0,0,0,0.12)",
                }}
              >
                <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>Location</div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                  {historyLocations.map((loc) => (
                    <button
                      key={loc || "__empty__"}
                      onClick={() => setHistoryLocation(historyLocation === loc ? "" : loc)}
                      style={{
                        padding: "4px 10px",
                        border: "none",
                        background: historyLocation === loc ? "var(--tab-active-bg)" : "var(--bg-alt)",
                        color: historyLocation === loc ? "var(--tab-active-text)" : "var(--text-muted)",
                        cursor: "pointer",
                        borderRadius: 6,
                        fontSize: 12,
                        transition: "all 0.15s ease",
                      }}
                    >
                      {loc || "Unknown"}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Auction search - desktop only */}
        {activeTab === "auction" && !isMobile && (
          <div
            style={{
              position: "absolute",
              left: "50%",
              transform: "translateX(-50%)",
            }}
          >
            <input
              type="text"
              placeholder="Search producers..."
              value={auctionSearch}
              onChange={(e) => setAuctionSearch(e.target.value)}
              style={{ ...searchInputStyle, width: 280 }}
            />
          </div>
        )}

        {/* Filter button + Today button - release tab */}
        {activeTab === "release" && !isMobile && (
          <div
            ref={filterRef}
            style={{
              display: "flex",
              gap: 6,
              alignItems: "center",
              position: "absolute",
              left: "50%",
              transform: "translateX(-50%)",
            }}
          >
            <button
              onClick={() => setTodayOnly((v) => !v)}
              style={{
                padding: "6px 14px",
                border: "none",
                background: todayOnly
                  ? "var(--tab-active-bg)"
                  : "var(--bg-alt)",
                color: todayOnly
                  ? "var(--tab-active-text)"
                  : "var(--text-muted)",
                cursor: "pointer",
                borderRadius: 8,
                fontSize: 12,
                fontWeight: 500,
                transition: "all 0.15s ease",
              }}
            >
              Today{"\u2019"}s Releases
            </button>
            <button
              onClick={() => setFilterOpen((v) => !v)}
              style={{
                padding: "6px 14px",
                border: "none",
                background: hasActiveFilters || filterOpen
                  ? "var(--tab-active-bg)"
                  : "var(--bg-alt)",
                color: hasActiveFilters || filterOpen
                  ? "var(--tab-active-text)"
                  : "var(--text-muted)",
                cursor: "pointer",
                borderRadius: 8,
                fontSize: 12,
                fontWeight: 500,
                transition: "all 0.15s ease",
              }}
            >
              Filter{hasActiveFilters ? " \u2022" : ""}
            </button>
            {filterOpen && (
              <div
                style={{
                  position: "absolute",
                  top: "calc(100% + 8px)",
                  left: "50%",
                  transform: "translateX(-50%)",
                  background: "var(--bg)",
                  border: "1px solid var(--border)",
                  borderRadius: 12,
                  padding: 12,
                  zIndex: 300,
                  minWidth: 280,
                  display: "flex",
                  flexDirection: "column",
                  gap: 10,
                  boxShadow: "0 4px 20px rgba(0,0,0,0.12)",
                }}
              >
                <div>
                  <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>Country</div>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                    {countryOptions.map((c) => (
                      <button
                        key={c}
                        onClick={() => {
                          setSelectedCountry(selectedCountry === c ? "" : c);
                          if (selectedCountry !== c && c !== "France" && c !== "Italy") {
                            setActiveRating(0);
                            setRatingMinMode(false);
                          }
                        }}
                        style={{
                          padding: "4px 10px",
                          border: "none",
                          background: selectedCountry === c ? "var(--tab-active-bg)" : "var(--bg-alt)",
                          color: selectedCountry === c ? "var(--tab-active-text)" : "var(--text-muted)",
                          cursor: "pointer",
                          borderRadius: 6,
                          fontSize: 12,
                          transition: "all 0.15s ease",
                        }}
                      >
                        {c}
                      </button>
                    ))}
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>Type</div>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                    {typeOptions.map((t) => (
                      <button
                        key={t}
                        onClick={() => {
                          setSelectedType(selectedType === t ? "" : t);
                          if (selectedType !== t && t !== "Red" && t !== "White") {
                            setActiveRating(0);
                            setRatingMinMode(false);
                          }
                        }}
                        style={{
                          padding: "4px 10px",
                          border: "none",
                          background: selectedType === t ? "var(--tab-active-bg)" : "var(--bg-alt)",
                          color: selectedType === t ? "var(--tab-active-text)" : "var(--text-muted)",
                          cursor: "pointer",
                          borderRadius: 6,
                          fontSize: 12,
                          transition: "all 0.15s ease",
                        }}
                      >
                        {t}
                      </button>
                    ))}
                  </div>
                </div>
                {hasRatings && (
                  <div>
                    <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>AI Rating</div>
                    <div style={{ display: "flex", gap: 2, background: "var(--bg-alt)", borderRadius: 8, padding: 2, width: "fit-content" }}>
                      {[
                        { stars: 3, label: "\u2605\u2605\u2605", min: false },
                        { stars: 3, label: "\u2605\u2605\u2605+", min: true },
                        { stars: 4, label: "\u2605\u2605\u2605\u2605", min: false },
                      ].map((f, i) => {
                        const isActive = f.min
                          ? ratingMinMode && activeRating === f.stars
                          : !ratingMinMode && activeRating === f.stars;
                        return (
                          <button
                            key={i}
                            onClick={() => handleRatingFilter(f.stars, f.min)}
                            style={{
                              padding: "4px 10px",
                              border: "none",
                              background: isActive ? "var(--tab-active-bg)" : "transparent",
                              color: isActive ? "var(--tab-active-text)" : "var(--text-muted)",
                              cursor: "pointer",
                              borderRadius: 6,
                              fontSize: 13,
                              transition: "all 0.15s ease",
                            }}
                          >
                            {f.label}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Right side: timestamp + dark mode - desktop */}
        {!isMobile && (
          <span
            style={{
              marginLeft: "auto",
              display: "flex",
              gap: 10,
              alignItems: "center",
            }}
          >
            <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
              {timestamps[activeTab]}
            </span>
            <DarkModeToggle />
          </span>
        )}
      </div>

      {/* Mobile: single-line header with context controls + dark mode */}
      {isMobile && (
        <div style={{ display: "flex", alignItems: "center", marginBottom: 12, position: "relative" }}>
          {/* Release tab: Today on left, Filter centered, dark mode right */}
          {activeTab === "release" && (
            <>
              <button
                onClick={() => setTodayOnly((v) => !v)}
                style={{
                  padding: "6px 14px",
                  border: "none",
                  background: todayOnly
                    ? "var(--tab-active-bg)"
                    : "var(--bg-alt)",
                  color: todayOnly
                    ? "var(--tab-active-text)"
                    : "var(--text-muted)",
                  cursor: "pointer",
                  borderRadius: 8,
                  fontSize: 12,
                  fontWeight: 500,
                  transition: "all 0.15s ease",
                }}
              >
                Today{"\u2019"}s
              </button>
              <div
                ref={isMobile ? filterRef : undefined}
                style={{
                  position: "absolute",
                  left: "50%",
                  transform: "translateX(-50%)",
                }}
              >
                <button
                  onClick={() => setFilterOpen((v) => !v)}
                  style={{
                    padding: "6px 14px",
                    border: "none",
                    background: hasActiveFilters || filterOpen
                      ? "var(--tab-active-bg)"
                      : "var(--bg-alt)",
                    color: hasActiveFilters || filterOpen
                      ? "var(--tab-active-text)"
                      : "var(--text-muted)",
                    cursor: "pointer",
                    borderRadius: 8,
                    fontSize: 12,
                    fontWeight: 500,
                    transition: "all 0.15s ease",
                  }}
                >
                  Filter{hasActiveFilters ? " \u2022" : ""}
                </button>
                {filterOpen && (
                  <div
                    style={{
                      position: "absolute",
                      top: "calc(100% + 8px)",
                      left: "50%",
                      transform: "translateX(-50%)",
                      background: "var(--bg)",
                      border: "1px solid var(--border)",
                      borderRadius: 12,
                      padding: 12,
                      zIndex: 300,
                      minWidth: 260,
                      display: "flex",
                      flexDirection: "column",
                      gap: 10,
                      boxShadow: "0 4px 20px rgba(0,0,0,0.12)",
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>Country</div>
                      <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                        {countryOptions.map((c) => (
                          <button
                            key={c}
                            onClick={() => {
                              setSelectedCountry(selectedCountry === c ? "" : c);
                              if (selectedCountry !== c && c !== "France" && c !== "Italy") {
                                setActiveRating(0);
                                setRatingMinMode(false);
                              }
                            }}
                            style={{
                              padding: "4px 10px",
                              border: "none",
                              background: selectedCountry === c ? "var(--tab-active-bg)" : "var(--bg-alt)",
                              color: selectedCountry === c ? "var(--tab-active-text)" : "var(--text-muted)",
                              cursor: "pointer",
                              borderRadius: 6,
                              fontSize: 12,
                              transition: "all 0.15s ease",
                            }}
                          >
                            {c}
                          </button>
                        ))}
                      </div>
                    </div>
                    <div>
                      <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>Type</div>
                      <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                        {typeOptions.map((t) => (
                          <button
                            key={t}
                            onClick={() => {
                              setSelectedType(selectedType === t ? "" : t);
                              if (selectedType !== t && t !== "Red" && t !== "White") {
                                setActiveRating(0);
                                setRatingMinMode(false);
                              }
                            }}
                            style={{
                              padding: "4px 10px",
                              border: "none",
                              background: selectedType === t ? "var(--tab-active-bg)" : "var(--bg-alt)",
                              color: selectedType === t ? "var(--tab-active-text)" : "var(--text-muted)",
                              cursor: "pointer",
                              borderRadius: 6,
                              fontSize: 12,
                              transition: "all 0.15s ease",
                            }}
                          >
                            {t}
                          </button>
                        ))}
                      </div>
                    </div>
                    {hasRatings && (
                      <div>
                        <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>AI Rating</div>
                        <div style={{ display: "flex", gap: 2, background: "var(--bg-alt)", borderRadius: 8, padding: 2, width: "fit-content" }}>
                          {[
                            { stars: 3, label: "\u2605\u2605\u2605", min: false },
                            { stars: 3, label: "\u2605\u2605\u2605+", min: true },
                            { stars: 4, label: "\u2605\u2605\u2605\u2605", min: false },
                          ].map((f, i) => {
                            const isActive = f.min
                              ? ratingMinMode && activeRating === f.stars
                              : !ratingMinMode && activeRating === f.stars;
                            return (
                              <button
                                key={i}
                                onClick={() => handleRatingFilter(f.stars, f.min)}
                                style={{
                                  padding: "4px 10px",
                                  border: "none",
                                  background: isActive ? "var(--tab-active-bg)" : "transparent",
                                  color: isActive ? "var(--tab-active-text)" : "var(--text-muted)",
                                  cursor: "pointer",
                                  borderRadius: 6,
                                  fontSize: 12,
                                  transition: "all 0.15s ease",
                                }}
                              >
                                {f.label}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </>
          )}

          {/* Auction tab: search bar */}
          {activeTab === "auction" && (
            <input
              type="text"
              placeholder="Search producers..."
              value={auctionSearch}
              onChange={(e) => setAuctionSearch(e.target.value)}
              style={{ ...searchInputStyle, padding: "6px 14px", flex: 1, marginRight: 6 }}
            />
          )}

          {/* Cellar: upload button on the left */}
          {activeTab === "cellar" && cellarData && (
            <UploadButton onImportComplete={handleImport} onClearData={handleClearData} />
          )}

          {/* History: upload on left, filter centered */}
          {activeTab === "history" && historyData && (
            <>
              <UploadButton onImportComplete={handleImport} onClearData={handleClearData} />
              <div
                ref={isMobile ? historyFilterRef : undefined}
                style={{
                  position: "absolute",
                  left: "50%",
                  transform: "translateX(-50%)",
                }}
              >
                <button
                  onClick={() => setHistoryFilterOpen((v) => !v)}
                  style={{
                    padding: "6px 14px",
                    border: "none",
                    background: historyLocation || historyFilterOpen
                      ? "var(--tab-active-bg)"
                      : "var(--bg-alt)",
                    color: historyLocation || historyFilterOpen
                      ? "var(--tab-active-text)"
                      : "var(--text-muted)",
                    cursor: "pointer",
                    borderRadius: 8,
                    fontSize: 12,
                    fontWeight: 500,
                    transition: "all 0.15s ease",
                  }}
                >
                  Filter{historyLocation ? " \u2022" : ""}
                </button>
                {historyFilterOpen && (
                  <div
                    style={{
                      position: "absolute",
                      top: "calc(100% + 8px)",
                      left: "50%",
                      transform: "translateX(-50%)",
                      background: "var(--bg)",
                      border: "1px solid var(--border)",
                      borderRadius: 12,
                      padding: 12,
                      zIndex: 300,
                      minWidth: 220,
                      boxShadow: "0 4px 20px rgba(0,0,0,0.12)",
                    }}
                  >
                    <div style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>Location</div>
                    <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                      {historyLocations.map((loc) => (
                        <button
                          key={loc || "__empty__"}
                          onClick={() => setHistoryLocation(historyLocation === loc ? "" : loc)}
                          style={{
                            padding: "4px 10px",
                            border: "none",
                            background: historyLocation === loc ? "var(--tab-active-bg)" : "var(--bg-alt)",
                            color: historyLocation === loc ? "var(--tab-active-text)" : "var(--text-muted)",
                            cursor: "pointer",
                            borderRadius: 6,
                            fontSize: 12,
                            transition: "all 0.15s ease",
                          }}
                        >
                          {loc || "Unknown"}
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </>
          )}

          {/* Dark mode toggle always on the right */}
          <span style={{ marginLeft: "auto" }}>
            <DarkModeToggle />
          </span>
        </div>
      )}
      </div>

      {/* Content area */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: 0 }}>
      {activeTab === "release" && (
        <ReleaseTab
          data={releases}
          activeRating={activeRating}
          ratingMinMode={ratingMinMode}
          todayOnly={todayOnly}
          matchCountry={selectedCountry ? (c: string) => {
            const svKey = countryToSwedish(selectedCountry);
            if (svKey === "__other__") {
              return !Object.keys(KNOWN_COUNTRIES).includes(c);
            }
            return c === svKey;
          } : null}
          matchType={selectedType ? (t: string) => {
            const svKey = typeToSwedish(selectedType);
            if (svKey === "__other__") {
              return !Object.keys(TYPE_LABELS).includes(t);
            }
            return t === svKey;
          } : null}
          hasRatings={hasRatings}
        />
      )}
      {activeTab === "cellar" && (
        cellarData ? <CellarTab data={cellarData} /> : <UploadButton inline onImportComplete={handleImport} />
      )}
      {activeTab === "history" && (
        historyData ? <HistoryTab wines={filteredHistoryWines} selectedLocation={historyLocation} /> : <UploadButton inline onImportComplete={handleImport} />
      )}
      {activeTab === "auction" && <AuctionTab search={auctionSearch} />}
      </div>

      {/* Mobile: Bottom tab bar (hidden when native app provides its own) */}
      {isMobile && !isNativeApp && (
        <div
          style={{
            position: "fixed",
            bottom: 0,
            left: 0,
            right: 0,
            zIndex: 1000,
            display: "flex",
            justifyContent: "space-around",
            alignItems: "center",
            padding: "6px 0 calc(6px + env(safe-area-inset-bottom))",
            background: "var(--bottom-bar-bg)",
            backdropFilter: "blur(20px) saturate(180%)",
            WebkitBackdropFilter: "blur(20px) saturate(180%)",
            borderTop: "0.5px solid var(--bottom-bar-border)",
          }}
        >
          {visibleTabs.map((tab) => {
            const active = activeTab === tab;
            return (
              <button
                key={tab}
                onClick={() => switchTab(tab)}
                style={{
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  gap: 2,
                  background: "none",
                  border: "none",
                  cursor: "pointer",
                  padding: "4px 16px",
                  color: active ? "var(--bottom-bar-active)" : "var(--text-muted)",
                  transition: "color 0.15s ease",
                  WebkitTapHighlightColor: "transparent",
                }}
              >
                <TabIcon tab={tab} size={22} />
                <span style={{ fontSize: 10, fontWeight: active ? 600 : 400 }}>
                  {TAB_LABELS[tab]}
                </span>
              </button>
            );
          })}
        </div>
      )}
    </>
  );
}
