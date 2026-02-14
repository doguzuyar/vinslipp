export default function PrivacyPolicy() {
  const h2Style = { fontSize: 17, fontWeight: 600, marginTop: 28, marginBottom: 8 } as const;

  return (
    <div
      style={{
        maxWidth: 600,
        margin: "0 auto",
        padding: "40px 20px",
        fontFamily: "Inter, -apple-system, system-ui, sans-serif",
        lineHeight: 1.7,
        color: "var(--text)",
      }}
    >
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>
        Privacy Policy
      </h1>
      <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 32 }}>
        Last updated: February 14, 2026
      </p>

      <h2 style={h2Style}>Data We Collect</h2>
      <p>
        When you sign in with Apple, we collect your Apple-provided user ID and
        display name. If you choose to hide your email, we never see it.
      </p>
      <p>
        When you post tasting notes, we store your user ID, display name, and
        the content you write in Firebase Firestore.
      </p>
      <p>
        If you enable push notifications, Firebase Cloud Messaging receives a
        device token to deliver notifications. We do not store this token
        ourselves.
      </p>

      <h2 style={h2Style}>Data We Do Not Collect</h2>
      <p>
        We do not collect email addresses, location data, analytics, usage
        tracking, or advertising identifiers.
      </p>

      <h2 style={h2Style}>Local Storage</h2>
      <p>
        The app stores your display preferences (dark mode, filters) and
        imported cellar data locally on your device. This data never leaves your
        device.
      </p>

      <h2 style={h2Style}>Third-Party Services</h2>
      <ul style={{ paddingLeft: 20 }}>
        <li>
          <strong>Firebase Authentication</strong> &mdash; handles sign-in (
          <a href="https://policies.google.com/privacy" style={{ color: "var(--text)" }}>
            Google Privacy Policy
          </a>
          )
        </li>
        <li>
          <strong>Firebase Firestore</strong> &mdash; stores blog posts
        </li>
        <li>
          <strong>Firebase Cloud Messaging</strong> &mdash; delivers push
          notifications
        </li>
      </ul>

      <h2 style={h2Style}>Data Deletion</h2>
      <p>
        You can delete your blog posts directly in the app. To request full
        account deletion, contact us at the email below.
      </p>

      <h2 style={h2Style}>Third-Party Links</h2>
      <p>
        The app may contain links to external websites (e.g. Vivino,
        Systembolaget). These sites have their own privacy policies and we have
        no control over their content or practices.
      </p>

      <h2 style={h2Style}>Contact</h2>
      <p>
        If you have questions about this policy, you can reach the developer at{" "}
        <a href="mailto:doguzuyar@gmail.com" style={{ color: "var(--text)" }}>
          doguzuyar@gmail.com
        </a>
        .
      </p>
    </div>
  );
}
