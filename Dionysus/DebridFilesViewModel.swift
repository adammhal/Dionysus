import Foundation
import SwiftUI

@MainActor
class DebridFilesViewModel: ObservableObject {
    @Published var torrents: [RealDebridTorrent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentPage = 1
    private var isFetching = false
    private var hasMorePages = true

    func fetchTorrents(forceRefresh: Bool = false) async {
        guard !isFetching, hasMorePages || forceRefresh else { return }

        if forceRefresh {
            currentPage = 1
            torrents.removeAll()
            hasMorePages = true
        }

        isFetching = true
        isLoading = true
        errorMessage = nil

        do {
            let fetchedTorrents = try await APIService.shared.fetchTorrents(page: currentPage)
            if fetchedTorrents.isEmpty {
                hasMorePages = false
            } else {
                torrents.append(contentsOf: fetchedTorrents)
                currentPage += 1
            }
        } catch {
            self.errorMessage = "Failed to fetch debrid files."
        }

        isLoading = false
        isFetching = false
    }

    func deleteTorrent(id: String) async {
        do {
            try await APIService.shared.deleteTorrent(id: id)
            torrents.removeAll { $0.id == id }
        } catch {
            self.errorMessage = "Failed to delete torrent."
        }
    }
}
