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

            PlaceholderTab(title: "Blog", icon: "doc.text")
                .tabItem {
                    Label("Blog", systemImage: "doc.text")
                }
                .tag(2)

            PlaceholderTab(title: "Auction", icon: "dollarsign.circle")
                .tabItem {
                    Label("Auction", systemImage: "dollarsign.circle")
                }
                .tag(3)

            PlaceholderTab(title: "Profile", icon: "person.circle")
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(4)
        }
        .tint(Color(hex: "#e7e5e4"))
    }
}
