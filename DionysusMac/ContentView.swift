import SwiftUI

struct ContentView: View {
    private var hapticManager = HapticManager()

    var body: some View {
        NavigationView {
            List {
                Text("Search Results")
            }
            .listStyle(SidebarListStyle())

            Text("Media Content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .liquidGlass()
                .onTapGesture {
                    hapticManager.playForceFeedback()
                }
        }
        .frame(minWidth: 700, minHeight: 300)
    }
}
