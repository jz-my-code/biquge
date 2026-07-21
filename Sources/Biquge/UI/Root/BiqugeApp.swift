import SwiftUI

// MARK: - App 入口

@main
struct BiqugeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(SourceStore.shared)
                .environmentObject(ShelfStore.shared)
        }
    }
}

// MARK: - 根 Tab 视图

struct RootView: View {
    @StateObject private var sourceStore = SourceStore.shared
    @StateObject private var shelfStore = ShelfStore.shared

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("书架", systemImage: "books.vertical.fill") }

            ExploreView()
                .tabItem { Label("发现", systemImage: "safari.fill") }

            SourceManagerView()
                .tabItem { Label("书源", systemImage: "list.bullet.rectangle.portrait") }
        }
        .tint(.orange)
    }
}