"use client";

import { useState, useEffect } from "react";

export function SplashOverlay() {
  const [phase, setPhase] = useState<"visible" | "animating" | "gone">("visible");

  useEffect(() => {
    // Brief pause then animate out
    const t1 = setTimeout(() => setPhase("animating"), 300);
    const t2 = setTimeout(() => setPhase("gone"), 1100);
    return () => { clearTimeout(t1); clearTimeout(t2); };
  }, []);

  if (phase === "gone") return null;

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 9999,
        background: "#ffffff",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        opacity: phase === "animating" ? 0 : 1,
        transition: "opacity 0.8s ease",
        pointerEvents: "none",
      }}
    >
      <svg
        viewBox="0 0 180 620"
        style={{
          width: 90,
          height: 310,
          transform: phase === "animating" ? "scale(1.15)" : "scale(1)",
          opacity: phase === "animating" ? 0 : 1,
          transition: "transform 0.8s ease, opacity 0.6s ease",
        }}
      >
        <defs>
          <linearGradient id="sp-shine" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="rgba(255,255,255,0.35)" />
            <stop offset="100%" stopColor="rgba(255,255,255,0)" />
          </linearGradient>
        </defs>
        <g transform="translate(90, 325)">
          <path
            d="M -16 -300 L -16 -200 C -16 -185 -30 -170 -55 -155 C -80 -140 -90 -120 -90 -100 L -90 260 C -90 280 -75 290 -55 290 L 55 290 C 75 290 90 280 90 260 L 90 -100 C 90 -120 80 -140 55 -155 C 30 -170 16 -185 16 -200 L 16 -300 Z"
            fill="#292524"
            stroke="#44403c"
            strokeWidth="2"
          />
          <rect x="-82" y="-100" width="16" height="360" rx="5" fill="url(#sp-shine)" opacity="0.7" />
          <rect x="-22" y="-325" width="44" height="45" rx="5" fill="#7f1d1d" />
          <rect x="-22" y="-325" width="44" height="6" rx="3" fill="#991b1b" />
          <rect x="-20" y="-282" width="40" height="6" rx="3" fill="#57534e" />
          <rect x="-60" y="10" width="120" height="120" rx="3" fill="#fafaf9" opacity="0.12" />
          <rect x="-38" y="35" width="76" height="3" rx="1.5" fill="#d6d3d1" opacity="0.4" />
          <rect x="-28" y="48" width="56" height="2" rx="1" fill="#d6d3d1" opacity="0.3" />
          <rect x="-44" y="75" width="88" height="2" rx="1" fill="#7f1d1d" opacity="0.7" />
          <rect x="-24" y="92" width="48" height="2" rx="1" fill="#d6d3d1" opacity="0.25" />
        </g>
      </svg>
    </div>
  );
}
