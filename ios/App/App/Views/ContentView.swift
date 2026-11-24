import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dataService = DataService()
    @StateObject private var cellarService = CellarService()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            TabView(selection: $appDelegate.selectedTab) {
                ReleaseTab(dataService: dataService)
                    .tabItem {
                        Label("Releases", systemImage: "clock")
                    }
                    .tag(0)

                CellarTab(cellarService: cellarService)
                    .tabItem {
                        Label("Cellar", systemImage: "cube.box")
                    }
                    .tag(1)

                AuctionTab(dataService: dataService)
                    .tabItem {
                        Label("Auction", systemImage: "dollarsign.circle")
                    }
                    .tag(2)

                ProfileTab()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .tag(3)
            }
            .tint(Color.primary)
            .environmentObject(cellarService)
            .environmentObject(dataService)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .statusBarHidden()
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
