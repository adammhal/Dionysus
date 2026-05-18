import SwiftUI

struct FileDetailsView: View {
    @StateObject private var viewModel = FileDetailsViewModel()
    
    let torrent: RealDebridTorrent
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            await viewModel.fetchDetails(id: torrent.id)
                        }
                    }
                } else if let torrentInfo = viewModel.torrentInfo {
                    List {
                        if torrent.isFailed || torrent.isStuck {
                            Section {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: torrent.isFailed ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(torrent.isFailed ? .red : .orange)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(torrent.statusLabel)
                                            .font(.headline)
                                            .foregroundColor(torrent.isFailed ? .red : .orange)
                                        Text(torrent.isFailed
                                            ? "This torrent failed on Real-Debrid. Delete it and re-add a different source."
                                            : "Files were never selected — this torrent is stuck. Delete it and re-add.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        ForEach(torrentInfo.files) { file in
                        HStack(spacing: 10) {
                            Image(systemName: file.isSubtitle ? "captions.bubble.fill" : "doc.fill")
                                .foregroundColor(file.isSubtitle ? .green : .secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(URL(fileURLWithPath: file.path).lastPathComponent)
                                    .font(.headline)
                                    .lineLimit(2)
                                HStack {
                                    Text("Size: \(formatFileSize(Int64(file.bytes)))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    if let lang = file.subtitleLanguage {
                                        Text("• \(lang)")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                }
                                if let health = viewModel.fileHealth[file.id] {
                                    switch health {
                                    case .checking:
                                        HStack(spacing: 4) {
                                            ProgressView().scaleEffect(0.6)
                                            Text("Checking…")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    case .infringing:
                                        Label("Blocked — copyright claim", systemImage: "exclamationmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    case .failed:
                                        Label("Couldn't verify link", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    case .ok:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        }
                    }
                } else {
                    Text("No file information available.")
                }
            }
            .navigationTitle(torrent.filename)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if viewModel.torrentInfo == nil {
                Task {
                    await viewModel.fetchDetails(id: torrent.id)
                }
            }
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
}
