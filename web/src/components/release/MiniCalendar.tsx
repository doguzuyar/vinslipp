"use client";

import { useState, useMemo } from "react";

interface Props {
  dateColors: Record<string, string>;
  selectedDate: string | null;
  onSelectDate: (date: string | null) => void;
}

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function pad(n: number) {
  return n < 10 ? `0${n}` : `${n}`;
}

function getMonthDays(year: number, month: number) {
  const first = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0).getDate();
  // Monday=0, Sunday=6
  let startDay = first.getDay() - 1;
  if (startDay < 0) startDay = 6;

  const days: (string | null)[] = [];
  for (let i = 0; i < startDay; i++) days.push(null);
  for (let d = 1; d <= lastDay; d++) {
    days.push(`${year}-${pad(month + 1)}-${pad(d)}`);
  }
  return days;
}

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

export function MiniCalendar({ dateColors, selectedDate, onSelectDate }: Props) {
  const today = useMemo(() => new Date().toISOString().slice(0, 10), []);

  const [year, setYear] = useState(() => {
    const d = new Date();
    return d.getFullYear();
  });
  const [month, setMonth] = useState(() => {
    const d = new Date();
    return d.getMonth();
  });

  const days = useMemo(() => getMonthDays(year, month), [year, month]);

  const prev = () => {
    if (month === 0) { setYear(year - 1); setMonth(11); }
    else setMonth(month - 1);
  };
  const next = () => {
    if (month === 11) { setYear(year + 1); setMonth(0); }
    else setMonth(month + 1);
  };

  return (
    <div style={{ padding: "8px 0 12px" }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12, marginBottom: 8 }}>
        <span onClick={prev} style={{ cursor: "pointer", padding: "4px 8px", fontSize: 14, color: "var(--text-muted)", userSelect: "none" }}>
          ◀
        </span>
        <span style={{ fontSize: 14, fontWeight: 600, minWidth: 120, textAlign: "center" }}>
          {MONTH_NAMES[month]} {year}
        </span>
        <span onClick={next} style={{ cursor: "pointer", padding: "4px 8px", fontSize: 14, color: "var(--text-muted)", userSelect: "none" }}>
          ▶
        </span>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 2, maxWidth: 280, margin: "0 auto" }}>
        {DAYS.map((d) => (
          <div key={d} style={{ textAlign: "center", fontSize: 10, color: "var(--text-muted)", padding: "2px 0", fontWeight: 500 }}>
            {d}
          </div>
        ))}
        {days.map((dateStr, i) => {
          if (!dateStr) return <div key={`empty-${i}`} />;
          const dayNum = parseInt(dateStr.slice(-2));
          const color = dateColors[dateStr];
          const isSelected = dateStr === selectedDate;
          const isToday = dateStr === today;
          return (
            <div
              key={dateStr}
              onClick={() => onSelectDate(isSelected ? null : dateStr)}
              style={{
                textAlign: "center",
                fontSize: 12,
                padding: "4px 0",
                cursor: color ? "pointer" : "default",
                borderRadius: 6,
                position: "relative",
                fontWeight: isToday ? 700 : 400,
                color: isSelected ? "#fff" : color ? "var(--text)" : "var(--text-muted)",
                background: isSelected ? (color || "var(--th-bg)") : "transparent",
                opacity: color ? 1 : 0.4,
              }}
            >
              {dayNum}
              {color && !isSelected && (
                <div style={{
                  width: 5,
                  height: 5,
                  borderRadius: "50%",
                  background: color,
                  margin: "1px auto 0",
                }} />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
