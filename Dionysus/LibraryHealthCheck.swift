import Foundation
import SwiftUI

// MARK: - Models

struct TorrentHealthResult: Identifiable {
    let id: String
    let torrentName: String
    let flaggedFiles: [FlaggedFile]

    struct FlaggedFile: Identifiable {
        let id = UUID()
        let filename: String
        let reason: Reason
        enum Reason { case infringing, unreachable }
    }
}

// MARK: - ViewModel

@MainActor
class LibraryHealthCheckViewModel: ObservableObject {
    enum State {
        case idle
        case fetchingList
        case checking(checked: Int, total: Int)
        case done(checked: Int)
        case failed(String)
    }

    @Published var state: State = .idle
    @Published var results: [TorrentHealthResult] = []

    private var checkTask: Task<Void, Never>?

    func start() {
        checkTask = Task { await run() }
    }

    func cancel() {
        checkTask?.cancel()
        checkTask = nil
        state = .idle
        results = []
    }

    private func run() async {
        state = .fetchingList
        results = []

        do {
            // Collect all downloaded torrents
            var allTorrents: [RealDebridTorrent] = []
            var page = 1
            while true {
                try Task.checkCancellation()
                let batch = try await APIService.shared.fetchTorrents(page: page)
                if batch.isEmpty { break }
                allTorrents.append(contentsOf: batch)
                page += 1
            }

            let toCheck = allTorrents.filter { $0.status == "downloaded" }
            state = .checking(checked: 0, total: toCheck.count)

            // Process in batches of 5 to stay well under the 250 req/min limit
            let batchSize = 5
            var checked = 0

            for batchStart in stride(from: 0, to: toCheck.count, by: batchSize) {
                try Task.checkCancellation()
                let slice = toCheck[batchStart..<min(batchStart + batchSize, toCheck.count)]

                await withTaskGroup(of: TorrentHealthResult?.self) { group in
                    for torrent in slice {
                        group.addTask { await self.checkTorrent(torrent) }
                    }
                    for await result in group {
                        checked += 1
                        state = .checking(checked: checked, total: toCheck.count)
                        if let result, !result.flaggedFiles.isEmpty {
                            results.append(result)
                        }
                    }
                }

                // 300ms pause between batches
                if batchStart + batchSize < toCheck.count {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }

            state = .done(checked: checked)
        } catch is CancellationError {
            // user cancelled — state already reset in cancel()
        } catch let error as APIError {
            state = .failed(error.localizedDescription ?? "Check failed.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func checkTorrent(_ torrent: RealDebridTorrent) async -> TorrentHealthResult? {
        guard let info = try? await APIService.shared.fetchTorrentInfo(id: torrent.id) else {
            return nil
        }
        let selectedFiles = info.files.filter { $0.selected == 1 }
        guard selectedFiles.count == info.links.count, !info.links.isEmpty else { return nil }

        var flagged: [TorrentHealthResult.FlaggedFile] = []

        await withTaskGroup(of: TorrentHealthResult.FlaggedFile?.self) { group in
            for (index, file) in selectedFiles.enumerated() {
                let link = info.links[index]
                let filename = URL(fileURLWithPath: file.path).lastPathComponent
                group.addTask {
                    do {
                        _ = try await APIService.shared.unrestrict(link: link)
                        return nil
                    } catch APIError.infringingFile {
                        return TorrentHealthResult.FlaggedFile(filename: filename, reason: .infringing)
                    } catch {
                        return TorrentHealthResult.FlaggedFile(filename: filename, reason: .unreachable)
                    }
                }
            }
            for await entry in group {
                if let entry { flagged.append(entry) }
            }
        }

        guard !flagged.isEmpty else { return nil }
        return TorrentHealthResult(id: torrent.id, torrentName: torrent.filename, flaggedFiles: flagged)
    }
}

// MARK: - View

struct LibraryHealthCheckView: View {
    @StateObject private var viewModel = LibraryHealthCheckViewModel()

    var body: some View {
        List {
            switch viewModel.state {
            case .idle:
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This scans every downloaded torrent in your Real-Debrid library and checks whether each file link is accessible.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Large libraries may take a minute or two. Requests are rate-limited automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    Button("Start Check") {
                        viewModel.start()
                    }
                    .font(.headline)
                }

            case .fetchingList:
                Section {
                    HStack(spacing: 12) {
                        ProgressView().scaleEffect(0.9)
                        Text("Fetching your library…")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    Button("Cancel", role: .destructive) { viewModel.cancel() }
                }

            case .checking(let checked, let total):
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Checking files…")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(checked) / \(total)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: Double(checked), total: Double(max(total, 1)))
                    }
                    .padding(.vertical, 4)
                    Button("Cancel", role: .destructive) { viewModel.cancel() }
                }
                resultsSection

            case .done(let checked):
                Section {
                    if viewModel.results.isEmpty {
                        Label("All \(checked) torrents are healthy", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("\(viewModel.results.count) torrent(s) have issues", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                resultsSection
                Section {
                    Button("Run Again") {
                        viewModel.start()
                    }
                }

            case .failed(let message):
                Section {
                    Label("Check failed", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Try Again") { viewModel.start() }
                }
            }
        }
        .navigationTitle("Library Health Check")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !viewModel.results.isEmpty {
            Section(header: Text("Issues Found")) {
                ForEach(viewModel.results) { result in
                    DisclosureGroup {
                        ForEach(result.flaggedFiles) { file in
                            HStack(spacing: 10) {
                                Image(systemName: file.reason == .infringing
                                      ? "exclamationmark.circle.fill"
                                      : "exclamationmark.triangle.fill")
                                    .foregroundColor(file.reason == .infringing ? .red : .orange)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.filename)
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text(file.reason == .infringing
                                         ? "Blocked — copyright claim"
                                         : "Link unreachable")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(result.torrentName)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }
}
