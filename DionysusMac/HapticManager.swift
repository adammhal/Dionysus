import Foundation
import AppKit

class HapticManager {
    // This method provides a more pronounced haptic feedback.
    // To implement true "force" haptics, you would use this with a
    // gesture recognizer that can detect pressure, such as NSClickGestureRecognizer.
    func playForceFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    // I'll keep the original method for other types of feedback.
    func playSuccess() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}
