"use client";

import { useState, useEffect } from "react";
import type { AuthUser } from "@/lib/firebase";
import type { CellarData, HistoryData } from "@/types";
import { isNativeApp, setNotificationPreference, getNotificationPreference } from "@/lib/firebase";
import { DarkModeToggle } from "../DarkModeToggle";
import { UploadButton } from "../UploadButton";

interface Props {
  user: AuthUser | null;
  onSignIn: () => void;
  onSignOut: () => void;
  onImportComplete: (cellar: CellarData, history: HistoryData) => void;
  onClearData: () => void;
}

const NOTIFICATION_OPTIONS: { value: string; label: string }[] = [
  { value: "none", label: "None" },
  { value: "french-red", label: "French Red" },
  { value: "french-white", label: "French White" },
  { value: "italy-red", label: "Italy Red" },
  { value: "italy-white", label: "Italy White" },
];

const profileBtnStyle: React.CSSProperties = {
  width: "100%",
  padding: "12px 16px",
  background: "var(--bg-alt)",
  color: "var(--text)",
  border: "none",
  borderRadius: 10,
  fontSize: 14,
  fontWeight: 500,
  cursor: "pointer",
  transition: "opacity 0.15s ease",
  textAlign: "left",
  display: "flex",
  alignItems: "center",
  justifyContent: "space-between",
};

function NotificationButton() {
  const [open, setOpen] = useState(false);
  const [topic, setTopic] = useState("none");

  useEffect(() => {
    const cleanup = getNotificationPreference((t) => setTopic(t));
    return cleanup;
  }, []);

  function handleChange(value: string) {
    setTopic(value);
    setNotificationPreference(value);
  }

  const activeLabel = NOTIFICATION_OPTIONS.find((o) => o.value === topic)?.label || "None";

  return (
    <div style={{ width: "100%", maxWidth: 320 }}>
      <button onClick={() => setOpen((v) => !v)} style={profileBtnStyle}>
        <span>Notifications</span>
        <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
          {activeLabel} {open ? "\u25B2" : "\u25BC"}
        </span>
      </button>
      {open && (
        <div
          style={{
            marginTop: 8,
            display: "flex",
            flexDirection: "column",
            gap: 6,
          }}
        >
          <div style={{ fontSize: 12, color: "var(--text-muted)", marginBottom: 2, paddingLeft: 2 }}>
            Get notified when new wines are released
          </div>
          {NOTIFICATION_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => handleChange(opt.value)}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                padding: "10px 14px",
                background: topic === opt.value ? "var(--tab-active-bg)" : "var(--bg-alt)",
                color: topic === opt.value ? "var(--tab-active-text)" : "var(--text)",
                border: "none",
                borderRadius: 10,
                fontSize: 14,
                cursor: "pointer",
                transition: "background 0.15s ease, color 0.15s ease",
                textAlign: "left",
              }}
            >
              <span
                style={{
                  width: 18,
                  height: 18,
                  borderRadius: "50%",
                  border: topic === opt.value ? "none" : "2px solid var(--text-muted)",
                  background: topic === opt.value ? "var(--tab-active-text)" : "transparent",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  flexShrink: 0,
                }}
              >
                {topic === opt.value && (
                  <span
                    style={{
                      width: 8,
                      height: 8,
                      borderRadius: "50%",
                      background: "var(--tab-active-bg)",
                    }}
                  />
                )}
              </span>
              {opt.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

export function ProfileTab({ user, onSignIn, onSignOut, onImportComplete, onClearData }: Props) {
  if (!user) {
    return (
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          flex: 1,
          gap: 20,
          padding: 40,
        }}
      >
        <DarkModeToggle />
        <div style={{ fontSize: 14, color: "var(--text-muted)" }}>
          Sign in to sync your data across devices
        </div>
        <button
          onClick={onSignIn}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            padding: "12px 24px",
            background: "var(--tab-active-bg)",
            color: "var(--tab-active-text)",
            border: "none",
            borderRadius: 10,
            fontSize: 15,
            fontWeight: 500,
            cursor: "pointer",
            transition: "opacity 0.15s ease",
          }}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
            <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
          </svg>
          Sign in with Apple
        </button>
        <div style={{ width: "100%", maxWidth: 320, display: "flex", flexDirection: "column", gap: 12, marginTop: 10 }}>
          <NotificationButton />
          <UploadButton onImportComplete={onImportComplete} onClearData={onClearData} />
        </div>
      </div>
    );
  }

  const initial = (user.displayName || "?")[0].toUpperCase();

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        padding: 40,
        gap: 20,
      }}
    >
      <div
        style={{
          width: 64,
          height: 64,
          borderRadius: "50%",
          background: "var(--bg-alt)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 28,
          fontWeight: 600,
          color: "var(--text)",
        }}
      >
        {initial}
      </div>
      <div style={{ textAlign: "center" }}>
        <div style={{ fontSize: 18, fontWeight: 600, color: "var(--text)" }}>
          {user.displayName || "User"}
        </div>
      </div>
      <button
        onClick={onSignOut}
        style={{
          padding: "10px 24px",
          background: "var(--bg-alt)",
          color: "var(--text-muted)",
          border: "none",
          borderRadius: 10,
          fontSize: 14,
          cursor: "pointer",
          transition: "opacity 0.15s ease",
        }}
      >
        Sign Out
      </button>
      <div style={{ marginTop: 10 }}>
        <DarkModeToggle />
      </div>
      <div style={{ width: "100%", maxWidth: 320, display: "flex", flexDirection: "column", gap: 12, marginTop: 10 }}>
        <NotificationButton />
        <UploadButton onImportComplete={onImportComplete} onClearData={onClearData} />
      </div>
    </div>
  );
}
