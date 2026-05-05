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
                    List(torrentInfo.files) { file in
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
