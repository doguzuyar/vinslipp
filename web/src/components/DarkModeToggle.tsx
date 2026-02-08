"use client";

import { useState, useEffect } from "react";

export function DarkModeToggle() {
  const [dark, setDark] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setDark(document.documentElement.classList.contains("dark"));
    setMounted(true);
  }, []);

  function toggle() {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    localStorage.setItem("darkMode", next ? "1" : "0");
  }

  return (
    <button
      onClick={toggle}
      title="Toggle dark mode"
      style={{
        background: "var(--bg-alt)",
        border: "none",
        borderRadius: 8,
        padding: "6px 10px",
        cursor: "pointer",
        fontSize: 14,
        color: "var(--text-muted)",
        transition: "all 0.15s ease",
        lineHeight: 1,
      }}
    >
      {mounted ? (dark ? "\u2600\uFE0F" : "\uD83C\uDF19") : "\uD83C\uDF19"}
    </button>
  );
}
