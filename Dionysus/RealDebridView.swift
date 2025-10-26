import SwiftUI

@MainActor
class RealDebridViewModel: ObservableObject {
    @Published var torrents: [RealDebridTorrent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = true
    private var currentPage = 1
    private let limit = 50

    func fetchTorrents(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            torrents = []
            canLoadMore = true
        }

        guard !isLoading && canLoadMore else { return }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedTorrents = try await APIService.shared.fetchRealDebridTorrents(page: currentPage, limit: limit)
            if fetchedTorrents.count < limit {
                canLoadMore = false
            }
            torrents.append(contentsOf: fetchedTorrents)
            currentPage += 1
            HapticManager.shared.success()
        } catch {
            self.errorMessage = "Failed to load torrents."
        }
        isLoading = false
    }

    func deleteTorrent(id: String) async {
        do {
            try await APIService.shared.deleteRealDebridTorrent(id: id)
            torrents.removeAll { $0.id == id }
            HapticManager.shared.success()
        } catch {
            // Handle error silently for now
        }
    }
}

struct RealDebridView: View {
    @StateObject private var viewModel = RealDebridViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                BlobBackgroundView(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], isAnimating: true)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.torrents.isEmpty {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) { Task { await viewModel.fetchTorrents(refresh: true) } }
                } else {
                    List {
                        ForEach(viewModel.torrents) { torrent in
                            TorrentStatusRow(torrent: torrent)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteTorrent(id: torrent.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }

                        if viewModel.canLoadMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .onAppear {
                                        Task {
                                            await viewModel.fetchTorrents()
                                        }
                                    }
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.fetchTorrents(refresh: true) }
                }
            }
            .navigationTitle("Real-Debrid Files")
            .toolbar { ToolbarItem(placement: .principal) { DionysusTitleView() } }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .task {
            if viewModel.torrents.isEmpty {
                await viewModel.fetchTorrents()
            }
        }
    }
}

struct TorrentStatusRow: View {
    let torrent: RealDebridTorrent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(torrent.filename)
                .font(.headline)

            HStack {
                Text(torrent.status.capitalized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor(for: torrent.status))

                Spacer()

                Text(formatBytes(torrent.bytes))
                    .font(.caption)
            }

            ProgressView(value: Float(torrent.progress), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: statusColor(for: torrent.status)))

            HStack {
                if let speed = torrent.speed, speed > 0 {
                    Label(String(format: "%.2f MB/s", Double(speed) / 1024 / 1024), systemImage: "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let seeders = torrent.seeders, seeders > 0 {
                    Label("\(seeders)", systemImage: "arrow.up.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "downloaded":
            return .green
        case "downloading":
            return .blue
        case "seeding":
            return .purple
        case "error":
            return .red
        default:
            return .gray
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
