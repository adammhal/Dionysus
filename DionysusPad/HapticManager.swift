import UIKit

class HapticManager {
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()

    func playSuccess() {
        impactFeedbackGenerator.impactOccurred()
    }

    // This method is intended to be used with Apple Pencil Pro.
    // It provides a subtle feedback when the pencil is interacting with the UI.
    // You would typically trigger this from a UIHoverGestureRecognizer.
    func playPencilProHaptic() {
        selectionFeedbackGenerator.selectionChanged()
    }
}
