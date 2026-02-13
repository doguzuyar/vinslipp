import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @StateObject private var dataService = DataService()

    var body: some View {
        TabView(selection: $appDelegate.selectedTab) {
            ReleaseTab(dataService: dataService)
                .tabItem {
                    Label("Releases", systemImage: "clock")
                }
                .tag(0)

            CellarTab()
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

            ProfileTab()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(4)
        }
        .tint(Color.primary)
        .statusBarHidden()
    }
}
