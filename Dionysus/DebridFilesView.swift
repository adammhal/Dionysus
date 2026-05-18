import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DebridFilesView: View {
    @StateObject private var viewModel = DebridFilesViewModel()
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedTorrent: RealDebridTorrent?

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
                            await viewModel.loadAllTorrents(forceRefresh: true)
                        }
                    }
                } else {
                    torrentList
                }
            }
            .coordinateSpace(name: "scroll")
            .onChange(of: scrollOffset) {
                #if os(iOS)
                HapticManager.shared.playScrollTick()
                #endif
            }
            .navigationTitle("Debrid Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadAllTorrents(forceRefresh: true)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search your library")
            .sheet(item: $selectedTorrent) { torrent in
                FileDetailsView(torrent: torrent)
            }
        }
        .onAppear {
            if viewModel.torrents.isEmpty {
                Task {
                    await viewModel.loadAllTorrents()
                }
            }
        }
    }
    
    private var torrentList: some View {
        let list = List {
            ForEach(viewModel.torrents) { torrent in
                Button(action: {
                    selectedTorrent = torrent
                }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(torrent.filename)
                                .font(.headline)
                                .lineLimit(2)
                            Text(formatFileSize(Int64(torrent.bytes)))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(torrent.statusLabel)
                                .font(.caption)
                                .foregroundColor(torrent.statusColor)
                        }
                        Spacer()
                        if torrent.isFailed {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                        } else if torrent.isStuck {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        .background(GeometryReader {
            Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: $0.frame(in: .named("scroll")).minY)
        })
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            self.scrollOffset = value
        }
        
        if #available(iOS 15.0, *) {
            return list
        } else {
            return list
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        }

        let mb = Double(bytes) / 1_048_576
        if mb >= 1 {
            return String(format: "%.2f MB", mb)
        }

        let kb = Double(bytes) / 1024
        if kb >= 1 {
            return String(format: "%.2f KB", kb)
        }

        return "\(bytes) B"
    }

    private func deleteItems(at offsets: IndexSet) {
        let torrentsToDelete = offsets.map { viewModel.torrents[$0] }
        Task {
            for torrent in torrentsToDelete {
                await viewModel.deleteTorrent(id: torrent.id)
            }
        }
    }

}
