"use client";

import { useState } from "react";

interface Props {
  score: number;
  reason: string;
}

export function RatingStars({ score, reason }: Props) {
  const [hover, setHover] = useState(false);

  return (
    <span
      className="rating-cell"
      style={{ position: "relative", display: "block", width: "100%", height: "100%" }}
      onMouseEnter={() => reason && setHover(true)}
      onMouseLeave={() => setHover(false)}
    >
      {"\u2605".repeat(score)}
      {hover && (
        <span
          style={{
            position: "absolute",
            top: "100%",
            right: 0,
            background: "var(--th-bg)",
            color: "var(--th-text)",
            padding: "6px 12px",
            borderRadius: 6,
            fontSize: 12,
            fontStyle: "italic",
            whiteSpace: "nowrap",
            pointerEvents: "none",
            zIndex: 50,
            marginTop: 4,
            boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
          }}
        >
          {reason}
        </span>
      )}
    </span>
  );
}
