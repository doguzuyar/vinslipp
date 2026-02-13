import SwiftUI

struct ContentView: View {
    @StateObject private var dataService = DataService()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ReleaseTab(dataService: dataService)
                .tabItem {
                    Label("Releases", systemImage: "clock")
                }
                .tag(0)

            PlaceholderTab(title: "Cellar", icon: "cube.box")
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
