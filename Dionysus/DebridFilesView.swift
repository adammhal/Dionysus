import SwiftUI

struct DebridFilesView: View {
    @StateObject private var viewModel = DebridFilesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                BlobBackgroundView(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], isAnimating: true)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.torrents.isEmpty {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            await viewModel.fetchTorrents()
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.torrents) { torrent in
                            TorrentFileRow(torrent: torrent, onDelete: {
                                Task {
                                    await viewModel.deleteTorrent(id: torrent.id)
                                }
                            })
                            .onAppear {
                                if torrent.id == viewModel.torrents.last?.id {
                                    Task {
                                        await viewModel.fetchTorrents()
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Debrid Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.fetchTorrents(forceRefresh: true)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            if viewModel.torrents.isEmpty {
                Task {
                    await viewModel.fetchTorrents()
                }
            }
        }
    }
}

struct TorrentFileRow: View {
    let torrent: RealDebridTorrent
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(torrent.filename)
                    .font(.headline)
                Text("Size: \(torrent.bytes / 1024 / 1024) MB")
                    .font(.subheadline)
                Text("Status: \(torrent.status)")
                    .font(.subheadline)
                    .foregroundColor(statusColor(for: torrent.status))
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "downloaded":
            return .green
        case "downloading":
            return .blue
        case "seeding":
            return .orange
        default:
            return .gray
        }
    }
}
