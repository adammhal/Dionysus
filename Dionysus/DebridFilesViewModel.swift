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

    func deleteTorrent(at offsets: IndexSet) {
        let torrentsToDelete = offsets.map { torrents[$0] }
        HapticManager.shared.impact()
        Task {
            for torrent in torrentsToDelete {
                do {
                    try await APIService.shared.deleteTorrent(id: torrent.id)
                    await MainActor.run {
                        torrents.removeAll { $0.id == torrent.id }
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to delete torrent."
                    }
                }
            }
        }
    }
}
