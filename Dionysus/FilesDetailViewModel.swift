import Foundation
import SwiftUI

@MainActor
class FileDetailsViewModel: ObservableObject {
    @Published var torrentInfo: RealDebridTorrentInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchDetails(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            self.torrentInfo = try await APIService.shared.fetchTorrentInfo(id: id)
        } catch {
            print("!!! FETCH DETAILS FAILED: \(error.localizedDescription)")
            self.errorMessage = "Failed to load file details."
        }
        
        isLoading = false
    }
}
