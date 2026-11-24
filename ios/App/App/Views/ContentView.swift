import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dataService = DataService()
    @StateObject private var cellarService = CellarService()
    @State private var showSplash = true
    @State private var hasTopBand = true

    var body: some View {
        ZStack {
            TabView(selection: $appDelegate.selectedTab) {
                ReleaseTab(dataService: dataService)
                    .padding(.top, topPadding)
                    .tabItem {
                        Label("Releases", systemImage: "clock")
                    }
                    .tag(0)

                CellarTab(cellarService: cellarService)
                    .padding(.top, topPadding)
                    .tabItem {
                        Label("Cellar", systemImage: "cube.box")
                    }
                    .tag(1)

                AuctionTab(dataService: dataService)
                    .padding(.top, topPadding)
                    .tabItem {
                        Label("Auction", systemImage: "dollarsign.circle")
                    }
                    .tag(2)

                ProfileTab()
                    .padding(.top, topPadding)
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .tag(3)
            }
            .tint(Color.primary)
            .environmentObject(cellarService)
            .environmentObject(dataService)
            .environment(\.hasTopBand, hasTopBand)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .statusBarHidden()
        // Re-measured on launch and whenever the screen size changes (folding or unfolding).
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { measureTopBand() }
                    .onChange(of: geo.size) { measureTopBand() }
            }
        }
        .task {
            if dataService.releaseData == nil {
                await dataService.loadReleases()
            }
            // Lift the splash after the first attempt either way, so a failed load shows ReleaseTab's Retry.
            withAnimation(.easeInOut(duration: 0.8)) {
                showSplash = false
            }
            if dataService.auctionData == nil {
                await dataService.loadAuction()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
        }
    }
}

extension ContentView {
    /// Without a top band (iPhone Duo inner display) the top edge ignores taps,
    /// so each tab keeps its controls below it. Set per tab: TabView doesn't pass it on.
    private var topPadding: CGFloat { hasTopBand ? 0 : 24 }

    /// Reads the window's own inset, which the padding added above can't change.
    private func measureTopBand() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return }
        hasTopBand = UIDevice.current.userInterfaceIdiom == .pad || window.safeAreaInsets.top > 0
    }
}

// MARK: - Splash View

private struct SplashView: View {
    var body: some View {
        GeometryReader { geo in
            Image("Splash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }
}
