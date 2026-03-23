interface PageLayoutProps {
  title: string;
  subtitle: string;
  children: React.ReactNode;
}

export function PageLayout({ title, subtitle, children }: PageLayoutProps) {
  return (
    <div style={{
      maxWidth: 640,
      margin: "0 auto",
      padding: "60px 24px 80px",
      color: "var(--text)",
    }}>
      <h1 style={{ fontSize: 28, fontWeight: 600, marginBottom: 6, letterSpacing: "-0.02em" }}>
        {title}
      </h1>
      <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 48, marginTop: 0 }}>
        {subtitle}
      </p>
      {children}
    </div>
  );
}
