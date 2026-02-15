import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GenerateView()
                .tabItem {
                    Label("Generate Subtitles", systemImage: "text.bubble")
                }
                .tag(0)

            BurnView()
                .tabItem {
                    Label("Burn Subtitles", systemImage: "flame")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
