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

                BlogTab()
                    .tabItem {
                        Label("Blog", systemImage: "doc.text")
                    }
                    .tag(2)

                AuctionTab(dataService: dataService)
                    .tabItem {
                        Label("Auction", systemImage: "dollarsign.circle")
                    }
                    .tag(3)

                ProfileTab(cellarService: cellarService)
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .tag(4)
            }
            .tint(Color.primary)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .statusBarHidden()
        .onChange(of: dataService.isLoading) {
            if !dataService.isLoading && dataService.releaseData != nil {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showSplash = false
                }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
                UIApplication.shared.applicationIconBadgeNumber = 0
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
