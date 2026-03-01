import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GenerateView()
                .tabItem {
                    Label("生成字幕", systemImage: "text.bubble")
                }
                .tag(0)

            BurnView()
                .tabItem {
                    Label("燒錄字幕", systemImage: "flame")
                }
                .tag(1)

            CorrectView()
                .tabItem {
                    Label("校正/翻譯字幕", systemImage: "text.badge.checkmark")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(3)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
