import SwiftUI
import TVServices

@MainActor
class DeepLinkManager: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var sourceSheetQuery: String?

    func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        let host = components.host
        let pathComponents = components.path.split(separator: "/").map(String.init)
        
        if host == "sources" {
            if let queryItem = components.queryItems?.first(where: { $0.name == "query" }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.sourceSheetQuery = queryItem.value
                }
            }
            return
        }
        
        guard (host == "movie" || host == "tv"),
              pathComponents.count == 1,
              let id = Int(pathComponents[0]) else {
            return
        }
        
        Task {
            do {
                let mediaItem: MediaItem
                if host == "movie" {
                    let movie = try await APIService.shared.fetchMovie(id: id)
                    mediaItem = .movie(movie)
                } else {
                    let show = try await APIService.shared.fetchTVShow(id: id)
                    mediaItem = .tvShow(show)
                }
                
                navigationPath = NavigationPath()
                navigationPath.append(mediaItem)
                
            } catch {
                
            }
        }
    }
}

@main
struct DionysusAppTV: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

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
            try? await Task.sleep(for: .seconds(1.5))
            
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

struct ContentView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var deepLinkManager = DeepLinkManager()

    var body: some View {
        NavigationStack(path: $deepLinkManager.navigationPath) {
            TabView {
                HomeView(viewModel: homeViewModel)
                    .tabItem { Label("Home", systemImage: "house") }
                
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
            }
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(media: item.underlyingMedia)
            }
            .navigationDestination(for: Genre.self) { genre in
                GenreResultsView(genre: genre)
            }
        }
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            deepLinkManager.handleURL(url)
        }
        .sheet(item: $deepLinkManager.sourceSheetQuery) { query in
            LibraryActionSheetView(searchQuery: query)
        }
    }
}

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var themeColors: [Color] = [.purple.opacity(0.8), .blue.opacity(0.8)]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            BlobBackgroundView(colors: themeColors, isAnimating: true)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: themeColors)

            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ErrorView(message: errorMessage) { Task { await viewModel.loadAllContent() } }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    DionysusTitleView()
                        .padding(.horizontal, 60)
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 60) {
                            MediaCarouselView(title: "Trending Movies", items: viewModel.trendingMovies, themeColors: $themeColors)
                            MediaCarouselView(title: "Trending TV Shows", items: viewModel.trendingShows, themeColors: $themeColors)
                            MediaCarouselView(title: "Popular Movies", items: viewModel.popularMovies, themeColors: $themeColors)
                            MediaCarouselView(title: "Popular TV Shows", items: viewModel.popularShows, themeColors: $themeColors)
                        }
                        .padding([.bottom,.top], 40)
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
    @Binding var themeColors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).font(.title2).fontWeight(.bold).padding(.horizontal, 60)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 40) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            MediaPosterView(media: item.underlyingMedia)
                                .frame(width: 300, height: 450)
                        }
                        .buttonStyle(.card)
                        .onFocusChange { isFocused in
                            if isFocused {
                                Task {
                                    await updateThemeColors(for: item.underlyingMedia)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 40)
            }
            .clipped(antialiased: false)
        }
    }

    private func updateThemeColors(for media: any Media) async {
        guard let posterPath = media.posterPath, let url = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)") else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            
            let primaryUIColors = ColorExtractor.extractPrimaryColors(from: image)
            let newColors = primaryUIColors.map { Color($0).darker(by: 0.6) }
            
            await MainActor.run {
                if !newColors.isEmpty {
                    self.themeColors = newColors
                }
            }
        } catch {
            
        }
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
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
        Group {
            if viewModel.query.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 40) {
                        ForEach(genres, id: \.genre) { item in
                            NavigationLink(value: item.genre) { GenreButtonView(genre: item.genre, gradient: item.colors) }
                                .buttonStyle(.card)
                        }
                    }
                    .padding(60)
                }
            } else {
                if viewModel.isLoading { ProgressView() }
                else if let errorMessage = viewModel.errorMessage { Text(errorMessage) }
                else if viewModel.searchResults.isEmpty { Text("No results for \"\(viewModel.query)\"").font(.title2) }
                else {
                    List(viewModel.searchResults) { item in
                        NavigationLink(value: item) { SearchResultRow(media: item.underlyingMedia) }
                    }
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search movies & TV shows...")
        .onChange(of: viewModel.query) { Task { await viewModel.performSearch() } }
    }
}

struct MediaDetailView: View {
    let media: any Media
    
    @State private var trailerURL: URL?
    @State private var showContent = false
    @State private var librarySearchQuery: String?
    @State private var themeColors: [Color] = []
    @State private var showTrailerQRCode = false
    
    private var releaseYear: String {
        (media.releaseDate?.split(separator: "-").first).map(String.init) ?? "N/A"
    }

    var body: some View {
        ZStack {
            if themeColors.isEmpty {
                Color.black.ignoresSafeArea()
            } else {
                BlobBackgroundView(colors: themeColors, isAnimating: true)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    HeaderView(media: media, releaseYear: releaseYear)
                    
                    ActionButtonsView(trailerURL: trailerURL, addToAction: {
                        librarySearchQuery = (media is TVShow) ? "\(media.title) complete" : "\(media.title) \(releaseYear)"
                    }, playTrailerAction: {
                        showTrailerQRCode = true
                    })
                    
                    if let show = media as? TVShow {
                        TVShowDetailContentView(show: show, themeColor: themeColors.first)
                    }
                    
                    OverviewView(overview: media.overview)
                }
                .padding(60)
                .opacity(showContent ? 1 : 0)
            }
        }
        .sheet(item: $librarySearchQuery) { query in
            LibraryActionSheetView(searchQuery: query)
        }
        .sheet(isPresented: $showTrailerQRCode) {
            if let trailerURL = trailerURL {
                TrailerQRSheetView(trailerURL: trailerURL)
            }
        }
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
    
    private func fetchVideos() async {
        do {
            let videos = try await APIService.shared.fetchVideos(for: media)
            self.trailerURL = videos.first?.youtubeURL
        } catch {
            
        }
    }
    
    private func fetchAndSetThemeColors() async {
        guard let posterPath = media.posterPath, let url = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)") else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            
            let primaryUIColors = ColorExtractor.extractPrimaryColors(from: image)
            let newColors = primaryUIColors.map { Color($0).darker(by: 0.6) }
            
            await MainActor.run {
                withAnimation {
                    self.themeColors = newColors
                }
            }
        } catch {
            
        }
    }
}

func generateQRCode(from string: String) -> UIImage? {
    let data = string.data(using: String.Encoding.ascii)

    if let filter = CIFilter(name: "CIQRCodeGenerator") {
        filter.setValue(data, forKey: "inputMessage")
        let transform = CGAffineTransform(scaleX: 10, y: 10)

        if let output = filter.outputImage?.transformed(by: transform) {
            let context = CIContext()
            if let cgImage = context.createCGImage(output, from: output.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
    }
    return nil
}

struct TrailerQRSheetView: View {
    let trailerURL: URL

    var body: some View {
        VStack(spacing: 40) {
            Text("Scan to Watch Trailer")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let qrCodeImage = generateQRCode(from: trailerURL.absoluteString) {
                Image(uiImage: qrCodeImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .background(Color.white)
                    .cornerRadius(20)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(30)

            } else {
                Text("Could not generate QR code.")
                    .font(.title2)
            }
            
            Text("Point your phone's camera at the QR code to open the trailer on your device.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .padding(60)
    }
}

struct DionysusTitleView: View {
    var body: some View {
        Text("Dionysus")
            .font(.system(size: 80, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
    }
}

struct MediaPosterView: View {
    let media: any Media

    var body: some View {
        CachedAsyncImage(url: media.posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }) { phase in
            switch phase {
            case .empty: ProgressView()
            case .success(let image): image.resizable()
            case .failure: Image(systemName: "film.slash").font(.largeTitle).foregroundColor(.secondary)
            @unknown default: EmptyView()
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .background(.gray.opacity(0.3))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

struct SearchResultRow: View {
    let media: any Media
    
    var body: some View {
        HStack(spacing: 30) {
            MediaPosterView(media: media).frame(width: 140, height: 210)
            VStack(alignment: .leading, spacing: 10) {
                Text(media.title).font(.headline)
                Text((media.releaseDate?.split(separator: "-").first).map(String.init) ?? "N/A")
                    .font(.subheadline).foregroundColor(.secondary)
                Text(media is Movie ? "Movie" : "TV Show").font(.caption).fontWeight(.bold)
                    .foregroundColor(media is Movie ? .cyan : .orange)
                Text(media.overview).font(.caption).foregroundColor(.gray).lineLimit(3)
            }
        }
        .padding(.vertical, 15)
    }
}

struct HeaderView: View {
    let media: any Media
    let releaseYear: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 40) {
            MediaPosterView(media: media)
                .frame(width: 300, height: 450)
            
            VStack(alignment: .leading, spacing: 15) {
                Text(media.title).font(.largeTitle).fontWeight(.bold)
                Text("\(releaseYear) • \(String(format: "%.1f", media.voteAverage)) ★")
                    .font(.title3).foregroundColor(.secondary)
            }
        }
    }
}

struct ActionButtonsView: View {
    let trailerURL: URL?
    let addToAction: () -> Void
    let playTrailerAction: () -> Void

    var body: some View {
        HStack(spacing: 30) {
            Button(action: addToAction) { Label("Add to Library", systemImage: "plus.circle.fill") }
            if trailerURL != nil {
                Button(action: playTrailerAction) { Label("Play Trailer", systemImage: "qrcode.viewfinder") }
            }
        }
        .font(.title3)
    }
}

struct OverviewView: View {
    let overview: String
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Overview").font(.title2).fontWeight(.bold)
            Text(overview).font(.body)
        }
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

struct LibraryActionSheetView: View {
    @StateObject private var viewModel = LibraryViewModel()
    let searchQuery: String
    @Environment(\.dismiss) private var dismiss
    
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
    
    private var filteredTorrents: [Torrent] {
        var torrents = viewModel.torrents
        if selectedQuality != "All" { torrents = torrents.filter { $0.quality == selectedQuality } }
        if !filterText.isEmpty { torrents = torrents.filter { $0.name.localizedCaseInsensitiveContains(filterText) } }
        return torrents
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                HStack {
                    Text("Sources for \(searchQuery)")
                        .font(.largeTitle)
                    Spacer()
                    Button {
                        Task {
                            await viewModel.fetchTorrents(for: finalSearchQuery, forceRefresh: true)
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.horizontal, 60)
                
                VStack(spacing: 30) {
                    Picker("Quality", selection: $selectedQuality) { ForEach(qualityOptions, id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    Picker("Audio/Video", selection: $selectedAVQuality) {
                        ForEach(AVQuality.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
                .padding(.horizontal, 60)
                
                if viewModel.isLoading { ProgressView() }
                else if let errorMessage = viewModel.errorMessage { ErrorView(message: errorMessage) { Task { await viewModel.fetchTorrents(for: finalSearchQuery) } } }
                else if filteredTorrents.isEmpty { Text("No Sources Found").font(.title2) }
                else {
                    List(filteredTorrents) { torrent in
                        let isAdded = torrent.infoHash.flatMap { viewModel.existingTorrentHashes.contains($0) } ?? false
                        TorrentRowView(torrent: torrent, isAlreadyAdded: isAdded) { magnet in Task { await viewModel.addTorrent(magnet: magnet) } }
                    }
                }
            }
            .padding(.top, 60)
            .task { await viewModel.fetchTorrents(for: finalSearchQuery, forceRefresh: false) }
            .onChange(of: selectedAVQuality) { Task { await viewModel.fetchTorrents(for: finalSearchQuery, forceRefresh: false) } }
            .onChange(of: viewModel.addState) { if viewModel.addState == .success { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() } } }
            
            if viewModel.addState != .idle {
                StatusOverlayView(addState: $viewModel.addState)
            }
        }
    }
}

struct TVShowDetailContentView: View {
    @StateObject private var viewModel = TVDetailViewModel()
    let show: TVShow
    let themeColor: Color?
    @State private var selectedSeason: Int = 1
    @State private var librarySearchQuery: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            if viewModel.isLoadingDetails { ProgressView() }
            else if let details = viewModel.showDetails {
                Text("Seasons").font(.title2).fontWeight(.bold)
                let seasons = details.seasons.filter { $0.seasonNumber > 0 }
                if !seasons.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(seasons) { season in
                                Button("Season \(season.seasonNumber)") {
                                    selectedSeason = season.seasonNumber
                                }
                                .buttonStyle(.bordered)
                                .background(selectedSeason == season.seasonNumber ? Color.blue.opacity(0.3) : Color.clear)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .onChange(of: selectedSeason) { Task { await viewModel.fetchSeason(tvShowId: show.id, seasonNumber: selectedSeason) } }
                }
                
                if viewModel.isLoadingSeason { ProgressView() }
                else if let seasonDetails = viewModel.selectedSeasonDetails {
                    VStack(alignment: .leading, spacing: 20) {
                        Button(action: {
                            let query = "\(show.title) S\(String(format: "%02d", selectedSeason))"
                            librarySearchQuery = query
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "sparkles").font(.title3).foregroundStyle(.yellow)
                                VStack(alignment: .leading) {
                                    Text("Season \(selectedSeason)").font(.caption).foregroundColor(.secondary)
                                    Text("Search for Full Season Pack").font(.headline).fontWeight(.bold)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill((themeColor ?? .blue).opacity(0.25))
                                .shadow(color: (themeColor ?? .blue).opacity(0.5), radius: 8, x: 0, y: 4)
                        )
                        
                        Divider()
                        
                        if seasonDetails.episodes.isEmpty {
                            Text("No episodes found for this season.").padding()
                        } else {
                            ForEach(seasonDetails.episodes) { episode in
                                EpisodeRowView(showTitle: show.title, episode: episode) { query in librarySearchQuery = query }
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.fetchDetails(for: show.id)
            if let firstSeason = viewModel.showDetails?.seasons.first(where: { $0.seasonNumber > 0 }) ?? viewModel.showDetails?.seasons.first { selectedSeason = firstSeason.seasonNumber }
        }
        .sheet(item: $librarySearchQuery) { query in LibraryActionSheetView(searchQuery: query) }
    }
}

struct EpisodeRowView: View {
    let showTitle: String
    let episode: Episode
    let addToAction: (String) -> Void
    
    var body: some View {
        Button(action: {
            let query = "\(showTitle) S\(String(format: "%02d", episode.seasonNumber))E\(String(format: "%02d", episode.episodeNumber))"
            addToAction(query)
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Episode \(episode.episodeNumber)").font(.caption).foregroundColor(.secondary)
                    Text(episode.name).font(.body)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
            }
        }
    }
}

struct GenreButtonView: View {
    let genre: Genre
    let gradient: [Color]

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: gradient), startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(genre.name).font(.title2).fontWeight(.bold).foregroundColor(.white).shadow(radius: 5)
        }
        .frame(height: 150)
        .cornerRadius(20)
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

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.red)
            Text(message).font(.headline).multilineTextAlignment(.center).padding()
            Button("Retry", action: retryAction)
        }
    }
}

struct GenreResultsView: View {
    @StateObject private var viewModel = GenreViewModel()
    let genre: Genre
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading { ProgressView() }
            else {
                LazyVGrid(columns: columns, spacing: 40) {
                    ForEach(viewModel.media) { item in
                        NavigationLink(value: item) {
                            MediaPosterView(media: item.underlyingMedia)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(60)
            }
        }
        .navigationTitle(genre.name)
        .task { await viewModel.loadMedia(for: genre.id) }
    }
}

struct TorrentRowView: View {
    let torrent: Torrent
    let isAlreadyAdded: Bool
    let addAction: (String) -> Void
    
    var body: some View {
        Button(action: { if let magnet = torrent.magnet { addAction(magnet) } }) {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text(torrent.name).font(.headline).lineLimit(2)
                    HStack {
                        Text(torrent.provider ?? "Unknown").font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.3)).cornerRadius(8)
                        if let quality = torrent.quality { Text(quality).font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(Color.purple.opacity(0.3)).cornerRadius(8) }
                    }
                    HStack(spacing: 20) {
                        Label(torrent.formattedSize, systemImage: "opticaldiscdrive")
                        Label(torrent.seeders ?? "0", systemImage: "arrow.up.circle.fill").foregroundColor(.green)
                        Label(torrent.leechers ?? "0", systemImage: "arrow.down.circle.fill").foregroundColor(.red)
                    }
                    .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if isAlreadyAdded {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
            }
        }
        .disabled(torrent.magnet == nil || isAlreadyAdded)
    }
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    
    var body: some View {
        if let url = url, let image = ImageCache.shared.get(forKey: url) {
            content(.success(Image(uiImage: image)))
        } else {
            AsyncImage(url: url) { phase in
                ZStack {
                    content(phase)
                    if case .success(let image) = phase, let url = url {
                        CacheActionView(url: url, image: image)
                    }
                }
            }
        }
    }
    
    private struct CacheActionView: View {
        let url: URL
        let image: Image
        
        var body: some View {
            Color.clear.frame(width: 0, height: 0).onAppear {
                #if os(iOS) || os(tvOS)
                let renderer = ImageRenderer(content: image)
                if let uiImage = renderer.uiImage { ImageCache.shared.set(forKey: url, image: uiImage) }
                #endif
            }
        }
    }
}

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private init() {}
    func get(forKey key: URL) -> UIImage? { cache.object(forKey: key as NSURL) }
    func set(forKey key: URL, image: UIImage) { cache.setObject(image, forKey: key as NSURL) }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct FocusChangeModifier: ViewModifier {
    let onFocusChange: (Bool) -> Void

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) {
                onFocusChange(isFocused)
            }
    }
}

extension View {
    func onFocusChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.modifier(FocusChangeModifier(onFocusChange: action))
    }
}
