import Testing
@testable import Dionysus

@MainActor
struct DebridFilesViewModelTests {

    var viewModel: DebridFilesViewModel!

    @before @MainActor func setup() {
        viewModel = DebridFilesViewModel()
        viewModel.torrents = [
            RealDebridTorrent(id: "1", filename: "Test File 1.mkv", bytes: 100, status: "downloaded"),
            RealDebridTorrent(id: "2", filename: "Another Test File.mp4", bytes: 200, status: "downloading"),
            RealDebridTorrent(id: "3", filename: "Yet Another File.avi", bytes: 300, status: "seeding")
        ]
    }

    @Test func testFilterTorrents() {
        viewModel.searchText = "Test"
        #expect(viewModel.filteredTorrents.count == 2)
        #expect(viewModel.filteredTorrents.allSatisfy { $0.filename.contains("Test") })
    }

    @Test func testFilterTorrents_caseInsensitive() {
        viewModel.searchText = "test"
        #expect(viewModel.filteredTorrents.count == 2)
        #expect(viewModel.filteredTorrents.allSatisfy { $0.filename.lowercased().contains("test") })
    }

    @Test func testFilterTorrents_noResults() {
        viewModel.searchText = "xyz"
        #expect(viewModel.filteredTorrents.isEmpty)
    }

    @Test func testFilterTorrents_emptySearchText() {
        viewModel.searchText = ""
        #expect(viewModel.filteredTorrents.count == 3)
    }
}
