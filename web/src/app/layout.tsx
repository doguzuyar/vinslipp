import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./custom.css";

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 0.85,
  maximumScale: 0.85,
  userScalable: false,
  viewportFit: "cover",
};

export const metadata: Metadata = {
  title: "Vinslipp",
  description: "Wine cellar dashboard with releases, auction data, and collection tracking",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap"
          rel="stylesheet"
        />
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if (localStorage.getItem('darkMode') === '1') {
                document.documentElement.classList.add('dark');
              }
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a[target="_blank"]');
                if (a && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openInApp) {
                  e.preventDefault();
                  e.stopPropagation();
                  window.webkit.messageHandlers.openInApp.postMessage(a.href);
                }
              }, true);
            `,
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
