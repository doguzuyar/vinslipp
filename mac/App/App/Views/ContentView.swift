import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dataService = DataService()
    @StateObject private var cellarService = CellarService()

    private let tabs: [(label: String, icon: String)] = [
        ("Releases", "clock"),
        ("Cellar", "cube.box"),
        ("Blog", "doc.text"),
        ("Auction", "dollarsign.circle"),
        ("Profile", "person.circle"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 0) {
                Text("Vinslipp")
                    .font(.title3.weight(.bold))
                    .padding(.leading, 16)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button {
                            appDelegate.selectedTab = index
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.label)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(appDelegate.selectedTab == index ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                appDelegate.selectedTab == index
                                    ? Color.primary.opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Content
            Group {
                switch appDelegate.selectedTab {
                case 0:
                    ReleaseTab(dataService: dataService)
                case 1:
                    CellarTab(cellarService: cellarService)
                case 2:
                    BlogTab()
                case 3:
                    AuctionTab(dataService: dataService)
                case 4:
                    ProfileTab()
                default:
                    ReleaseTab(dataService: dataService)
                }
            }
            .environmentObject(cellarService)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, Bundle.main.bundleIdentifier != nil {
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
        }
        .task {
            if dataService.releaseData == nil {
                await dataService.loadReleases()
            }
        }
    }
}
