import { getReleaseData, getMetadata } from "@/lib/data";
import { TabShell } from "@/components/TabShell";
import { SplashOverlay } from "@/components/SplashOverlay";

export default function Home() {
  const releases = getReleaseData();
  const metadata = getMetadata();

  return (
    <>
      <SplashOverlay />
      <TabShell releases={releases} metadata={metadata} />
    </>
  );
}
