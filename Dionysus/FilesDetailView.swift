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
                        VStack(alignment: .leading) {
                            Text(file.path)
                                .font(.headline)
                            Text("Size: \(formatFileSize(Int64(file.bytes)))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
