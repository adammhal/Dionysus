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
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(torrent.filename)
                                        .font(.headline)
                                    Text("Size: \(formatFileSize(Int64(torrent.bytes)))")
                                        .font(.subheadline)
                                    Text("Status: \(torrent.status)")
                                        .font(.subheadline)
                                        .foregroundColor(statusColor(for: torrent.status))
                                }
                                Spacer()
                            }
                            .onAppear {
                                if torrent.id == viewModel.torrents.last?.id {
                                    Task {
                                        await viewModel.fetchTorrents()
                                    }
                                }
                            }
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

    // ✅ Replaces MB-only display with dynamic formatting
    private func formatFileSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824 // 1024^3
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        }

        let mb = Double(bytes) / 1_048_576 // 1024^2
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
