import Foundation
import SwiftUI

@MainActor
class FileDetailsViewModel: ObservableObject {
    enum FileHealth { case checking, ok, infringing, failed }

    @Published var torrentInfo: RealDebridTorrentInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var fileHealth: [Int: FileHealth] = [:]

    func fetchDetails(id: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let info = try await APIService.shared.fetchTorrentInfo(id: id)
            self.torrentInfo = info
            isLoading = false
            await checkFileHealth(for: info)
        } catch let apiError as APIError {
            self.errorMessage = apiError.localizedDescription
            isLoading = false
        } catch {
            self.errorMessage = "Failed to load file details: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func checkFileHealth(for info: RealDebridTorrentInfo) async {
        guard info.status == "downloaded" else { return }
        let selectedFiles = info.files.filter { $0.selected == 1 }
        guard selectedFiles.count == info.links.count, !info.links.isEmpty else { return }

        for file in selectedFiles {
            fileHealth[file.id] = .checking
        }

        await withTaskGroup(of: (Int, FileHealth).self) { group in
            for (index, file) in selectedFiles.enumerated() {
                let link = info.links[index]
                group.addTask {
                    do {
                        _ = try await APIService.shared.unrestrict(link: link)
                        return (file.id, .ok)
                    } catch APIError.infringingFile {
                        return (file.id, .infringing)
                    } catch {
                        return (file.id, .failed)
                    }
                }
            }
            for await (fileId, health) in group {
                self.fileHealth[fileId] = health
            }
        }
    }
}
