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
      <img
        src="/icon.png"
        alt="Vinslipp"
        width={80}
        height={80}
        style={{ borderRadius: 18 }}
      />

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
                display: "block",
                position: i === 0 ? "relative" : "absolute",
                top: 0,
                left: 0,
                opacity: current === i ? 1 : 0,
                transition: "opacity 0.6s ease-in-out",
              }}
            />
          ))}
        </div>
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

      <a
        href="https://apps.apple.com/app/vinslipp/id6758891213"
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
        <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
          <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
        </svg>
        Download on the App Store
      </a>

      <div
        style={{
          display: "flex",
          gap: 16,
          fontSize: 12,
          color: "var(--text-muted)",
          opacity: 0.4,
          marginTop: 16,
        }}
      >
        <a href="/privacy" style={{ color: "inherit", textDecoration: "none" }}>
          Privacy
        </a>
        <a href="/support" style={{ color: "inherit", textDecoration: "none" }}>
          Support
        </a>
      </div>

      <a
        href="https://www.instagram.com/vinslipp"
        target="_blank"
        rel="noopener noreferrer"
        style={{ color: "var(--text-muted)", opacity: 0.4, display: "inline-flex" }}
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
        </svg>
      </a>
    </main>
  );
}
