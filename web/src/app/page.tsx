export default function Home() {
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
            maxWidth: 320,
          }}
        >
          Wine releases, cellar tracking &amp; auction insights
        </p>
      </div>

      {/* Phone Mockup */}
      <div
        style={{
          width: 220,
          height: 440,
          borderRadius: 32,
          border: "2px solid var(--border)",
          background: "var(--bg-alt)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Notch */}
        <div
          style={{
            position: "absolute",
            top: 8,
            left: "50%",
            transform: "translateX(-50%)",
            width: 60,
            height: 20,
            borderRadius: 10,
            background: "var(--bg)",
          }}
        />
        {/* Placeholder text */}
        <span
          style={{
            fontSize: 12,
            color: "var(--text-muted)",
            opacity: 0.5,
          }}
        >
          Screenshot
        </span>
        {/* Home indicator */}
        <div
          style={{
            position: "absolute",
            bottom: 8,
            left: "50%",
            transform: "translateX(-50%)",
            width: 48,
            height: 4,
            borderRadius: 2,
            background: "var(--border)",
          }}
        />
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
