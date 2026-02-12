"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { createPortal } from "react-dom";
import { processCellar, processHistory } from "@/lib/vivino";
import type { CellarData, HistoryData } from "@/types";

const REQUIRED_FILES = ["cellar.csv", "full_wine_list.csv"];
const OPTIONAL_FILES = ["user_prices.csv"];
const ALL_FILES = [...REQUIRED_FILES, ...OPTIONAL_FILES];

type Phase = "ready" | "processing" | "done" | "error";

interface Props {
  onImportComplete: (cellar: CellarData, history: HistoryData) => void;
  onClearData?: () => void;
  /** When true, renders as inline empty-state panel instead of button+modal */
  inline?: boolean;
}

export function UploadButton({ onImportComplete, onClearData, inline }: Props) {
  const [open, setOpen] = useState(false);
  const [phase, setPhase] = useState<Phase>("ready");
  const [errorMsg, setErrorMsg] = useState("");
  const [files, setFiles] = useState<Map<string, string>>(new Map());
  const [isNativeApp, setIsNativeApp] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);
  const folderRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setIsNativeApp(!!(window as /* eslint-disable-line */ any).webkit?.messageHandlers?.tabSwitch);
  }, []);

  // Close panel on outside click
  useEffect(() => {
    if (!open || inline) return;
    function handleClick(e: MouseEvent) {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open, inline]);

  const toggle = useCallback(() => {
    if (!open) {
      setPhase("ready");
      setFiles(new Map());
      setErrorMsg("");
    }
    setOpen((prev) => !prev);
  }, [open]);

  async function handleFiles(fileList: FileList | null) {
    if (!fileList || fileList.length === 0) return;
    const newFiles = new Map<string, string>();

    for (let i = 0; i < fileList.length; i++) {
      const f = fileList[i];
      if (!f.name.endsWith(".csv")) continue;
      const path = f.webkitRelativePath || f.name;
      const basename = path.includes("/")
        ? path.slice(path.lastIndexOf("/") + 1)
        : path;
      if (ALL_FILES.includes(basename)) {
        newFiles.set(basename, await f.text());
      }
    }
    setFiles(newFiles);
  }

  async function handleSingleFile(expectedName: string, fileList: FileList | null) {
    if (!fileList || fileList.length === 0) return;
    const f = fileList[0];
    const content = await f.text();
    setFiles((prev) => {
      const next = new Map(prev);
      next.set(expectedName, content);
      return next;
    });
  }

  const allPresent = REQUIRED_FILES.every((f) => files.has(f));

  async function handleImport() {
    if (!allPresent) return;
    setPhase("processing");
    setErrorMsg("");

    try {
      const cellar = processCellar(
        files.get("cellar.csv")!,
        files.get("user_prices.csv") ?? null,
      );
      const history = processHistory(files.get("full_wine_list.csv")!);
      setPhase("done");
      onImportComplete(cellar, history);
    } catch (err) {
      setPhase("error");
      setErrorMsg(err instanceof Error ? err.message : "Failed to process CSV data");
    }
  }

  // Shared panel content
  const panelContent = (
    <>
      {/* --- Ready: pick files --- */}
      {phase === "ready" && (
        <div>
          {isNativeApp ? (
            <>
              <div style={{ fontSize: 13, marginBottom: 10, color: "var(--text-muted)" }}>
                Select each CSV file from your Vivino export:
              </div>
              {ALL_FILES.map((f) => (
                <div key={f} style={{ marginBottom: 8 }}>
                  <label
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: "10px 12px",
                      border: files.has(f) ? "1.5px solid #16a34a" : "1.5px dashed var(--border)",
                      borderRadius: 8,
                      cursor: "pointer",
                      fontSize: 12,
                      color: files.has(f) ? "var(--text)" : "var(--text-muted)",
                      transition: "all 0.15s ease",
                    }}
                  >
                    <span>
                      {f}
                      {OPTIONAL_FILES.includes(f) && (
                        <span style={{ fontSize: 10, marginLeft: 4 }}>(optional)</span>
                      )}
                    </span>
                    <span>{files.has(f) ? "\u2713" : "Choose"}</span>
                    <input
                      type="file"
                      accept=".csv"
                      onChange={(e) => handleSingleFile(f, e.target.files)}
                      style={{ display: "none" }}
                    />
                  </label>
                </div>
              ))}
            </>
          ) : (
            <>
              <div style={{ fontSize: 13, marginBottom: 10, color: "var(--text-muted)" }}>
                Upload Vivino export folder:
              </div>
              <input
                ref={folderRef}
                type="file"
                {...({ webkitdirectory: "", directory: "" } as React.InputHTMLAttributes<HTMLInputElement>)}
                onChange={(e) => handleFiles(e.target.files)}
                style={{ display: "none" }}
              />
              <button
                onClick={() => folderRef.current?.click()}
                style={{
                  width: "100%",
                  padding: "12px",
                  border: "2px dashed var(--border)",
                  borderRadius: 10,
                  background: "transparent",
                  color: "var(--text-muted)",
                  cursor: "pointer",
                  fontSize: 13,
                  transition: "border-color 0.15s ease",
                }}
              >
                Choose folder
              </button>

              {/* Validation checklist */}
              <div style={{ marginTop: 12 }}>
                {ALL_FILES.map((f) => (
                  <div
                    key={f}
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      fontSize: 12,
                      padding: "4px 0",
                      color: files.has(f) ? "var(--text)" : "var(--text-muted)",
                    }}
                  >
                    <span>
                      {f}
                      {OPTIONAL_FILES.includes(f) && (
                        <span style={{ fontSize: 10, marginLeft: 4 }}>(optional)</span>
                      )}
                    </span>
                    <span>{files.has(f) ? "\u2713" : "\u2014"}</span>
                  </div>
                ))}
              </div>
            </>
          )}

          <button
            onClick={handleImport}
            disabled={!allPresent}
            style={{
              marginTop: 12,
              width: "100%",
              padding: "10px",
              border: "none",
              borderRadius: 8,
              background: allPresent
                ? "var(--tab-active-bg)"
                : "var(--border)",
              color: allPresent
                ? "var(--tab-active-text)"
                : "var(--text-muted)",
              cursor: allPresent ? "pointer" : "default",
              fontSize: 13,
              fontWeight: 500,
              transition: "all 0.15s ease",
            }}
          >
            Import
          </button>

          {onClearData && (
            <div style={{ marginTop: 14, paddingTop: 12, borderTop: "1px solid var(--border)", textAlign: "center" }}>
              <button
                onClick={() => { onClearData(); setOpen(false); }}
                style={{
                  background: "none",
                  border: "none",
                  color: "#dc2626",
                  cursor: "pointer",
                  fontSize: 11,
                  textDecoration: "underline",
                }}
              >
                Clear data
              </button>
            </div>
          )}
        </div>
      )}

      {/* --- Processing --- */}
      {phase === "processing" && (
        <div style={{ fontSize: 13, color: "var(--text)" }}>
          <div style={{ fontWeight: 500 }}>Processing{"\u2026"}</div>
        </div>
      )}

      {/* --- Done --- */}
      {phase === "done" && (
        <div style={{ fontSize: 13 }}>
          <div
            style={{
              color: "#16a34a",
              fontWeight: 500,
              marginBottom: 8,
            }}
          >
            {"\u2713"} Import complete!
          </div>
          <div style={{ color: "var(--text-muted)", fontSize: 12 }}>
            Your wine data has been saved to this device.
          </div>
          <button
            onClick={() => {
              setPhase("ready");
              setFiles(new Map());
              setErrorMsg("");
            }}
            style={{
              marginTop: 12,
              padding: "8px 18px",
              border: "1px solid var(--border)",
              borderRadius: 8,
              background: "transparent",
              color: "var(--text)",
              cursor: "pointer",
              fontSize: 12,
              transition: "all 0.15s ease",
            }}
          >
            Import again
          </button>
        </div>
      )}

      {/* --- Error --- */}
      {phase === "error" && (
        <div style={{ fontSize: 13 }}>
          <div
            style={{
              color: "#dc2626",
              fontWeight: 500,
              marginBottom: 8,
            }}
          >
            Import failed
          </div>
          <div
            style={{
              color: "var(--text-muted)",
              fontSize: 12,
              wordBreak: "break-word",
            }}
          >
            {errorMsg}
          </div>
          <button
            onClick={() => {
              setPhase("ready");
              setErrorMsg("");
            }}
            style={{
              marginTop: 12,
              padding: "8px 18px",
              border: "1px solid var(--border)",
              borderRadius: 8,
              background: "transparent",
              color: "var(--text)",
              cursor: "pointer",
              fontSize: 12,
              transition: "all 0.15s ease",
            }}
          >
            Try again
          </button>
        </div>
      )}
    </>
  );

  // Inline mode: render panel content directly inside the tab area
  if (inline) {
    return (
      <div
        className="tab-scroll"
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          minHeight: 300,
        }}
      >
        <div style={{ width: 340, padding: 20 }}>
          <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 14, color: "var(--text)" }}>
            Import Vivino Data
          </div>
          {panelContent}
        </div>
      </div>
    );
  }

  // Button+modal mode
  return (
    <div style={{ width: "100%" }}>
      <button
        onClick={toggle}
        title="Import Vivino data"
        style={{
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
          textAlign: "left" as const,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
        }}
      >
        <span>Import Vivino Data</span>
        <span style={{ fontSize: 12, color: "var(--text-muted)" }}>{open ? "\u25B2" : "\u25BC"}</span>
      </button>

      {open && createPortal(
        <div
          ref={panelRef}
          style={{
            position: "fixed",
            left: "50%",
            top: "50%",
            transform: "translate(-50%, -50%)",
            background: "var(--bg)",
            border: "1px solid var(--border)",
            borderRadius: 12,
            padding: 20,
            width: 340,
            zIndex: 100,
            boxShadow: "0 8px 30px rgba(0,0,0,0.12)",
          }}
        >
          <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 14, color: "var(--text)" }}>
            Import Vivino Data
          </div>
          {panelContent}
        </div>,
        document.body,
      )}
    </div>
  );
}
