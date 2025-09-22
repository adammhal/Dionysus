import Foundation
import WatchKit

class HapticManager {
    func playSuccess() {
        WKInterfaceDevice.current().play(.success)
    }
}
