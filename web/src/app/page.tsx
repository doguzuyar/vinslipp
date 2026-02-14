"use client";

import { useState, useEffect } from "react";

const screenshots = [
  { src: "/screenshot-releases.png", alt: "Releases" },
  { src: "/screenshot-cellar.png", alt: "Cellar" },
  { src: "/screenshot-auction.png", alt: "Auction" },
];

export default function Home() {
  const [current, setCurrent] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrent((i) => (i + 1) % screenshots.length);
    }, 4000);
    return () => clearInterval(timer);
  }, []);

  return (
    <main
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        minHeight: "100dvh",
        padding: "48px 24px",
        textAlign: "center",
        gap: "32px",
      }}
    >
      {/* App Icon */}
      <img
        src="/icon.svg"
        alt="Vinslipp"
        width={80}
        height={80}
        style={{ borderRadius: 18 }}
      />

      {/* Title & Tagline */}
      <div>
        <h1
          style={{
            fontSize: 36,
            fontWeight: 600,
            letterSpacing: "-0.02em",
            margin: 0,
            color: "var(--text)",
          }}
        >
          Vinslipp
        </h1>
        <p
          style={{
            fontSize: 16,
            color: "var(--text-muted)",
            margin: "8px 0 0",
            fontWeight: 300,
            maxWidth: 420,
          }}
        >
          Releases, cellar &amp; auction insights for wine lovers
        </p>
      </div>

      {/* iPhone 17 Pro Max Mockup */}
      <div
        style={{
          position: "relative",
          width: 260,
          padding: 4,
          borderRadius: 36,
          background: "#1a1a1a",
          boxShadow: "0 0 0 1.5px #444, 0 20px 60px rgba(0,0,0,0.5)",
        }}
      >
        {/* Dynamic Island */}
        <div
          style={{
            position: "absolute",
            top: 12,
            left: "50%",
            transform: "translateX(-50%)",
            width: 72,
            height: 22,
            borderRadius: 11,
            background: "#000",
            zIndex: 2,
          }}
        />
        {/* Screen */}
        <div
          style={{
            borderRadius: 32,
            overflow: "hidden",
            background: "#000",
            position: "relative",
          }}
        >
          {screenshots.map((s, i) => (
            <img
              key={s.src}
              src={s.src}
              alt={s.alt}
              style={{
                width: "100%",
                height: "auto",
                display: i === 0 ? "block" : "none",
                position: i === 0 ? "relative" : "absolute",
                top: 0,
                left: 0,
                opacity: current === i ? 1 : 0,
                transition: "opacity 0.6s ease-in-out",
                ...(i !== 0 ? { display: "block" } : {}),
              }}
            />
          ))}
        </div>
        {/* Home Indicator */}
        <div
          style={{
            position: "absolute",
            bottom: 10,
            left: "50%",
            transform: "translateX(-50%)",
            width: 96,
            height: 4,
            borderRadius: 2,
            background: "rgba(255,255,255,0.15)",
          }}
        />
      </div>

      {/* Dots */}
      <div style={{ display: "flex", gap: 8 }}>
        {screenshots.map((s, i) => (
          <button
            key={s.src}
            onClick={() => setCurrent(i)}
            style={{
              width: 8,
              height: 8,
              borderRadius: "50%",
              border: "none",
              padding: 0,
              cursor: "pointer",
              background: current === i ? "var(--text)" : "var(--border)",
              transition: "background 0.3s",
            }}
          />
        ))}
      </div>

      {/* App Store Link */}
      <a
        href="#"
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 8,
          padding: "12px 24px",
          borderRadius: 12,
          background: "var(--text)",
          color: "var(--bg)",
          textDecoration: "none",
          fontSize: 14,
          fontWeight: 500,
          transition: "opacity 0.15s",
        }}
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
        </svg>
        Download on the App Store
      </a>

      {/* Footer */}
      <p
        style={{
          fontSize: 12,
          color: "var(--text-muted)",
          opacity: 0.4,
          marginTop: 16,
        }}
      >
        Vinslipp
      </p>
    </main>
  );
}
