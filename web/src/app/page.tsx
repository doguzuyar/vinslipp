import { getCellarData, getReleaseData, getHistoryData, getMetadata } from "@/lib/data";
import { TabShell } from "@/components/TabShell";
import { SplashOverlay } from "@/components/SplashOverlay";

export default function Home() {
  const cellar = getCellarData();
  const releases = getReleaseData();
  const history = getHistoryData();
  const metadata = getMetadata();

  return (
    <>
      <SplashOverlay />
      <TabShell
        cellar={cellar}
        releases={releases}
        history={history}
        metadata={metadata}
      />
    </>
  );
}
