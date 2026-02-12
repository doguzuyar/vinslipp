"use client";

import { useState, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import type { AuthUser } from "@/lib/firebase";
import { addBlogPost } from "@/lib/firebase";

export interface BlogWine {
  id: string;
  name: string;
  winery: string;
  vintage: string;
}

interface Props {
  wine: BlogWine;
  user: AuthUser | null;
  onClose: () => void;
  onPosted?: () => void;
}

export function BlogModal({ wine, user, onClose, onPosted }: Props) {
  const [comment, setComment] = useState("");
  const [posting, setPosting] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) {
        onClose();
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [onClose]);

  async function handlePost() {
    if (!user || !comment.trim()) return;
    setPosting(true);
    try {
      await addBlogPost({
        wineId: wine.id,
        wineName: wine.name,
        winery: wine.winery,
        vintage: wine.vintage,
        userId: user.uid,
        userName: user.displayName || "Anonymous",
        comment: comment.trim(),
      });
      onPosted?.();
      onClose();
    } catch {
      setPosting(false);
    }
  }

  return createPortal(
    <div
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(0,0,0,0.5)",
        zIndex: 9999,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        ref={panelRef}
        style={{
          background: "var(--bg)",
          border: "1px solid var(--border)",
          borderRadius: 14,
          padding: 20,
          width: "min(400px, 90vw)",
          display: "flex",
          flexDirection: "column",
          gap: 16,
        }}
      >
        <div>
          <div style={{ fontSize: 16, fontWeight: 600, color: "var(--text)" }}>
            {wine.winery}
          </div>
          <div style={{ fontSize: 13, color: "var(--text-muted)" }}>
            {wine.name} {wine.vintage}
          </div>
        </div>

        {user ? (
          <>
            <textarea
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder="Write your tasting note..."
              rows={4}
              style={{
                width: "100%",
                padding: 12,
                border: "1px solid var(--border)",
                borderRadius: 10,
                background: "var(--input-bg)",
                color: "var(--text)",
                fontSize: 14,
                resize: "vertical",
                outline: "none",
                boxSizing: "border-box",
              }}
            />
            <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
              <button
                onClick={onClose}
                style={{
                  padding: "8px 16px",
                  background: "var(--bg-alt)",
                  color: "var(--text-muted)",
                  border: "none",
                  borderRadius: 8,
                  fontSize: 13,
                  cursor: "pointer",
                }}
              >
                Cancel
              </button>
              <button
                onClick={handlePost}
                disabled={!comment.trim() || posting}
                style={{
                  padding: "8px 16px",
                  background: comment.trim() && !posting ? "var(--tab-active-bg)" : "var(--bg-alt)",
                  color: comment.trim() && !posting ? "var(--tab-active-text)" : "var(--text-muted)",
                  border: "none",
                  borderRadius: 8,
                  fontSize: 13,
                  fontWeight: 500,
                  cursor: comment.trim() && !posting ? "pointer" : "default",
                  transition: "all 0.15s ease",
                }}
              >
                {posting ? "Posting..." : "Post"}
              </button>
            </div>
          </>
        ) : (
          <div style={{ fontSize: 13, color: "var(--text-muted)", textAlign: "center", padding: 20 }}>
            Sign in to write a tasting note
          </div>
        )}
      </div>
    </div>,
    document.body,
  );
}
