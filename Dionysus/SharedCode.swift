import Foundation
import SwiftUI
import Combine // FIX: Added missing import for ObservableObject and @Published
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import CoreHaptics

// MARK: - Platform-Agnostic Type Aliases
#if canImport(UIKit)
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
#endif

// MARK: - Core Data Models
// FIX: Removed Sendable conformance to resolve build errors with Swift 6 concurrency model.
protocol Media: Codable, Identifiable, Hashable {
    var id: Int { get }
    var overview: String { get }
    var posterPath: String? { get }
    var backdropPath: String? { get }
    var voteAverage: Double { get }
    var title: String { get }
    var releaseDate: String? { get }
}

struct Movie: Media {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let releaseDate: String?
}

struct TVShow: Media {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let firstAirDate: String?
    
    var title: String { name }
    var releaseDate: String? { firstAirDate }
}

enum MediaItem: Identifiable, Hashable {
    case movie(Movie)
    case tvShow(TVShow)

    var id: Int {
        switch self {
        case .movie(let movie): return movie.id
        case .tvShow(let show): return show.id
        }
    }
    
    var underlyingMedia: any Media {
        switch self {
        case .movie(let movie): return movie
        case .tvShow(let show): return show
        }
    }
}

struct Genre: Identifiable, Hashable {
    let id: Int
    let name: String
}

// MARK: - API Related Models
struct MovieResponse: Codable {
    let results: [Movie]
}

struct TVShowResponse: Codable {
    let results: [TVShow]
}


struct VideoResponse: Codable {
    let results: [Video]
}

struct Video: Codable, Identifiable {
    let id: String
    let key: String
    let site: String
    let type: String

    var youtubeURL: URL? {
        guard site == "YouTube" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

struct TorrentResponse: Codable {
    let data: [Torrent]
}

struct Torrent: Codable, Identifiable, Hashable {
    var id: String { magnet ?? name }
    let name: String
    let size: String?
    let seeders: String?
    let leechers: String?
    let magnet: String?
    let quality: String?
    let provider: String?
    
    var infoHash: String? {
        guard let magnet = magnet,
              let range = magnet.range(of: "urn:btih:") else { return nil }
        let hashStartIndex = range.upperBound
        let remainingString = magnet[hashStartIndex...]
        let hashEndIndex = remainingString.firstIndex(of: "&") ?? remainingString.endIndex
        return String(remainingString[..<hashEndIndex]).lowercased()
    }
    
    var formattedSize: String {
        guard let size = size else { return "N/A" }
        if let gbRange = size.range(of: "GB") {
            return String(size[..<gbRange.upperBound])
        }
        if let mbRange = size.range(of: "MB") {
            return String(size[..<mbRange.upperBound])
        }
        return size
    }
}

struct TVShowDetails: Codable {
    let id: Int
    let name: String
    let numberOfSeasons: Int
    let seasons: [SeasonSummary]
}

struct SeasonSummary: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
}

struct SeasonDetails: Codable {
    let id: String
    let episodes: [Episode]
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case episodes
    }
}

struct Episode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let episodeNumber: Int
    let seasonNumber: Int
}


struct RealDebridAddTorrentResponse: Codable {
    let id: String
    let uri: String
}

struct RealDebridTorrent: Codable, Identifiable {
    let id: String
    let filename: String
    let hash: String
    let bytes: Int
    let status: String
}

class APIService {
    static let shared = APIService()
    private init() {}

    private let baseUrl = "https://api.themoviedb.org/3"
    private let dionysusServerBaseURL = "https://dionysus-server-py-production.up.railway.app"

    private func fetch<T: Codable>(from url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    func fetchMovies(from endpoint: String) async throws -> [Movie] {
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(Secrets.tmdbApiKey)")!
        let response: MovieResponse = try await fetch(from: url)
        return response.results
    }

    func fetchTVShows(from endpoint: String) async throws -> [TVShow] {
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(Secrets.tmdbApiKey)")!
        let response: TVShowResponse = try await fetch(from: url)
        return response.results
    }
    
    func searchAll(query: String) async throws -> [MediaItem] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let movieUrl = URL(string: "\(baseUrl)/search/movie?api_key=\(Secrets.tmdbApiKey)&query=\(encodedQuery)")!
        let tvShowUrl = URL(string: "\(baseUrl)/search/tv?api_key=\(Secrets.tmdbApiKey)&query=\(encodedQuery)")!
        
        async let movies: MovieResponse = try fetch(from: movieUrl)
        async let tvShows: TVShowResponse = try fetch(from: tvShowUrl)
        
        let fetchedMovies = (try? await movies)?.results ?? []
        let fetchedTVShows = (try? await tvShows)?.results ?? []
        
        return (fetchedMovies.map(MediaItem.movie) + fetchedTVShows.map(MediaItem.tvShow))
            .sorted { $0.underlyingMedia.voteAverage > $1.underlyingMedia.voteAverage }
    }

    func fetchVideos(for media: any Media) async throws -> [Video] {
        let endpoint = media is Movie ? "/movie/\(media.id)/videos" : "/tv/\(media.id)/videos"
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(Secrets.tmdbApiKey)")!
        let response: VideoResponse = try await fetch(from: url)
        return response.results.filter { $0.site == "YouTube" }
    }
    
    func searchTorrents(query: String, forceRefresh: Bool = false) async throws -> [Torrent] {
        let torrentApiUrl = "https://dionysus-server-py-production.up.railway.app"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var urlString = "\(torrentApiUrl)/api/v1/all/search?query=\(encodedQuery)"
        if forceRefresh {
            urlString += "&force_refresh=true"
        }
        
        let url = URL(string: urlString)!
        let response: TorrentResponse = try await fetch(from: url)
        return response.data
    }
    
    func fetchUserTorrentHashes() async throws -> Set<String> {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Secrets.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let userTorrents = try JSONDecoder().decode([RealDebridTorrent].self, from: data)
        return Set(userTorrents.map { $0.hash.lowercased() })
    }
    
    func fetchTVShowDetails(id: Int) async throws -> TVShowDetails {
        let url = URL(string: "\(baseUrl)/tv/\(id)?api_key=\(Secrets.tmdbApiKey)")!
        return try await fetch(from: url)
    }

    func fetchSeasonDetails(tvShowId: Int, seasonNumber: Int) async throws -> SeasonDetails {
        let url = URL(string: "\(baseUrl)/tv/\(tvShowId)/season/\(seasonNumber)?api_key=\(Secrets.tmdbApiKey)")!
        return try await fetch(from: url)
    }
    
    func fetchDiscoverMedia(genreId: Int) async throws -> [MediaItem] {
        let movieUrl = URL(string: "\(baseUrl)/discover/movie?api_key=\(Secrets.tmdbApiKey)&with_genres=\(genreId)")!
        let tvUrl = URL(string: "\(baseUrl)/discover/tv?api_key=\(Secrets.tmdbApiKey)&with_genres=\(genreId)")!
        
        async let movies: MovieResponse = try fetch(from: movieUrl)
        async let tvShows: TVShowResponse = try fetch(from: tvUrl)
        
        let fetchedMovies = (try? await movies)?.results ?? []
        let fetchedTVShows = (try? await tvShows)?.results ?? []
        
        return (fetchedMovies.map(MediaItem.movie) + fetchedTVShows.map(MediaItem.tvShow))
            .sorted { $0.underlyingMedia.voteAverage > $1.underlyingMedia.voteAverage }
    }
    
    func addAndSelectTorrent(magnet: String) async throws {
        let addedTorrent = try await addMagnetToRealDebrid(magnet: magnet)
        try await selectTorrentFiles(torrentId: addedTorrent.id)
    }

    private func addMagnetToRealDebrid(magnet: String) async throws -> RealDebridAddTorrentResponse {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/addMagnet")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "magnet=\(magnet.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RealDebridAddTorrentResponse.self, from: data)
    }
    
    private func selectTorrentFiles(torrentId: String) async throws {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/\(torrentId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "files=all".data(using: .utf8)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }
}


// MARK: - ViewModels (Shared)
@MainActor
class HomeViewModel: ObservableObject {
    @Published var trendingMovies: [MediaItem] = []
    @Published var popularMovies: [MediaItem] = []
    @Published var trendingShows: [MediaItem] = []
    @Published var popularShows: [MediaItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadAllContent() async {
        isLoading = true
        errorMessage = nil
        do {
            async let trendingMoviesFetch = APIService.shared.fetchMovies(from: "/trending/movie/week")
            async let popularMoviesFetch = APIService.shared.fetchMovies(from: "/movie/popular")
            async let trendingShowsFetch = APIService.shared.fetchTVShows(from: "/trending/tv/week")
            async let popularShowsFetch = APIService.shared.fetchTVShows(from: "/tv/popular")

            let (trMovies, popMovies, trShows, popShows) = try await (trendingMoviesFetch, popularMoviesFetch, trendingShowsFetch, popularShowsFetch)
            self.trendingMovies = trMovies.map(MediaItem.movie)
            self.popularMovies = popMovies.map(MediaItem.movie)
            self.trendingShows = trShows.map(MediaItem.tvShow)
            self.popularShows = popShows.map(MediaItem.tvShow)
        } catch {
            self.errorMessage = "Failed to load content."
        }
        isLoading = false
    }
}

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [MediaItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var query = ""

    func performSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            searchResults = try await APIService.shared.searchAll(query: query)
        } catch {
            self.errorMessage = "Search failed."
        }
        isLoading = false
    }
}

enum LoadingState {
    case idle, loading, success, error
}

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var torrents: [Torrent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addState: LoadingState = .idle
    @Published var existingTorrentHashes: Set<String> = []
    
    func fetchTorrents(for query: String, forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            async let searchResult = APIService.shared.searchTorrents(query: query, forceRefresh: forceRefresh)
            async let hashesResult = APIService.shared.fetchUserTorrentHashes()
            let (fetchedTorrents, fetchedHashes) = try await (searchResult, hashesResult)
            self.torrents = fetchedTorrents
            self.existingTorrentHashes = fetchedHashes
        } catch {
            self.errorMessage = "Failed to fetch sources."
        }
        isLoading = false
    }
    
    func addTorrent(magnet: String) async {
        addState = .loading
        do {
            try await APIService.shared.addAndSelectTorrent(magnet: magnet)
            addState = .success
            HapticManager.shared.success()
            if let newHash = Torrent(name: "", size: nil, seeders: nil, leechers: nil, magnet: magnet, quality: nil, provider: nil).infoHash {
                existingTorrentHashes.insert(newHash)
            }
        } catch {
            addState = .error
        }
    }
}

@MainActor
class TVDetailViewModel: ObservableObject {
    @Published var showDetails: TVShowDetails?
    @Published var selectedSeasonDetails: SeasonDetails?
    @Published var isLoadingDetails = false
    @Published var isLoadingSeason = false
    
    func fetchDetails(for showId: Int) async {
        isLoadingDetails = true
        do {
            showDetails = try await APIService.shared.fetchTVShowDetails(id: showId)
            if let firstSeason = showDetails?.seasons.first(where: { $0.seasonNumber > 0 }) ?? showDetails?.seasons.first {
                await fetchSeason(tvShowId: showId, seasonNumber: firstSeason.seasonNumber)
            }
        } catch {
            
        }
        isLoadingDetails = false
    }
    
    func fetchSeason(tvShowId: Int, seasonNumber: Int) async {
        isLoadingSeason = true
        do {
            selectedSeasonDetails = try await APIService.shared.fetchSeasonDetails(tvShowId: tvShowId, seasonNumber: seasonNumber)
        } catch {
            
        }
        isLoadingSeason = false
    }
}

@MainActor
class GenreViewModel: ObservableObject {
    @Published var media: [MediaItem] = []
    @Published var isLoading = true
    
    func loadMedia(for genreId: Int) async {
        isLoading = true
        do {
            media = try await APIService.shared.fetchDiscoverMedia(genreId: genreId)
        } catch {
            
        }
        isLoading = false
    }
}


// MARK: - Views (Shared with adaptations for macOS)

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                BlobBackgroundView(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], isAnimating: true)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    HomeLoadingView()
                        .transition(.opacity.animation(.easeInOut))
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) { Task { await viewModel.loadAllContent() } }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            MediaCarouselView(title: "Trending Movies", items: viewModel.trendingMovies)
                            MediaCarouselView(title: "Trending TV Shows", items: viewModel.trendingShows)
                            MediaCarouselView(title: "Popular Movies", items: viewModel.popularMovies)
                            MediaCarouselView(title: "Popular TV Shows", items: viewModel.popularShows)
                        }
                        .padding(.vertical).padding(.bottom, 80)
                    }
                    .refreshable { await viewModel.loadAllContent() }
                    .toolbar { ToolbarItem(placement: .principal) { DionysusTitleView() } }
                    #if os(iOS)
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    #endif
                    .navigationDestination(for: MediaItem.self) { item in
                        MediaDetailView(media: item.underlyingMedia, showCustomDismissButton: true)
                    }
                }
            }
        }
        .task { if viewModel.trendingMovies.isEmpty { await viewModel.loadAllContent() } }
    }
}

struct MediaCarouselView: View {
    let title: String
    let items: [MediaItem]
    
    @State private var pressedItemId: Int? = nil
    @State private var centeredItemID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.custom("Eurostile-Regular", size: 22)).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(items) { item in
                        GeometryReader { geometry in
                            let itemFrame = geometry.frame(in: .global)
                            #if os(macOS)
                            let screenCenter = NSScreen.main?.visibleFrame.width ?? 800 / 2
                            #else
                            let screenCenter = UIScreen.main.bounds.width / 2
                            #endif
                            let isCentered = abs(itemFrame.midX - screenCenter) < 75

                            NavigationLink(value: item) {
                                MediaPosterView(media: item.underlyingMedia)
                                    .scaleEffect(pressedItemId == item.id ? 0.95 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onLongPressGesture(minimumDuration: .infinity, pressing: { isPressing in
                                withAnimation(.bouncy(duration: 0.2)) {
                                    pressedItemId = isPressing ? item.id : nil
                                }
                            }, perform: {})
                            .onChange(of: isCentered) {
                                if isCentered {
                                    centeredItemID = item.id
                                }
                            }
                        }
                        .frame(width: 150, height: 225)
                    }
                }
                .padding(.horizontal)
            }
            .sensoryFeedback(.selection, trigger: centeredItemID)
        }
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedMediaItem: MediaItem?
    // FIX: Added state for the debounce task to prevent cycles
    @State private var searchTask: Task<Void, Never>? = nil
    
    private let genres: [(genre: Genre, colors: [Color])] = [
        (Genre(id: 28, name: "Action"), [.blue, .purple]), (Genre(id: 12, name: "Adventure"), [.green, .blue]),
        (Genre(id: 16, name: "Animation"), [.orange, .red]), (Genre(id: 35, name: "Comedy"), [.yellow, .orange]),
        (Genre(id: 80, name: "Crime"), [.gray, .black]), (Genre(id: 99, name: "Documentary"), [.white.opacity(0.8), .gray]),
        (Genre(id: 18, name: "Drama"), [.red, .purple]), (Genre(id: 10751, name: "Family"), [.pink, .orange]),
        (Genre(id: 14, name: "Fantasy"), [.purple, .pink]), (Genre(id: 36, name: "History"), [.yellow, .gray]),
        (Genre(id: 27, name: "Horror"), [.red, .black]), (Genre(id: 10402, name: "Music"), [.pink, .purple]),
        (Genre(id: 9648, name: "Mystery"), [.indigo, .black]), (Genre(id: 10749, name: "Romance"), [.red, .pink]),
        (Genre(id: 878, name: "Sci-Fi"), [.blue, .cyan]), (Genre(id: 53, name: "Thriller"), [.cyan, .black]),
        (Genre(id: 10752, name: "War"), [.green, .gray]), (Genre(id: 37, name: "Western"), [.yellow, .black])
    ]
    
    var body: some View {
        NavigationSplitView {
            NavigationStack {
                sidebarView
                    .navigationDestination(for: Genre.self) { genre in
                        GenreResultsView(genre: genre)
                    }
                    .navigationDestination(for: MediaItem.self) { item in
                        MediaDetailView(media: item.underlyingMedia, showCustomDismissButton: true)
                    }
            }
            // FIX: Moved searchable and debounced onChange to the stable NavigationStack to prevent cycles
            .searchable(text: $viewModel.query, prompt: "Search movies & TV shows...")
            .onChange(of: viewModel.query) {
                searchTask?.cancel()
                searchTask = Task {
                    do {
                        try await Task.sleep(for: .milliseconds(300))
                        await viewModel.performSearch()
                    } catch {
                        // This handles the task being cancelled, which is expected
                    }
                }
            }
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.automatic)
    }

    @ViewBuilder
    private var sidebarView: some View {
        Group {
            if viewModel.query.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 15) {
                        ForEach(genres, id: \.genre) { item in
                            NavigationLink(value: item.genre) { GenreButtonView(genre: item.genre, gradient: item.colors) }
                        }
                    }
                    .padding().padding(.bottom, 80)
                }
            } else {
                if viewModel.isLoading { ProgressView() }
                else if let errorMessage = viewModel.errorMessage { Text(errorMessage) }
                else if viewModel.searchResults.isEmpty { Text("No results for \"\(viewModel.query)\"") }
                else {
                    List(viewModel.searchResults, selection: $selectedMediaItem) { item in
                        NavigationLink(value: item) {
                            SearchResultRow(media: item.underlyingMedia)
                                .sensoryFeedback(.impact(weight: .light), trigger: selectedMediaItem)
                        }
                    }
                    .listStyle(.plain).padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Search")
    }

    @ViewBuilder
    private var detailView: some View {
        if let selectedMediaItem {
            MediaDetailView(media: selectedMediaItem.underlyingMedia, showCustomDismissButton: false)
        } else {
            Text("Select an item to view details")
        }
    }
}

struct MediaDetailView: View {
    let media: any Media
    let showCustomDismissButton: Bool
    
    @State private var trailerURL: URL?
    @State private var showContent = false
    @State private var librarySearchQuery: String?
    @State private var themeColors: [Color] = []
    @Environment(\.dismiss) private var dismiss
    
    private var releaseYear: String {
        (media.releaseDate?.split(separator: "-").first).map(String.init) ?? "N/A"
    }
    
    private var searchQuery: String {
        (media is TVShow) ? "\(media.title) complete" : "\(media.title) \(releaseYear)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            mainDetailContent
                .frame(maxWidth: .infinity)

            SourcesView(searchQuery: searchQuery)
                .frame(maxWidth: 450)
                .background(.black.opacity(0.2))
        }
        .background(
            ZStack {
                if themeColors.isEmpty { Color.black.ignoresSafeArea() }
                else {
                    BlobBackgroundView(colors: themeColors, isAnimating: true)
                        .ignoresSafeArea()
                        .transition(.opacity.animation(.easeInOut))
                }
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn) { showContent = true }
            }
        }
        .task {
            async let colorTask: () = fetchAndSetThemeColors()
            async let videoTask: () = fetchVideos()
            _ = await (colorTask, videoTask)
        }
    }

    private var mainDetailContent: some View {
        ScrollView {
            GeometryReader { geo in
                let scrollY = geo.frame(in: .named("detailScroll")).minY
                AsyncImage(url: media.backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280/\($0)") }) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    default: EmptyView()
                    }
                }
                .offset(y: scrollY > 0 ? -scrollY : 0)
                .scaleEffect(scrollY > 0 ? (scrollY / 1000) + 1 : 1, anchor: .bottom)
            }
            .frame(height: 300)
            
            VStack(alignment: .leading, spacing: 0) {
                HeaderView(media: media, releaseYear: releaseYear)
                    .padding(.top, -50).padding(.bottom, 15)
                
                 if let trailerURL {
                     Link(destination: trailerURL) { Label("Play Trailer", systemImage: "play.circle.fill") }
                        .buttonStyle(.bordered)
                        .padding()
                }

                if let show = media as? TVShow {
                    TVShowDetailContentView(show: show, themeColor: themeColors.first)
                }
                OverviewView(overview: media.overview)
            }
            .padding(.bottom, 120).opacity(showContent ? 1 : 0)
        }
        .coordinateSpace(name: "detailScroll")
        .background(Color.clear)
        .ignoresSafeArea()
    }
    
    private func fetchVideos() async {
        do {
            let videos = try await APIService.shared.fetchVideos(for: media)
            self.trailerURL = videos.first?.youtubeURL
        } catch { }
    }
    
    private func fetchAndSetThemeColors() async {
        guard let posterPath = media.posterPath, let url = URL(string: "https://image.tmdb.org/t/p/w500/\(posterPath)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = PlatformImage(data: data) else { return }
            
            let primaryUIColors: [Color] = [.purple, .blue] // Placeholder
            let newColors = primaryUIColors.map { $0.darker(by: 0.6) }
            
            await MainActor.run { withAnimation { self.themeColors = newColors } }
        } catch { }
    }
}

struct SourcesView: View {
    @StateObject private var viewModel = LibraryViewModel()
    let searchQuery: String
    
    @State private var selectedQuality: String = "All"
    @State private var selectedAVQuality: AVQuality = .normal
    @State private var filterText: String = ""
    
    private let qualityOptions = ["All", "2160p", "1080p", "720p"]
    
    private var finalSearchQuery: String {
        var query = searchQuery
        if let term = selectedAVQuality.queryTerm {
            query += " \(term)"
        }
        return query
    }
    
    private var providerOptions: [String] { ["All"] + Set(viewModel.torrents.compactMap { $0.provider }).sorted() }
    
    private var filteredTorrents: [Torrent] {
        var torrents = viewModel.torrents
        if selectedQuality != "All" { torrents = torrents.filter { $0.quality == selectedQuality } }
        if !filterText.isEmpty { torrents = torrents.filter { $0.name.localizedCaseInsensitiveContains(filterText) } }
        return torrents
    }
    
    var body: some View {
        ZStack {
            VStack {
                VStack {
                    Picker("Quality", selection: $selectedQuality) { ForEach(qualityOptions, id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    Picker("Audio/Video", selection: $selectedAVQuality) {
                        ForEach(AVQuality.allCases) { quality in Text(quality.rawValue).tag(quality) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Filter by name...", text: $filterText)
                        .textFieldStyle(.roundedBorder)
                        .padding(8)
                }
                .padding(.horizontal)

                Group {
                    if viewModel.isLoading { ProgressView() }
                    else if let errorMessage = viewModel.errorMessage { ErrorView(message: errorMessage) { Task { await viewModel.fetchTorrents(for: finalSearchQuery) } } }
                    else if filteredTorrents.isEmpty { Text("No Sources Found") }
                    else {
                        List(filteredTorrents) { torrent in
                            let isAdded = torrent.infoHash.flatMap { viewModel.existingTorrentHashes.contains($0) } ?? false
                            TorrentRowView(torrent: torrent, isAlreadyAdded: isAdded) { magnet in Task { await viewModel.addTorrent(magnet: magnet) } }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Sources")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem {
                    Button { Task { await viewModel.fetchTorrents(for: finalSearchQuery, forceRefresh: true) } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                }
            }
            .task(id: finalSearchQuery) { await viewModel.fetchTorrents(for: finalSearchQuery, forceRefresh: false) }
            .onChange(of: viewModel.addState) { if viewModel.addState == .success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { viewModel.addState = .idle }
            }}
            if viewModel.addState != .idle { StatusOverlayView(addState: $viewModel.addState) }
        }
    }
}

// MARK: - Reusable UI Components (Shared)

struct BlobBackgroundView: View {
    @State var animate = false
    let colors: [Color]
    let isAnimating: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if colors.count > 1 {
                    Circle().fill(colors[0]).frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6).offset(x: 0, y: 0).offset(x: animate && isAnimating ? geometry.size.width * 0.25 : -geometry.size.width * 0.25, y: animate && isAnimating ? -geometry.size.height * 0.25 : geometry.size.height * 0.25)
                    Circle().fill(colors[1]).frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7).offset(x: 0, y: 0).offset(x: animate && isAnimating ? -geometry.size.width * 0.25 : geometry.size.width * 0.25, y: animate && isAnimating ? geometry.size.height * 0.25 : -geometry.size.height * 0.25)
                    Circle().fill(colors[0]).frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5).offset(x: 0, y: 0).offset(x: animate && isAnimating ? -geometry.size.width * 0.1 : geometry.size.width * 0.1, y: animate && isAnimating ? -geometry.size.height * 0.25 : geometry.size.height * 0.25)
                    Circle().fill(colors[1]).frame(width: geometry.size.width * 0.55, height: geometry.size.width * 0.55).offset(x: 0, y: 0).offset(x: animate && isAnimating ? geometry.size.width * 0.1 : -geometry.size.width * 0.1, y: animate && isAnimating ? geometry.size.height * 0.25 : -geometry.size.height * 0.25)
                } else {
                     LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                }
            }
            .blur(radius: 60)
            .animation(isAnimating ? .easeInOut(duration: 15).repeatForever(autoreverses: true) : nil, value: animate)
            .onAppear {
                if isAnimating {
                    animate = true
                }
            }
        }
    }
}


struct DionysusTitleView: View {
    var body: some View {
        Text("Dionysus").font(.custom("Eurostile-Regular", size: 34))
            .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
    }
}

struct MediaPosterView: View {
    let media: any Media

    var body: some View {
        AsyncImage(url: media.posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500/\($0)") }) { phase in
            switch phase {
            case .empty: ProgressView()
            case .success(let image): image.resizable()
            case .failure:
                Image(systemName: "film").font(.largeTitle).foregroundColor(.secondary)
            @unknown default: EmptyView()
            }
        }
        .aspectRatio(2/3, contentMode: .fit).background(Color.gray.opacity(0.3))
        .cornerRadius(12).shadow(radius: 5)
    }
}

struct SearchResultRow: View {
    let media: any Media
    
    var body: some View {
        HStack(spacing: 15) {
            MediaPosterView(media: media).frame(width: 70, height: 105)
            VStack(alignment: .leading, spacing: 5) {
                Text(media.title).font(.custom("Eurostile-Regular", size: 18))
                Text((media.releaseDate?.split(separator: "-").first).map(String.init) ?? "N/A")
                    .font(.custom("Eurostile-Regular", size: 14)).foregroundColor(.secondary)
                Text(media is Movie ? "Movie" : "TV Show").font(.custom("Eurostile-Regular", size: 12)).fontWeight(.bold)
                    .foregroundColor(media is Movie ? .cyan : .orange)
                Text(media.overview).font(.custom("Eurostile-Regular", size: 13)).foregroundColor(.gray).lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.red)
            Text(message).font(.custom("Eurostile-Regular", size: 16)).multilineTextAlignment(.center).padding()
            Button("Retry", action: retryAction).buttonStyle(.borderedProminent)
        }
    }
}

struct HeaderView: View {
    let media: any Media
    let releaseYear: String
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            MediaPosterView(media: media)
                .frame(width: 120, height: 180)
            
            VStack(alignment: .leading) {
                Text(media.title).font(.custom("Eurostile-Regular", size: 28))
                Text("\(releaseYear) • \(String(format: "%.1f", media.voteAverage)) ★")
                    .font(.custom("Eurostile-Regular", size: 16)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ActionButtonsView: View {
    let trailerURL: URL?
    let addToAction: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: addToAction) { Label("Add to Library", systemImage: "plus.circle.fill") }
                .buttonStyle(.borderedProminent).tint(.blue)
            if let trailerURL {
                Link(destination: trailerURL) { Label("Play Trailer", systemImage: "play.circle.fill") }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

struct OverviewView: View {
    let overview: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview").font(.custom("Eurostile-Regular", size: 22))
            Text(overview).font(.custom("Eurostile-Regular", size: 16))
        }
        .padding()
    }
}

enum AVQuality: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case dolbyVision = "Dolby Vision"
    case dolbyAtmos = "Dolby Atmos"
    
    var id: String { self.rawValue }
    
    var queryTerm: String? {
        switch self {
        case .normal: return nil
        case .dolbyVision: return "vision"
        case .dolbyAtmos: return "atmos"
        }
    }
}

struct TorrentRowView: View {
    let torrent: Torrent
    let isAlreadyAdded: Bool
    let addAction: (String) -> Void
    
    var body: some View {
        Button(action: { if let magnet = torrent.magnet { HapticManager.shared.impact(); addAction(magnet) } }) {
            VStack(alignment: .leading, spacing: 10) {
                Text(torrent.name).font(.custom("Eurostile-Regular", size: 16)).lineLimit(3).foregroundColor(.primary)
                HStack {
                    Text(torrent.provider ?? "Unknown").font(.custom("Eurostile-Regular", size: 12)).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.3)).cornerRadius(8)
                    if let quality = torrent.quality { Text(quality).font(.custom("Eurostile-Regular", size: 12)).padding(.horizontal, 8).padding(.vertical, 4).background(Color.purple.opacity(0.3)).cornerRadius(8) }
                    Spacer()
                }
                HStack(spacing: 4) {
                    Label(torrent.formattedSize, systemImage: "opticaldiscdrive"); Spacer()
                    Label(torrent.seeders ?? "0", systemImage: "arrow.up.circle.fill").foregroundColor(.green); Spacer()
                    Label(torrent.leechers ?? "0", systemImage: "arrow.down.circle.fill").foregroundColor(.red)
                    if isAlreadyAdded { Spacer(); Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                }
                .font(.custom("Eurostile-Regular", size: 14)).foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(torrent.magnet == nil || isAlreadyAdded)
    }
}

struct TVShowDetailContentView: View {
    @StateObject private var viewModel = TVDetailViewModel()
    let show: TVShow
    let themeColor: Color?
    @State private var selectedSeason: Int = 1
    @State private var librarySearchQuery: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            if viewModel.isLoadingDetails { ProgressView().padding() }
            else if let details = viewModel.showDetails {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Seasons").font(.custom("Eurostile-Regular", size: 22))
                    let seasons = details.seasons.filter { $0.seasonNumber > 0 }
                    if !seasons.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(seasons) { season in
                                    Button { selectedSeason = season.seasonNumber } label: { Text("Season \(season.seasonNumber)").font(.custom("Eurostile-Regular", size: 14)).padding(.horizontal, 16).padding(.vertical, 8).background(selectedSeason == season.seasonNumber ? Color.blue : Color.white.opacity(0.1)).foregroundColor(.white).cornerRadius(10) }
                                }
                            }
                        }
                        .onChange(of: selectedSeason) { Task { await viewModel.fetchSeason(tvShowId: show.id, seasonNumber: selectedSeason) } }
                    }
                    if viewModel.isLoadingSeason { ProgressView().frame(maxWidth: .infinity) }
                    else if let seasonDetails = viewModel.selectedSeasonDetails {
                        HStack(spacing: 15) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(.yellow)
                            
                            VStack(alignment: .leading) {
                                Text("Season \(selectedSeason)")
                                    .font(.custom("Eurostile-Regular", size: 14)).foregroundColor(.secondary)
                                Text("Search for Full Season Pack")
                                    .font(.custom("Eurostile-Regular", size: 16)).fontWeight(.bold)
                            }
                            Spacer()
                            Button {
                                let query = "\(show.title) S\(String(format: "%02d", selectedSeason))"
                                librarySearchQuery = query
                            } label: { Image(systemName: "plus.circle.fill") }.buttonStyle(.bordered)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill((themeColor ?? .blue).opacity(0.25))
                                .shadow(color: (themeColor ?? .blue).opacity(0.5), radius: 8, x: 0, y: 4)
                        )
                        .padding(.vertical, 8)

                        Divider()
                        
                        if seasonDetails.episodes.isEmpty {
                            Text("No episodes found for this season.")
                                .font(.custom("Eurostile-Regular", size: 16))
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(seasonDetails.episodes) { episode in
                                EpisodeRowView(showTitle: show.title, episode: episode) { query in librarySearchQuery = query }
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            await viewModel.fetchDetails(for: show.id)
            if let firstSeason = viewModel.showDetails?.seasons.first(where: { $0.seasonNumber > 0 }) ?? viewModel.showDetails?.seasons.first { selectedSeason = firstSeason.seasonNumber }
        }
        .sheet(item: $librarySearchQuery) { query in SourcesView(searchQuery: query) }
    }
}

struct EpisodeRowView: View {
    let showTitle: String
    let episode: Episode
    let addToAction: (String) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Episode \(episode.episodeNumber)").font(.custom("Eurostile-Regular", size: 14)).foregroundColor(.secondary)
                Text(episode.name).font(.custom("Eurostile-Regular", size: 16))
            }
            Spacer()
            Button {
                let query = "\(showTitle) S\(String(format: "%02d", episode.seasonNumber))E\(String(format: "%02d", episode.episodeNumber))"
                addToAction(query)
            } label: { Image(systemName: "plus.circle.fill") }.buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
}

struct GenreButtonView: View {
    let genre: Genre
    let gradient: [Color]
    @State private var isPressed = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: gradient), startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(genre.name).font(.custom("Eurostile-Regular", size: 24)).foregroundColor(.white).fontWeight(.bold).shadow(radius: 5)
        }
        .frame(height: 100).cornerRadius(20).clipped().scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in withAnimation(.spring()) { isPressed = pressing } }, perform: {})
    }
}

struct GenreResultsView: View {
    @StateObject private var viewModel = GenreViewModel()
    let genre: Genre
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading { ProgressView() }
            else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.media) { item in
                        NavigationLink(value: item) { MediaPosterView(media: item.underlyingMedia) }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(genre.name)
        .task { await viewModel.loadMedia(for: genre.id) }
    }
}

struct StatusOverlayView: View {
    @Binding var addState: LoadingState
    
    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.5)).ignoresSafeArea()
            VStack {
                switch addState {
                case .loading: ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(2)
                case .success: Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundColor(.green).transition(.scale.animation(.spring()))
                case .error: Image(systemName: "xmark.circle.fill").font(.system(size: 60)).foregroundColor(.red).transition(.scale.animation(.spring()))
                case .idle: EmptyView()
                }
            }
            .padding(40).background(.ultraThinMaterial).cornerRadius(20)
        }
        .onChange(of: addState) { if addState == .success || addState == .error { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { addState = .idle } } } }
    }
}

struct HomeLoadingView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 30) {
                ForEach(0..<4) { _ in
                    VStack(alignment: .leading, spacing: 15) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 200, height: 24)
                            .padding(.horizontal)
                        HStack(spacing: 20) {
                            ForEach(0..<3) { _ in
                                 RoundedRectangle(cornerRadius: 12)
                                    .fill(.gray.opacity(0.3))
                                    .frame(width: 150, height: 225)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical).padding(.bottom, 80)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

// MARK: - Helpers & Extensions

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -2.0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black.opacity(0.6), location: phase),
                        .init(color: .white.opacity(0.3), location: phase + 0.1),
                        .init(color: .black.opacity(0.6), location: phase + 0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: phase)
            )
            .onAppear { phase = 2.0 }
    }
}

extension View {
    func shimmering() -> some View {
        self.modifier(Shimmer())
    }
}

class HapticManager {
    static let shared = HapticManager()
    
    #if os(macOS)
    private let feedbackManager = NSHapticFeedbackManager.defaultPerformer
    #else
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    #endif

    private init() {
        #if os(iOS)
        selectionGenerator.prepare()
        impactGenerator.prepare()
        lightImpactGenerator.prepare()
        rigidImpactGenerator.prepare()
        notificationGenerator.prepare()
        #endif
    }
    
    func impact() {
        #if os(macOS)
        feedbackManager.perform(.generic, performanceTime: .now)
        #else
        impactGenerator.impactOccurred()
        #endif
    }
    
    func success() {
        #if os(macOS)
        feedbackManager.perform(.generic, performanceTime: .now)
        #else
        notificationGenerator.notificationOccurred(.success)
        #endif
    }

    func playScrollTick() {
        #if os(macOS)
        feedbackManager.perform(.levelChange, performanceTime: .now)
        #else
        lightImpactGenerator.impactOccurred()
        #endif
    }

    func playDragStart() {
        #if os(macOS)
        feedbackManager.perform(.generic, performanceTime: .now)
        #else
        rigidImpactGenerator.impactOccurred()
        #endif
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

#if os(iOS)
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
#endif

// FIX: Added missing color extension
extension Color {
    func darker(by percentage: Double) -> Color {
        let platformColor = PlatformColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        
        // FIX: On macOS, we must convert to a standard colorspace before getting components.
        let rgbColor = platformColor.usingColorSpace(.sRGB) ?? platformColor
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return Color(PlatformColor(
            red: max(0, red - percentage),
            green: max(0, green - percentage),
            blue: max(0, blue - percentage),
            alpha: alpha
        ))
    }
}


#if os(macOS)
extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#else
extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#endif

