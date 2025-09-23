import SwiftUI

@main
struct DionysusMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // This sets a default size for the window on macOS.
        .windowStyle(DefaultWindowStyle())
        .windowResizability(.contentSize)
    }
}
