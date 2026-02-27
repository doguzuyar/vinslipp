import { Section } from "@/components/Section";

export default function PrivacyPolicy() {
  return (
    <div style={{
      maxWidth: 640,
      margin: "0 auto",
      padding: "60px 24px 80px",
      color: "var(--text)",
    }}>
      <h1 style={{ fontSize: 28, fontWeight: 600, marginBottom: 6, letterSpacing: "-0.02em" }}>
        Privacy Policy
      </h1>
      <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 48, marginTop: 0 }}>
        Last updated: February 19, 2026
      </p>

      <Section title="Data We Collect">
        <p>When you sign in with Apple, we receive your Apple-provided user ID, display name, and email address (unless you choose to hide it, in which case we never see it).</p>
        <p>When you post tasting notes, we store your user ID, display name, and the content you write in Firebase Firestore.</p>
        <p>If you enable push notifications, Firebase Cloud Messaging receives a device token to deliver them. We do not store this token ourselves.</p>
      </Section>

      <Section title="Data We Do Not Collect">
        <Tags items={["Location data", "Analytics", "Usage tracking", "Advertising identifiers"]} />
      </Section>

      <Section title="Local Storage">
        <p>Display preferences (dark mode, filters) and imported cellar data are stored locally on your device and never leave it.</p>
      </Section>

      <Section title="Third-Party Services">
        <ServiceList items={[
          { name: "Firebase Authentication", desc: "Handles sign-in", link: { label: "Google Privacy Policy", href: "https://policies.google.com/privacy" } },
          { name: "Firebase Firestore", desc: "Stores tasting notes and blog posts" },
          { name: "Firebase Cloud Messaging", desc: "Delivers push notifications" },
        ]} />
      </Section>

      <Section title="Data Deletion">
        <p>
          You can delete your account directly from the app. Open the <strong>Profile</strong> tab,
          scroll down, and tap <strong>Delete Account</strong>. You will be asked to re-authenticate
          with Apple before deletion completes. This permanently removes your sign-in credentials and
          any content you have published.
        </p>
      </Section>

      <Section title="Third-Party Links">
        <p>
          The app may link to external websites (e.g. Vivino, Systembolaget). Those sites have their
          own privacy policies and we have no control over their content or practices.
        </p>
      </Section>

      <Section title="Contact" last>
        <p>
          Questions about this policy? Reach the developer at{" "}
          <a href="mailto:doguziylan@icloud.com" style={{ color: "var(--accent)", textDecoration: "none" }}>
            doguziylan@icloud.com
          </a>
          .
        </p>
      </Section>
    </div>
  );
}

function Tags({ items }: { items: string[] }) {
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
      {items.map((item) => (
        <span key={item} style={{
          fontSize: 13,
          padding: "4px 12px",
          borderRadius: 100,
          background: "var(--bg-alt)",
          border: "1px solid var(--border)",
          color: "var(--text-muted)",
        }}>
          {item}
        </span>
      ))}
    </div>
  );
}

function ServiceList({ items }: {
  items: { name: string; desc: string; link?: { label: string; href: string } }[]
}) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      {items.map((item) => (
        <div key={item.name} style={{
          padding: "14px 16px",
          borderRadius: 10,
          background: "var(--bg-alt)",
          border: "1px solid var(--border)",
          fontSize: 14,
          lineHeight: 1.6,
        }}>
          <span style={{ fontWeight: 600 }}>{item.name}</span>
          <span style={{ color: "var(--text-muted)" }}> | {item.desc}</span>
          {item.link && (
            <span>
              {" "}(
              <a href={item.link.href} style={{ color: "var(--accent)", textDecoration: "none" }}>
                {item.link.label}
              </a>
              )
            </span>
          )}
        </div>
      ))}
    </div>
  );
}
