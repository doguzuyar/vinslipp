"use client";

import { useState, useRef, useEffect, useCallback, type ReactNode } from "react";

interface PopupPos {
  top: number;
  left: number;
  width: number;
}

export function useRowPopup() {
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [popupPos, setPopupPos] = useState<PopupPos | null>(null);
  const popupRef = useRef<HTMLDivElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  // Close popup on click outside
  useEffect(() => {
    if (!expandedId) return;
    function handleClick(e: MouseEvent) {
      if (popupRef.current && !popupRef.current.contains(e.target as Node)) {
        setExpandedId(null);
        setPopupPos(null);
      }
    }
    document.addEventListener("click", handleClick);
    return () => document.removeEventListener("click", handleClick);
  }, [expandedId]);

  // Close popup on scroll
  useEffect(() => {
    if (!expandedId) return;
    const el = scrollRef.current;
    if (!el) return;
    function handleScroll() {
      setExpandedId(null);
      setPopupPos(null);
    }
    el.addEventListener("scroll", handleScroll);
    return () => el.removeEventListener("scroll", handleScroll);
  }, [expandedId]);

  const handleRowClick = useCallback(
    (id: string, e: React.MouseEvent<HTMLTableRowElement>) => {
      if (expandedId) {
        setExpandedId(null);
        setPopupPos(null);
      } else {
        const row = e.currentTarget as HTMLElement;
        const rect = row.getBoundingClientRect();
        const scrollRect = scrollRef.current?.getBoundingClientRect();
        if (scrollRect) {
          setPopupPos({
            top: rect.bottom - scrollRect.top + (scrollRef.current?.scrollTop || 0),
            left: rect.left - scrollRect.left + rect.width / 2,
            width: rect.width,
          });
        }
        setExpandedId(id);
      }
    },
    [expandedId],
  );

  return { expandedId, popupPos, popupRef, scrollRef, handleRowClick };
}

interface LinkItem {
  label: string;
  href?: string;
}

interface RowPopupProps {
  popupRef: React.RefObject<HTMLDivElement | null>;
  popupPos: PopupPos;
  links: LinkItem[];
  children?: ReactNode;
}

const linkStyle: React.CSSProperties = {
  padding: "4px 10px",
  background: "var(--bg-alt)",
  color: "var(--text-muted)",
  borderRadius: 6,
  fontSize: 12,
  textDecoration: "none",
  transition: "all 0.15s ease",
};

export function RowPopup({ popupRef, popupPos, links, children }: RowPopupProps) {
  return (
    <div
      ref={popupRef}
      style={{
        position: "absolute",
        top: popupPos.top + 4,
        left: popupPos.left,
        transform: "translateX(-50%)",
        background: "var(--bg)",
        border: "1px solid var(--border)",
        borderRadius: 12,
        padding: 12,
        display: "flex",
        flexDirection: "column",
        gap: 12,
        zIndex: 300,
        boxShadow: "0 4px 20px rgba(0,0,0,0.12)",
      }}
    >
      <div style={{ display: "flex", gap: 12 }}>
        {links.map((link) =>
          link.href ? (
            <a
              key={link.label}
              href={link.href}
              target="_blank"
              rel="noreferrer"
              style={linkStyle}
            >
              {link.label}
            </a>
          ) : (
            <span key={link.label} style={linkStyle}>
              {link.label}
            </span>
          ),
        )}
      </div>
      {children}
    </div>
  );
}
