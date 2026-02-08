"use client";

interface Props {
  yearCounts: Record<string, number>;
  colorPalette: Record<string, string>;
  activeYear: string | null;
  onYearClick: (year: string) => void;
}

export function BottleChart({ yearCounts, colorPalette, activeYear, onYearClick }: Props) {
  const years = Object.keys(yearCounts).sort();
  const maxCount = Math.max(...Object.values(yearCounts));

  return (
    <div style={{ maxWidth: 500 }}>
      {years.map((year) => {
        const count = yearCounts[year];
        const width = Math.round((count / maxCount) * 100);
        const color = colorPalette[year] || "#ccc";
        const isActive = activeYear === year;
        const isDimmed = activeYear !== null && activeYear !== year;

        return (
          <div
            key={year}
            onClick={() => onYearClick(year)}
            style={{
              display: "flex",
              alignItems: "center",
              margin: "4px 0",
              cursor: "pointer",
              opacity: isDimmed ? 0.3 : isActive ? 1 : 0.85,
              borderRadius: 6,
              padding: "3px 6px",
              background: isActive ? "var(--bg-alt)" : "transparent",
              transition: "all 0.15s ease",
            }}
          >
            <span
              style={{
                width: 50,
                minWidth: 50,
                flexShrink: 0,
                fontWeight: 500,
                fontSize: 13,
                textAlign: "right",
                marginRight: 10,
              }}
            >
              {year}
            </span>
            <div
              className="bar"
              style={{
                height: 22,
                borderRadius: 5,
                minWidth: 5,
                width: `${width}%`,
                backgroundColor: color,
              }}
            />
            <span style={{ marginLeft: 10, fontWeight: 500, fontSize: 13, color: "var(--text-muted)" }}>{count}</span>
          </div>
        );
      })}
    </div>
  );
}
