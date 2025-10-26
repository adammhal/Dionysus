import Foundation
import SwiftUI
import Combine

@MainActor
class DebridFilesViewModel: ObservableObject {
    @Published var torrents: [RealDebridTorrent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private var allLibraryTorrents: [RealDebridTorrent] = []
    private var isFetching = false
    private var searchCancellable: AnyCancellable?

    init() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterTorrents()
            }
    }
    
    private func filterTorrents() {
        if searchText.isEmpty {
            torrents = allLibraryTorrents
        } else {
            torrents = allLibraryTorrents.filter {
                $0.filename.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func loadAllTorrents(forceRefresh: Bool = false) async {
        guard !isFetching || forceRefresh else { return }

        isFetching = true
        isLoading = true
        errorMessage = nil

        if forceRefresh {
            allLibraryTorrents.removeAll()
        }
        
        var currentPage = 1
        var hasMorePages = true

        do {
            while hasMorePages {
                let fetchedTorrents = try await APIService.shared.fetchTorrents(page: currentPage)
                if fetchedTorrents.isEmpty {
                    hasMorePages = false
                } else {
                    allLibraryTorrents.append(contentsOf: fetchedTorrents)
                    currentPage += 1
                }
            }
            filterTorrents()
        } catch {
            print("!!! VM ERROR (loadAllTorrents): \(error.localizedDescription)")
            self.errorMessage = "Failed to fetch debrid files. Check console."
        }

        isLoading = false
        isFetching = false
    }

    func deleteTorrent(id: String) async {
        do {
            try await APIService.shared.deleteTorrent(id: id)
            allLibraryTorrents.removeAll { $0.id == id }
            filterTorrents()
        } catch {
            print("!!! VM ERROR (deleteTorrent): \(error.localizedDescription)")
            self.errorMessage = "Failed to delete torrent. Check console."
        }
    }
}
