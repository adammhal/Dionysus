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
                    // This should be triggered by an Apple Pencil Pro gesture,
                    // for example a UIHoverGestureRecognizer.
                    hapticManager.playPencilProHaptic()
                }
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
}
