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
  const lastDay = new Date(year, month + 1, 0).getDate();
  let startDay = new Date(year, month, 1).getDay() - 1;
  if (startDay < 0) startDay = 6;

  const days: (string | null)[] = [];
  for (let i = 0; i < startDay; i++) days.push(null);
  for (let d = 1; d <= lastDay; d++) {
    days.push(`${year}-${pad(month + 1)}-${pad(d)}`);
  }
  return days;
}

function offsetMonth(year: number, month: number, offset: number) {
  const d = new Date(year, month + offset, 1);
  return { year: d.getFullYear(), month: d.getMonth() };
}

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

const SHORT_MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

function MonthGrid({
  year,
  month,
  dateColors,
  selectedDate,
  today,
  onSelectDate,
  compact,
  hideTitle,
}: {
  year: number;
  month: number;
  dateColors: Record<string, string>;
  selectedDate: string | null;
  today: string;
  onSelectDate: (date: string | null) => void;
  compact?: boolean;
  hideTitle?: boolean;
}) {
  const days = useMemo(() => getMonthDays(year, month), [year, month]);

  return (
    <div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 2 }}>
        {DAYS.map((d) => (
          <div key={d} style={{ textAlign: "center", fontSize: compact ? 10 : 10, color: "var(--text-muted)", padding: "2px 0", fontWeight: 500 }}>
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
              onClick={() => (color || isToday) ? onSelectDate(isSelected ? null : dateStr) : undefined}
              style={{
                textAlign: "center",
                fontSize: compact ? 13 : 12,
                padding: compact ? "5px 0" : "8px 0",
                cursor: (color || isToday) ? "pointer" : "default",
                borderRadius: 6,
                position: "relative",
                fontWeight: isToday ? 700 : 400,
                color: isSelected ? "#fff" : color ? "var(--text)" : "var(--text-muted)",
                background: isSelected ? (color || "var(--th-bg)") : "transparent",
                opacity: (color || isToday) ? 1 : 0.4,
                boxShadow: isToday && !isSelected ? "inset 0 0 0 2px var(--th-bg)" : "none",
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
      {!hideTitle && (
        <div style={{ textAlign: "center", fontSize: compact ? 13 : 14, fontWeight: 600, marginTop: 6 }}>
          {MONTH_NAMES[month]} {year}
        </div>
      )}
    </div>
  );
}

export function MiniCalendar({ dateColors, selectedDate, onSelectDate }: Props) {
  const today = useMemo(() => new Date().toISOString().slice(0, 10), []);

  const [year, setYear] = useState(() => new Date().getFullYear());
  const [month, setMonth] = useState(() => new Date().getMonth());

  const prev = () => {
    const p = offsetMonth(year, month, -1);
    setYear(p.year);
    setMonth(p.month);
  };
  const next = () => {
    const n = offsetMonth(year, month, 1);
    setYear(n.year);
    setMonth(n.month);
  };

  const prevM = offsetMonth(year, month, -1);
  const nextM = offsetMonth(year, month, 1);

  return (
    <div style={{ padding: "20px 0 12px" }}>
      {/* Mobile: single month with arrows */}
      <div className="calendar-mobile">
        <MonthGrid year={year} month={month} dateColors={dateColors} selectedDate={selectedDate} today={today} onSelectDate={onSelectDate} hideTitle />
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8, marginTop: 4 }}>
          <span onClick={prev} style={{ cursor: "pointer", padding: "4px 8px", fontSize: 16, color: "var(--text-muted)", userSelect: "none" }}>
            ◀
          </span>
          <span style={{ fontSize: 14, fontWeight: 600, minWidth: 120, textAlign: "center" }}>
            {MONTH_NAMES[month]} {year}
          </span>
          <span onClick={next} style={{ cursor: "pointer", padding: "4px 8px", fontSize: 16, color: "var(--text-muted)", userSelect: "none" }}>
            ▶
          </span>
        </div>
      </div>

      {/* Desktop: 3 months side by side */}
      <div className="calendar-desktop">
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
          <span onClick={prev} style={{ cursor: "pointer", padding: "4px 8px", fontSize: 14, color: "var(--text-muted)", userSelect: "none" }}>
            ◀
          </span>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 64, maxWidth: 900 }}>
            <MonthGrid year={prevM.year} month={prevM.month} dateColors={dateColors} selectedDate={selectedDate} today={today} onSelectDate={onSelectDate} compact />
            <MonthGrid year={year} month={month} dateColors={dateColors} selectedDate={selectedDate} today={today} onSelectDate={onSelectDate} compact />
            <MonthGrid year={nextM.year} month={nextM.month} dateColors={dateColors} selectedDate={selectedDate} today={today} onSelectDate={onSelectDate} compact />
          </div>
          <span onClick={next} style={{ cursor: "pointer", padding: "4px 8px", fontSize: 14, color: "var(--text-muted)", userSelect: "none" }}>
            ▶
          </span>
        </div>
      </div>
    </div>
  );
}
