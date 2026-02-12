"use client";

import { useState, useEffect, useCallback, useRef, useMemo } from "react";
import type { CellarData, ReleaseData, HistoryData, Metadata } from "@/types";
import { ProfileTab } from "./profile/ProfileTab";
import { signInWithApple, signOutUser, onAuthChange, type AuthUser } from "@/lib/firebase";
import { CellarTab } from "./cellar/CellarTab";
import { ReleaseTab } from "./release/ReleaseTab";
import { HistoryTab } from "./history/HistoryTab";
import { AuctionTab } from "./auction/AuctionTab";
import { BlogTab } from "./blog/BlogTab";
import { UploadButton } from "./UploadButton";
import { getUserData, saveUserData, clearAllUserData } from "@/lib/db";

const TABS = ["release", "cellar", "blog", "auction", "profile"] as const;
type TabName = (typeof TABS)[number];

const TAB_LABELS: Record<TabName, string> = {
  release: "Release",
  cellar: "Cellar",
  blog: "Blog",
  auction: "Auction",
  profile: "Profile",
};

function TabIcon({ tab, size = 22 }: { tab: TabName; size?: number }) {
  const s = { width: size, height: size, strokeWidth: 1.5, stroke: "currentColor", fill: "none", strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (tab === "release") return (
    <svg viewBox="0 0 24 24" {...s}><circle cx="12" cy="12" r="9"/><path d="M12 8v4l3 3"/></svg>
  );
  if (tab === "cellar") return (
    <svg viewBox="0 0 24 24" {...s}><path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
  );
  if (tab === "blog") return (
    <svg viewBox="0 0 24 24" {...s}><path d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V9a2 2 0 012-2h2a2 2 0 012 2v9a2 2 0 01-2 2h-2zm-8-7H7m4 4H7m6-8H7"/></svg>
  );
  if (tab === "auction") return (
    <svg viewBox="0 0 24 24" {...s}><path d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
  );
  return (
    <svg viewBox="0 0 24 24" {...s}><path d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/></svg>
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

const sectionLabelStyle: React.CSSProperties = {
  fontSize: 11, fontWeight: 500, color: "var(--text-muted)",
  marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em",
};

function chipStyle(active: boolean): React.CSSProperties {
  return {
    padding: "4px 10px",
    border: "none",
    background: active ? "var(--tab-active-bg)" : "var(--bg-alt)",
    color: active ? "var(--tab-active-text)" : "var(--text-muted)",
    cursor: "pointer",
    borderRadius: 6,
    fontSize: 12,
    transition: "all 0.15s ease",
  };
}

function toggleBtnStyle(active: boolean): React.CSSProperties {
  return {
    padding: "6px 14px",
    border: "none",
    background: active ? "var(--tab-active-bg)" : "var(--bg-alt)",
    color: active ? "var(--tab-active-text)" : "var(--text-muted)",
    cursor: "pointer",
    borderRadius: 8,
    fontSize: 12,
    fontWeight: 500,
    transition: "all 0.15s ease",
  };
}

const dropdownStyle: React.CSSProperties = {
  position: "absolute",
  top: "calc(100% + 8px)",
  left: "50%",
  transform: "translateX(-50%)",
  background: "var(--bg)",
  border: "1px solid var(--border)",
  borderRadius: 12,
  padding: 12,
  zIndex: 300,
  boxShadow: "0 4px 20px rgba(0,0,0,0.12)",
};

function useOutsideClick(ref: React.RefObject<HTMLElement | null>, open: boolean, onClose: () => void) {
  useEffect(() => {
    if (!open) return;
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        onClose();
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open, ref, onClose]);
}

// --- Extracted filter dropdown contents ---

function ReleaseFilterContent({
  countryOptions,
  typeOptions,
  selectedCountry,
  selectedType,
  setSelectedCountry,
  setSelectedType,
  hasRatings,
  activeRating,
  ratingMinMode,
  handleRatingFilter,
  setActiveRating,
  setRatingMinMode,
}: {
  countryOptions: string[];
  typeOptions: string[];
  selectedCountry: string;
  selectedType: string;
  setSelectedCountry: (v: string) => void;
  setSelectedType: (v: string) => void;
  hasRatings: boolean;
  activeRating: number;
  ratingMinMode: boolean;
  handleRatingFilter: (stars: number, min?: boolean) => void;
  setActiveRating: (v: number) => void;
  setRatingMinMode: (v: boolean) => void;
}) {
  return (
    <>
      <div>
        <div style={sectionLabelStyle}>Country</div>
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
              style={chipStyle(selectedCountry === c)}
            >
              {c}
            </button>
          ))}
        </div>
      </div>
      <div>
        <div style={sectionLabelStyle}>Type</div>
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
              style={chipStyle(selectedType === t)}
            >
              {t}
            </button>
          ))}
        </div>
      </div>
      {hasRatings && (
        <div>
          <div style={sectionLabelStyle}>AI Rating</div>
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
    </>
  );
}

function HistoryFilterContent({
  locations,
  selected,
  onSelect,
}: {
  locations: string[];
  selected: string;
  onSelect: (loc: string) => void;
}) {
  return (
    <>
      <div style={sectionLabelStyle}>Location</div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
        {locations.map((loc) => (
          <button
            key={loc || "__empty__"}
            onClick={() => onSelect(selected === loc ? "" : loc)}
            style={chipStyle(selected === loc)}
          >
            {loc || "Unknown"}
          </button>
        ))}
      </div>
    </>
  );
}

// --- Main component ---

interface Props {
  releases: ReleaseData;
  metadata: Metadata;
}

export function TabShell({ releases, metadata }: Props) {
  const [activeTab, setActiveTab] = useState<TabName>("release");
  const [user, setUser] = useState<AuthUser | null>(null);
  const [activeRating, setActiveRating] = useState(0);
  const [ratingMinMode, setRatingMinMode] = useState(false);
  const [auctionSearch, setAuctionSearch] = useState("");
  const [todayOnly, setTodayOnly] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
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
  const [cellarYear, setCellarYear] = useState<string | null>(null);
  const [cellarVintage, setCellarVintage] = useState<string | null>(null);
  const [cellarFilterOpen, setCellarFilterOpen] = useState(false);
  const cellarFilterRef = useRef<HTMLDivElement>(null);

  // URL hash sync + mobile detection + native app detection + IndexedDB load
  useEffect(() => {
    const native = !!(window as /* eslint-disable-line */ any).webkit?.messageHandlers?.tabSwitch;
    setIsNativeApp(native);
    if (native) document.body.classList.add("native-app");

    setSelectedCountry(localStorage.getItem("filterCountry") || "");
    setSelectedType(localStorage.getItem("filterType") || "");
    setHistoryLocation(localStorage.getItem("historyLocation") || "");
    const hash = window.location.hash.replace("#", "");
    if (hash === "history") {
      window.history.replaceState(null, "", "#cellar");
      setActiveTab("cellar");
      setShowHistory(true);
    } else if (TABS.includes(hash as TabName)) {
      setActiveTab(hash as TabName);
    }

    // Load persisted wine data from IndexedDB
    getUserData<CellarData>("cellar").then(setCellarData);
    getUserData<HistoryData>("history").then(setHistoryData);
    getUserData<{ importedAt: string }>("meta").then((m) => setImportedAt(m?.importedAt ?? null));

    // Listen for hash changes (e.g. from native tab bar or Quick Actions)
    function onHashChange() {
      const h = window.location.hash.replace("#", "");
      if (h === "history") {
        window.history.replaceState(null, "", "#cellar");
        setActiveTab("cellar");
        setShowHistory(true);
      } else if (TABS.includes(h as TabName)) {
        setActiveTab(h as TabName);
      }
    }
    window.addEventListener("hashchange", onHashChange);

    const mq = window.matchMedia("(max-width: 768px)");
    setIsMobile(mq.matches);
    const handler = (e: MediaQueryListEvent) => setIsMobile(e.matches);
    mq.addEventListener("change", handler);

    const unsubAuth = onAuthChange(setUser);

    return () => {
      window.removeEventListener("hashchange", onHashChange);
      mq.removeEventListener("change", handler);
      unsubAuth();
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
    blog: "",
    auction: metadata.auctionUpdated,
    profile: "",
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

  // Close dropdowns on click outside
  const closeFilter = useCallback(() => setFilterOpen(false), []);
  const closeHistoryFilter = useCallback(() => setHistoryFilterOpen(false), []);
  const closeCellarFilter = useCallback(() => setCellarFilterOpen(false), []);
  useOutsideClick(filterRef, filterOpen, closeFilter);
  useOutsideClick(historyFilterRef, historyFilterOpen, closeHistoryFilter);
  useOutsideClick(cellarFilterRef, cellarFilterOpen, closeCellarFilter);

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

  const cellarYears = useMemo(() => {
    if (!cellarData) return [];
    return Object.keys(cellarData.yearCounts)
      .filter((k) => /^\d{4}$/.test(k))
      .sort();
  }, [cellarData]);

  const cellarVintages = useMemo(() => {
    if (!cellarData) return [];
    const set = new Set<string>();
    for (const w of cellarData.wines) {
      if (w.vintage && /^\d{4}$/.test(w.vintage)) set.add(w.vintage);
    }
    return [...set].sort();
  }, [cellarData]);

  const historyLocations = useMemo(() => historyData?.locations ?? [], [historyData]);
  const filteredHistoryWines = useMemo(() => {
    if (!historyData) return [];
    if (!historyLocation) return historyData.wines;
    return historyData.wines.filter((w) => w.scanLocation === historyLocation);
  }, [historyData, historyLocation]);

  // Shared props for ReleaseFilterContent
  const releaseFilterProps = {
    countryOptions,
    typeOptions,
    selectedCountry,
    selectedType,
    setSelectedCountry,
    setSelectedType,
    hasRatings,
    activeRating,
    ratingMinMode,
    handleRatingFilter,
    setActiveRating,
    setRatingMinMode,
  };

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

        {/* Centered timestamp - desktop */}
        {!isMobile && timestamps[activeTab] && (
          <span
            style={{
              position: "absolute",
              left: "50%",
              transform: "translateX(-50%)",
              fontSize: 12,
              color: "var(--text-muted)",
              pointerEvents: "none",
            }}
          >
            {timestamps[activeTab]}
          </span>
        )}

        {/* Right side: tab controls - desktop */}
        {!isMobile && (
          <span
            ref={activeTab === "release" ? filterRef : activeTab === "cellar" ? (showHistory ? historyFilterRef : cellarFilterRef) : undefined}
            style={{
              marginLeft: "auto",
              display: "flex",
              gap: 10,
              alignItems: "center",
              position: "relative",
            }}
          >
            {activeTab === "release" && (
              <>
                <button
                  onClick={() => setTodayOnly((v) => !v)}
                  style={toggleBtnStyle(todayOnly)}
                >
                  Today{"\u2019"}s Releases
                </button>
                <button
                  onClick={() => setFilterOpen((v) => !v)}
                  style={toggleBtnStyle(hasActiveFilters || filterOpen)}
                >
                  Filter{hasActiveFilters ? " \u2022" : ""}
                </button>
                {filterOpen && (
                  <div style={{ ...dropdownStyle, left: "auto", right: 0, transform: "none", minWidth: 280, display: "flex", flexDirection: "column", gap: 10 }}>
                    <ReleaseFilterContent {...releaseFilterProps} />
                  </div>
                )}
              </>
            )}
            {activeTab === "cellar" && (cellarData || historyData) && (
              <>
                <button
                  onClick={() => setShowHistory((v) => !v)}
                  style={toggleBtnStyle(showHistory)}
                >
                  History
                </button>
                {!showHistory && (cellarYears.length > 0 || cellarVintages.length > 0) && (
                  <>
                    <button
                      onClick={() => setCellarFilterOpen((v) => !v)}
                      style={toggleBtnStyle(!!cellarYear || !!cellarVintage || cellarFilterOpen)}
                    >
                      Filter{cellarYear || cellarVintage ? " \u2022" : ""}
                    </button>
                    {cellarFilterOpen && (
                      <div style={{ ...dropdownStyle, left: "auto", right: 0, transform: "none", minWidth: 200, display: "flex", flexDirection: "column", gap: 10 }}>
                        {cellarYears.length > 0 && (
                          <div>
                            <div style={sectionLabelStyle}>Drink Year</div>
                            <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                              {cellarYears.map((y) => (
                                <button
                                  key={y}
                                  onClick={() => setCellarYear(cellarYear === y ? null : y)}
                                  style={chipStyle(cellarYear === y)}
                                >
                                  {y}
                                </button>
                              ))}
                            </div>
                          </div>
                        )}
                        {cellarVintages.length > 0 && (
                          <div>
                            <div style={sectionLabelStyle}>Vintage</div>
                            <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                              {cellarVintages.map((v) => (
                                <button
                                  key={v}
                                  onClick={() => setCellarVintage(cellarVintage === v ? null : v)}
                                  style={chipStyle(cellarVintage === v)}
                                >
                                  {v}
                                </button>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    )}
                  </>
                )}
                {showHistory && historyData && (
                  <>
                    <button
                      onClick={() => setHistoryFilterOpen((v) => !v)}
                      style={toggleBtnStyle(!!historyLocation || historyFilterOpen)}
                    >
                      Filter{historyLocation ? " \u2022" : ""}
                    </button>
                    {historyFilterOpen && (
                      <div style={{ ...dropdownStyle, left: "auto", right: 0, transform: "none", minWidth: 220 }}>
                        <HistoryFilterContent
                          locations={historyLocations}
                          selected={historyLocation}
                          onSelect={setHistoryLocation}
                        />
                      </div>
                    )}
                  </>
                )}
              </>
            )}
            {activeTab === "auction" && (
              <input
                type="text"
                placeholder="Search producers..."
                value={auctionSearch}
                onChange={(e) => setAuctionSearch(e.target.value)}
                style={{ ...searchInputStyle, width: 400 }}
              />
            )}
          </span>
        )}
      </div>

      {/* Mobile: single-line header with context controls */}
      {isMobile && (
        <div style={{ display: "flex", alignItems: "center", marginBottom: 12, position: "relative" }}>
          {/* Release tab: Today on left, Filter on right */}
          {activeTab === "release" && (
            <>
              <button
                onClick={() => setTodayOnly((v) => !v)}
                style={toggleBtnStyle(todayOnly)}
              >
                Today{"\u2019"}s
              </button>
              <div
                ref={isMobile ? filterRef : undefined}
                style={{
                  marginLeft: "auto",
                  position: "relative",
                }}
              >
                <button
                  onClick={() => setFilterOpen((v) => !v)}
                  style={toggleBtnStyle(hasActiveFilters || filterOpen)}
                >
                  Filter{hasActiveFilters ? " \u2022" : ""}
                </button>
                {filterOpen && (
                  <div style={{ ...dropdownStyle, left: "auto", right: 0, transform: "none", minWidth: 260, display: "flex", flexDirection: "column", gap: 10 }}>
                    <ReleaseFilterContent {...releaseFilterProps} />
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
              style={{ ...searchInputStyle, padding: "6px 14px", flex: 1 }}
            />
          )}

          {/* Cellar: History toggle on left, filter on right */}
          {activeTab === "cellar" && (cellarData || historyData) && (
            <>
              <button
                onClick={() => setShowHistory((v) => !v)}
                style={toggleBtnStyle(showHistory)}
              >
                History
              </button>
              {!showHistory && (cellarYears.length > 0 || cellarVintages.length > 0) && (
                <div
                  ref={isMobile ? cellarFilterRef : undefined}
                  style={{
                    marginLeft: "auto",
                    position: "relative",
                  }}
                >
                  <button
                    onClick={() => setCellarFilterOpen((v) => !v)}
                    style={toggleBtnStyle(!!cellarYear || !!cellarVintage || cellarFilterOpen)}
                  >
                    Filter{cellarYear || cellarVintage ? " \u2022" : ""}
                  </button>
                  {cellarFilterOpen && (
                    <div style={{ ...dropdownStyle, left: "auto", right: 0, transform: "none", minWidth: 200, display: "flex", flexDirection: "column", gap: 10 }}>
                      {cellarYears.length > 0 && (
                        <div>
                          <div style={sectionLabelStyle}>Drink Year</div>
                          <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                            {cellarYears.map((y) => (
                              <button
                                key={y}
                                onClick={() => setCellarYear(cellarYear === y ? null : y)}
                                style={chipStyle(cellarYear === y)}
                              >
                                {y}
                              </button>
                            ))}
                          </div>
                        </div>
                      )}
                      {cellarVintages.length > 0 && (
                        <div>
                          <div style={sectionLabelStyle}>Vintage</div>
                          <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                            {cellarVintages.map((v) => (
                              <button
                                key={v}
                                onClick={() => setCellarVintage(cellarVintage === v ? null : v)}
                                style={chipStyle(cellarVintage === v)}
                              >
                                {v}
                              </button>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}
              {showHistory && historyData && (
                <div
                  ref={isMobile ? historyFilterRef : undefined}
                  style={{
                    marginLeft: "auto",
                    position: "relative",
                  }}
                >
                  <button
                    onClick={() => setHistoryFilterOpen((v) => !v)}
                    style={toggleBtnStyle(!!historyLocation || historyFilterOpen)}
                  >
                    Filter{historyLocation ? " \u2022" : ""}
                  </button>
                  {historyFilterOpen && (
                    <div style={{ ...dropdownStyle, left: "auto", right: 0, transform: "none", minWidth: 220 }}>
                      <HistoryFilterContent
                        locations={historyLocations}
                        selected={historyLocation}
                        onSelect={setHistoryLocation}
                      />
                    </div>
                  )}
                </div>
              )}
            </>
          )}
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
          setTodayOnly={setTodayOnly}
          user={user}
        />
      )}
      {activeTab === "cellar" && (
        showHistory
          ? (historyData ? <HistoryTab wines={filteredHistoryWines} selectedLocation={historyLocation} user={user} /> : <UploadButton inline onImportComplete={handleImport} />)
          : (cellarData ? <CellarTab data={cellarData} activeYear={cellarYear} activeVintage={cellarVintage} onYearChange={setCellarYear} user={user} /> : <UploadButton inline onImportComplete={handleImport} />)
      )}
      {activeTab === "blog" && <BlogTab user={user} />}
      {activeTab === "auction" && <AuctionTab search={auctionSearch} />}
      {activeTab === "profile" && <ProfileTab user={user} onSignIn={signInWithApple} onSignOut={signOutUser} onImportComplete={handleImport} onClearData={handleClearData} />}
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
