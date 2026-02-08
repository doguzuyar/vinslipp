"use client";

import { useState, useEffect, useRef, useCallback } from "react";

const UNLOCK_HASH = "89f1c21f5a49bf50434dd8fdcc9b51c2185678499f9380f19a35f90a176eaeb3";

async function sha256(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const buf = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function DarkModeToggle({ onUnlockChange }: { onUnlockChange?: (unlocked: boolean) => void }) {
  const [dark, setDark] = useState(false);
  const [mounted, setMounted] = useState(false);
  const [showInput, setShowInput] = useState(false);
  const [code, setCode] = useState("");
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setDark(document.documentElement.classList.contains("dark"));
    setMounted(true);
  }, []);

  useEffect(() => {
    if (showInput && inputRef.current) {
      inputRef.current.focus();
    }
  }, [showInput]);

  function toggle() {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    localStorage.setItem("darkMode", next ? "1" : "0");
  }

  const startPress = useCallback(() => {
    timerRef.current = setTimeout(() => {
      setShowInput(true);
    }, 1500);
  }, []);

  const endPress = useCallback(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const hash = await sha256(code);
    if (hash === UNLOCK_HASH) {
      localStorage.setItem("unlocked", "1");
      onUnlockChange?.(true);
      setShowInput(false);
      setCode("");
    } else if (code.toLowerCase() === "lock") {
      localStorage.removeItem("unlocked");
      onUnlockChange?.(false);
      setShowInput(false);
      setCode("");
    } else {
      setCode("");
    }
  }

  return (
    <span style={{ position: "relative", display: "inline-block" }}>
      <button
        onClick={toggle}
        onMouseDown={startPress}
        onMouseUp={endPress}
        onMouseLeave={endPress}
        onTouchStart={startPress}
        onTouchEnd={endPress}
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
      {showInput && (
        <form
          onSubmit={handleSubmit}
          style={{
            position: "absolute",
            top: "100%",
            right: 0,
            marginTop: 6,
            zIndex: 1000,
          }}
        >
          <input
            ref={inputRef}
            type="password"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            onBlur={() => { setShowInput(false); setCode(""); }}
            placeholder="Code"
            style={{
              padding: "6px 10px",
              border: "1px solid var(--border)",
              borderRadius: 8,
              fontSize: 12,
              background: "var(--input-bg)",
              color: "var(--text)",
              width: 120,
              outline: "none",
            }}
          />
        </form>
      )}
    </span>
  );
}
