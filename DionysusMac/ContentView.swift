import SwiftUI

struct ContentView: View {
    var body: some View {
        // We can reuse the exact same TabView structure from the iPad app.
        // SwiftUI will automatically adapt its appearance for macOS.
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .preferredColorScheme(.dark)
    }
}
