import { Section } from "@/components/Section";

export default function Support() {
  return (
    <div style={{
      maxWidth: 640,
      margin: "0 auto",
      padding: "60px 24px 80px",
      color: "var(--text)",
    }}>
      <h1 style={{ fontSize: 28, fontWeight: 600, marginBottom: 6, letterSpacing: "-0.02em" }}>
        Support
      </h1>
      <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 48, marginTop: 0 }}>
        Vinslipp | Systembolaget Release Tracker
      </p>

      <Section title="Contact">
        <p>
          For questions, feedback, or issues, email{" "}
          <a href="mailto:doguziylan@icloud.com" style={{ color: "var(--accent)", textDecoration: "none" }}>
            doguziylan@icloud.com
          </a>
          . We typically respond within 1 to 2 business days.
        </p>
      </Section>

      <Section title="Delete Your Account">
        <p>
          Open the app and go to the <strong>Profile</strong> tab. Scroll down and tap{" "}
          <strong>Delete Account</strong>. You will be asked to re-authenticate with Apple and
          confirm before deletion completes.
        </p>
        <Note>
          Deletion permanently removes your sign-in credentials and any tasting notes or blog posts
          you have published. This cannot be undone.
        </Note>
      </Section>

      <Section title="Frequently Asked Questions">
        <FAQ items={[
          {
            q: "Why is a wine missing from the releases list?",
            a: "The list is generated daily from Systembolaget's API. If a wine was added or updated after the last sync, it will appear the following day.",
          },
          {
            q: "How do I import my Vivino cellar?",
            a: "Export your data from Vivino (Account → Privacy → Download my data), then open the Profile tab in Vinslipp and tap Import Vivino data.",
          },
          {
            q: "Push notifications are not arriving.",
            a: "Make sure notifications are enabled for Vinslipp in iOS Settings. Then open the Profile tab, tap Notifications, and select your preferred wine category. If the issue persists, try toggling the setting off and back on.",
          },
          {
            q: "The auction data looks outdated.",
            a: "Bukowskis auction statistics are updated after each auction closes. The next scheduled update will appear automatically.",
          },
        ]} />
      </Section>

      <Section title="Privacy Policy" last>
        <p>
          Read our{" "}
          <a href="/privacy" style={{ color: "var(--accent)", textDecoration: "none" }}>
            Privacy Policy
          </a>{" "}
          for details on what data we collect and how it is used.
        </p>
      </Section>
    </div>
  );
}

function Note({ children }: { children: React.ReactNode }) {
  return (
    <div style={{
      marginTop: 12,
      padding: "12px 16px",
      borderRadius: 10,
      background: "var(--bg-alt)",
      border: "1px solid var(--border)",
      fontSize: 13,
      color: "var(--text-muted)",
      lineHeight: 1.6,
    }}>
      {children}
    </div>
  );
}

function FAQ({ items }: { items: { q: string; a: string }[] }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      {items.map((item) => (
        <div key={item.q} style={{
          padding: "16px 18px",
          borderRadius: 10,
          background: "var(--bg-alt)",
          border: "1px solid var(--border)",
        }}>
          <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 6 }}>{item.q}</div>
          <div style={{ fontSize: 14, color: "var(--text-muted)", lineHeight: 1.65 }}>{item.a}</div>
        </div>
      ))}
    </div>
  );
}
