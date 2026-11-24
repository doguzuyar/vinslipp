import { PageLayout } from "@/components/PageLayout";
import { Section } from "@/components/Section";

export default function PrivacyPolicy() {
  return (
    <PageLayout title="Privacy Policy" subtitle="Last updated: November 24, 2026">

      <Section title="Data We Collect">
        <p>When you sign in with Apple, we receive your Apple-provided user ID, display name, and email address (unless you choose to hide it, in which case we never see it).</p>
        <p>When you are signed in, your cellar (the wines, counts, prices and notes you enter) is backed up to Firebase Firestore under your user ID so it can be restored on your other devices.</p>
        <p>If you enable push notifications, Firebase Cloud Messaging receives a device token to deliver them. We do not store this token ourselves.</p>
      </Section>

      <Section title="Data We Do Not Collect">
        <Tags items={["Location data", "Analytics", "Usage tracking", "Advertising identifiers"]} />
      </Section>

      <Section title="Local Storage">
        <p>Display preferences (dark mode, filters) stay on your device. Your cellar is also saved on your device; it is only copied to Firebase Firestore while you are signed in.</p>
      </Section>

      <Section title="Third-Party Services">
        <ServiceList items={[
          { name: "Firebase Authentication", desc: "Handles sign-in", link: { label: "Google Privacy Policy", href: "https://policies.google.com/privacy" } },
          { name: "Firebase Firestore", desc: "Backs up your cellar while you are signed in" },
          { name: "Firebase Cloud Messaging", desc: "Delivers push notifications" },
        ]} />
      </Section>

      <Section title="Data Deletion">
        <p>
          You can delete your account directly from the app. Open the <strong>Profile</strong> tab,
          scroll down, and tap <strong>Delete Account</strong>. You will be asked to re-authenticate
          with Apple before deletion completes. This permanently removes your sign-in credentials, your
          cellar backup, and any tasting notes you posted. The copy of your cellar stored on your device
          stays there until you clear it from the Cellar tab.
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
    </PageLayout>
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
