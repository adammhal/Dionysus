import SwiftUI

struct ContentView: View {
    private var hapticManager = HapticManager()

    var body: some View {
        VStack {
            Text("Dionysus")
                .font(.title)
                .liquidGlass()
                .onTapGesture {
                    hapticManager.playSuccess()
                }
        }
    }
}
