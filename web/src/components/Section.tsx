interface SectionProps {
  title: string;
  children: React.ReactNode;
  last?: boolean;
}

export function Section({ title, children, last }: SectionProps) {
  return (
    <div style={{ marginBottom: last ? 0 : 40 }}>
      <h2 style={{
        fontSize: 13,
        fontWeight: 600,
        textTransform: "uppercase",
        letterSpacing: "0.08em",
        color: "var(--text-muted)",
        marginBottom: 12,
        marginTop: 0,
      }}>
        {title}
      </h2>
      <div style={{ fontSize: 15, lineHeight: 1.75, color: "var(--text)" }}>
        {children}
      </div>
      {!last && (
        <div style={{ height: 1, background: "var(--border)", marginTop: 40 }} />
      )}
    </div>
  );
}
