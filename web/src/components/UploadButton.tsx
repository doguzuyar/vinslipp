"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import {
  getGitHubToken,
  setGitHubToken,
  clearGitHubToken,
  commitFiles,
  validateToken,
  STEP_LABELS,
  type UploadStep,
  type FileToCommit,
} from "@/lib/github";

const REQUIRED_FILES = ["cellar.csv", "user_prices.csv", "full_wine_list.csv"];

type Phase =
  | "idle"
  | "settings"
  | "ready"
  | "uploading"
  | "done"
  | "error";

export function UploadButton() {
  const [open, setOpen] = useState(false);
  const [phase, setPhase] = useState<Phase>("idle");
  const [step, setStep] = useState<UploadStep | null>(null);
  const [errorMsg, setErrorMsg] = useState("");
  const [tokenInput, setTokenInput] = useState("");
  const [hasToken, setHasToken] = useState(false);
  const [mounted, setMounted] = useState(false);
  const [files, setFiles] = useState<Map<string, string>>(new Map());
  const panelRef = useRef<HTMLDivElement>(null);
  const folderRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setHasToken(!!getGitHubToken());
    setMounted(true);
  }, []);

  // Close panel on outside click
  useEffect(() => {
    if (!open) return;
    function handleClick(e: MouseEvent) {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open]);

  const toggle = useCallback(() => {
    if (!open) {
      const token = getGitHubToken();
      setPhase(token ? "ready" : "settings");
      setFiles(new Map());
      setStep(null);
      setErrorMsg("");
    }
    setOpen((prev) => !prev);
  }, [open]);

  async function handleSaveToken() {
    const trimmed = tokenInput.trim();
    if (!trimmed) return;
    const valid = await validateToken(trimmed);
    if (!valid) {
      setErrorMsg("Invalid token or no access to repo.");
      return;
    }
    setGitHubToken(trimmed);
    setHasToken(true);
    setTokenInput("");
    setErrorMsg("");
    setPhase("ready");
  }

  function handleRemoveToken() {
    clearGitHubToken();
    setHasToken(false);
    setPhase("settings");
    setFiles(new Map());
  }

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
      if (REQUIRED_FILES.includes(basename)) {
        newFiles.set(basename, await f.text());
      }
    }
    setFiles(newFiles);
  }

  const allPresent = REQUIRED_FILES.every((f) => files.has(f));

  async function handleUpload() {
    const token = getGitHubToken();
    if (!token || !allPresent) return;

    setPhase("uploading");
    setStep("reading_files");
    setErrorMsg("");

    const toCommit: FileToCommit[] = REQUIRED_FILES.filter((f) =>
      files.has(f)
    ).map((f) => ({
      path: `vivino_data/${f}`,
      content: files.get(f)!,
    }));

    try {
      await commitFiles(token, toCommit, "chore: update Vivino data", (s) =>
        setStep(s)
      );
      setPhase("done");
    } catch (err) {
      setPhase("error");
      setStep("error");
      setErrorMsg(err instanceof Error ? err.message : "Unknown error");
    }
  }

  if (!mounted) return null;

  const maskedToken = hasToken
    ? `ghp_\u2026${getGitHubToken()?.slice(-4) ?? ""}`
    : "";

  return (
    <div ref={panelRef} style={{ position: "relative" }}>
      <button
        onClick={toggle}
        title="Upload Vivino data"
        style={{
          background: "var(--bg-alt)",
          border: "none",
          borderRadius: 8,
          padding: "6px 14px",
          cursor: "pointer",
          fontSize: 12,
          fontWeight: 500,
          color: "var(--text-muted)",
          transition: "all 0.15s ease",
        }}
      >
        Upload Vivino Data
      </button>

      {open && (
        <div
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
          {/* --- Settings: enter token --- */}
          {phase === "settings" && (
            <div>
              <div style={{ fontSize: 13, marginBottom: 10, color: "var(--text-muted)" }}>
                Enter a GitHub PAT with <strong>Contents</strong> write access:
              </div>
              <input
                type="password"
                placeholder="ghp_..."
                value={tokenInput}
                onChange={(e) => setTokenInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSaveToken()}
                style={{
                  width: "100%",
                  padding: "8px 12px",
                  border: "1px solid var(--border)",
                  borderRadius: 8,
                  fontSize: 13,
                  background: "var(--input-bg)",
                  color: "var(--text)",
                  boxSizing: "border-box",
                  outline: "none",
                }}
              />
              <button
                onClick={handleSaveToken}
                style={{
                  marginTop: 10,
                  padding: "8px 20px",
                  border: "none",
                  borderRadius: 8,
                  background: "var(--tab-active-bg)",
                  color: "var(--tab-active-text)",
                  cursor: "pointer",
                  fontSize: 13,
                  fontWeight: 500,
                  transition: "opacity 0.15s ease",
                }}
              >
                Save
              </button>
              {errorMsg && (
                <div style={{ color: "#dc2626", fontSize: 12, marginTop: 8 }}>
                  {errorMsg}
                </div>
              )}
            </div>
          )}

          {/* --- Ready: pick files --- */}
          {phase === "ready" && (
            <div>
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
                {REQUIRED_FILES.map((f) => (
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
                    <span>{f}</span>
                    <span>{files.has(f) ? "\u2713" : "\u2014"}</span>
                  </div>
                ))}
              </div>

              <button
                onClick={handleUpload}
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
                Upload to GitHub
              </button>

              {/* Token info */}
              <div
                style={{
                  marginTop: 14,
                  paddingTop: 12,
                  borderTop: "1px solid var(--border)",
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  fontSize: 11,
                  color: "var(--text-muted)",
                }}
              >
                <span>Token: {maskedToken}</span>
                <button
                  onClick={handleRemoveToken}
                  style={{
                    background: "none",
                    border: "none",
                    color: "#dc2626",
                    cursor: "pointer",
                    fontSize: 11,
                    textDecoration: "underline",
                  }}
                >
                  Remove
                </button>
              </div>
            </div>
          )}

          {/* --- Uploading: progress --- */}
          {phase === "uploading" && step && (
            <div style={{ fontSize: 13, color: "var(--text)" }}>
              <div style={{ marginBottom: 8, fontWeight: 500 }}>
                Uploading{"\u2026"}
              </div>
              {(
                [
                  "reading_files",
                  "creating_blobs",
                  "creating_tree",
                  "creating_commit",
                  "updating_ref",
                ] as UploadStep[]
              ).map((s) => {
                const isCurrent = s === step;
                const orderedSteps: UploadStep[] = [
                  "reading_files",
                  "creating_blobs",
                  "creating_tree",
                  "creating_commit",
                  "updating_ref",
                ];
                const isDone =
                  orderedSteps.indexOf(s) < orderedSteps.indexOf(step);
                return (
                  <div
                    key={s}
                    style={{
                      padding: "4px 0",
                      fontSize: 12,
                      color: isDone
                        ? "var(--text-muted)"
                        : isCurrent
                          ? "var(--text)"
                          : "var(--text-muted)",
                      fontWeight: isCurrent ? 500 : 400,
                    }}
                  >
                    {isDone ? "\u2713" : isCurrent ? "\u25B6" : "\u25CB"}{" "}
                    {STEP_LABELS[s]}
                  </div>
                );
              })}
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
                {"\u2713"} Upload complete!
              </div>
              <div style={{ color: "var(--text-muted)", fontSize: 12 }}>
                The site will rebuild automatically in ~2 minutes.
              </div>
              <button
                onClick={() => {
                  setPhase("ready");
                  setFiles(new Map());
                  setStep(null);
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
                Upload again
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
                Upload failed
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
                  setStep(null);
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
        </div>
      )}
    </div>
  );
}
