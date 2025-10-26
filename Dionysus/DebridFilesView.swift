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
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                        TextField("Search...", text: $viewModel.searchText)
                            .foregroundColor(.white)
                    }
                    .glassmorphicStyle()
                    .padding(.horizontal)

                    List {
                        ForEach(viewModel.filteredTorrents) { torrent in
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
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
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
