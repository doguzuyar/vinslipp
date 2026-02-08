export default function PrivacyPolicy() {
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
        Last updated: February 7, 2026
      </p>

      <h2 style={{ fontSize: 17, fontWeight: 600, marginTop: 28, marginBottom: 8 }}>
        Data Collection
      </h2>
      <p>
        Vinslipp does not collect, store, or transmit any personal data. The
        app runs entirely in your browser or device and does not use analytics,
        tracking, cookies, or any third-party services that collect user
        information.
      </p>

      <h2 style={{ fontSize: 17, fontWeight: 600, marginTop: 28, marginBottom: 8 }}>
        Local Storage
      </h2>
      <p>
        The app uses your device&apos;s local storage solely to remember your
        display preferences (such as dark mode and filters). This data never
        leaves your device.
      </p>

      <h2 style={{ fontSize: 17, fontWeight: 600, marginTop: 28, marginBottom: 8 }}>
        Third-Party Links
      </h2>
      <p>
        The app may contain links to external websites (e.g. Vivino,
        Systembolaget). These sites have their own privacy policies and we have
        no control over their content or practices.
      </p>

      <h2 style={{ fontSize: 17, fontWeight: 600, marginTop: 28, marginBottom: 8 }}>
        Contact
      </h2>
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
