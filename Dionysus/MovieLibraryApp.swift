import SwiftUI
import UIKit
import CoreHaptics
import PencilKit // Import PencilKit for Apple Pencil haptics support

@main
struct DionysusApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - ViewModels

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
            // Removed the artificial 1.5-second delay to improve startup time.
            async let trendingMoviesFetch = APIService.shared.fetchMovies(from: "/trending/movie/week")
            async let popularMoviesFetch = APIService.shared.fetchMovies(from: "/movie/popular")
            async let trendingShowsFetch = APIService.shared.fetchTVShows(from: "/trending/tv/week")
            async let popularShowsFetch = APIService.shared.fetchTVShows(from: "/tv/popular")

            let (trMovies, popMovies, trShows, popShows) = try await (trendingMoviesFetch, popularMoviesFetch, trendingShowsFetch, popularShowsFetch)
            self.trendingMovies = trMovies.map(MediaItem.movie)
            self.popularMovies = popMovies.map(MediaItem.movie)
            self.trendingShows = trShows.map(MediaItem.tvShow)
            self.popularShows = popShows.map(MediaItem.tvShow)
            HapticManager.shared.success()
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
            HapticManager.shared.success()
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

// MARK: - Main Content Views

struct ContentView: View {
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some View {
        TabView {
            HomeView(viewModel: homeViewModel)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .preferredColorScheme(.dark)
    }
}

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    
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
                    .sensoryFeedback(.increase, trigger: viewModel.trendingMovies.first?.id)
                    .refreshable { await viewModel.loadAllContent() }
                    .toolbar { ToolbarItem(placement: .principal) { DionysusTitleView() } }
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                            let screenCenter = UIScreen.main.bounds.width / 2
                            let isCentered = abs(itemFrame.midX - screenCenter) < 75

                            NavigationLink(value: item) {
                                MediaPosterView(media: item.underlyingMedia)
                                    .scaleEffect(pressedItemId == item.id ? 0.95 : 1.0)
                            }
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

// MARK: - iPad Optimized Search View

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedMediaItem: MediaItem?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isSplitView: Bool {
        horizontalSizeClass == .regular
    }

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
        if isSplitView {
            NavigationSplitView {
                // By wrapping the sidebar in its own NavigationStack, we create an unambiguous
                // context for push navigation that is separate from the split view's master-detail behavior.
                NavigationStack {
                    sidebarView
                        .navigationDestination(for: Genre.self) { genre in
                            GenreResultsView(genre: genre)
                        }
                        // This destination now correctly handles pushes from within the sidebar's stack,
                        // such as navigating from GenreResultsView to MediaDetailView.
                        .navigationDestination(for: MediaItem.self) { item in
                            MediaDetailView(media: item.underlyingMedia, showCustomDismissButton: true)
                        }
                }
            } detail: {
                detailView
            }
            .navigationSplitViewStyle(.automatic)
        } else {
            NavigationStack {
                sidebarView
                    .navigationDestination(for: Genre.self) { genre in GenreResultsView(genre: genre) }
                    .navigationDestination(for: MediaItem.self) { item in
                        MediaDetailView(media: item.underlyingMedia, showCustomDismissButton: false)
                    }
            }
        }
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
                else if viewModel.searchResults.isEmpty { ContentUnavailableView.search(text: viewModel.query) }
                else {
                    // The NavigationLink here correctly updates the `selectedMediaItem` to drive the detail view,
                    // as it's not ambiguous anymore thanks to the explicit NavigationStack.
                    List(viewModel.searchResults, selection: $selectedMediaItem) { item in
                        NavigationLink(value: item) {
                            SearchResultRow(media: item.underlyingMedia)
                                .onDrag {
                                    HapticManager.shared.playDragStart()
                                    let media = item.underlyingMedia
                                    let path = media is Movie ? "movie" : "tv"
                                    if let url = URL(string: "https://www.themoviedb.org/\(path)/\(media.id)") {
                                        return NSItemProvider(object: url as NSURL)
                                    }
                                    return NSItemProvider()
                                } preview: {
                                    MediaPosterView(media: item.underlyingMedia)
                                        .frame(width: 150, height: 225)
                                }
                                .sensoryFeedback(.impact(weight: .light), trigger: selectedMediaItem)
                        }
                    }
                    .listStyle(.plain).padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search movies & TV shows...")
        .onChange(of: viewModel.query) { Task { await viewModel.performSearch() } }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    @ViewBuilder
    private var detailView: some View {
        if let selectedMediaItem {
            MediaDetailView(media: selectedMediaItem.underlyingMedia, showCustomDismissButton: false)
        } else {
            ContentUnavailableView("Select an item to view details", systemImage: "film")
        }
    }
}


// MARK: - iPad Optimized Detail View

struct MediaDetailView: View {
    let media: any Media
    let showCustomDismissButton: Bool
    
    @State private var trailerURL: URL?
    @State private var showContent = false
    @State private var librarySearchQuery: String?
    @State private var themeColors: [Color] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var releaseYear: String {
        (media.releaseDate?.split(separator: "-").first).map(String.init) ?? "N/A"
    }
    
    private var searchQuery: String {
        (media is TVShow) ? "\(media.title) complete" : "\(media.title) \(releaseYear)"
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadDetailLayout
            } else {
                iPhoneDetailLayout
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
    
    private var iPadDetailLayout: some View {
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
    }

    private var iPhoneDetailLayout: some View {
        ZStack {
            if themeColors.isEmpty { Color.black.ignoresSafeArea() }
            else {
                BlobBackgroundView(colors: themeColors, isAnimating: true)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut))
            }
            mainDetailContent
        }
        .overlay(alignment: .topLeading) {
            if showCustomDismissButton {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .padding().safeAreaPadding(.top).opacity(showContent ? 1 : 0)
            }
        }
        .sheet(item: $librarySearchQuery) { query in
            SourcesView(searchQuery: query).presentationDetents([.medium, .large])
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBar(hidden: true)
    }

    private var mainDetailContent: some View {
        ScrollView {
            GeometryReader { geo in
                let scrollY = geo.frame(in: .named("detailScroll")).minY
                CachedAsyncImage(url: media.backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }) { phase in
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
                
                if horizontalSizeClass != .regular {
                    ActionButtonsView(trailerURL: trailerURL) {
                        librarySearchQuery = searchQuery
                    }
                } else if let trailerURL {
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
        .ignoresSafeArea(edges: horizontalSizeClass == .regular ? [] : .all)
    }
    
    private func fetchVideos() async {
        do {
            let videos = try await APIService.shared.fetchVideos(for: media)
            self.trailerURL = videos.first?.youtubeURL
        } catch { }
    }
    
    private func fetchAndSetThemeColors() async {
        guard let posterPath = media.posterPath, let url = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            let primaryUIColors = ColorExtractor.extractPrimaryColors(from: image)
            let newColors = primaryUIColors.map { Color($0).darker(by: 0.6) }
            await MainActor.run { withAnimation { self.themeColors = newColors } }
        } catch { }
    }
}

// MARK: - Renamed SourcesView (was LibraryActionSheetView)

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
            // Removed the nested NavigationStack to prevent conflicts with NavigationSplitView.
            VStack {
                VStack {
                    Picker("Quality", selection: $selectedQuality) { ForEach(qualityOptions, id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    Picker("Audio/Video", selection: $selectedAVQuality) {
                        ForEach(AVQuality.allCases) { quality in Text(quality.rawValue).tag(quality) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Filter by name...", text: $filterText)
                        .font(.custom("Eurostile-Regular", size: 16))
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Group {
                    if viewModel.isLoading { ProgressView() }
                    else if let errorMessage = viewModel.errorMessage { ErrorView(message: errorMessage) { Task { await viewModel.fetchTorrents(for: finalSearchQuery) } } }
                    else if filteredTorrents.isEmpty { ContentUnavailableView("No Sources Found", systemImage: "magnifyingglass") }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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

// MARK: - Reusable UI Components

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
        let poster = CachedAsyncImage(url: media.posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }) { phase in
            switch phase {
            case .empty: ProgressView()
            case .success(let image): image.resizable()
            case .failure: Image(systemName: "film.slash").font(.largeTitle).foregroundColor(.secondary)
            @unknown default: EmptyView()
            }
        }
        .aspectRatio(2/3, contentMode: .fit).background(.gray.opacity(0.3))
        .cornerRadius(12).shadow(radius: 5)

        let path = media is Movie ? "movie" : "tv"
        if let url = URL(string: "https://www.themoviedb.org/\(path)/\(media.id)") {
            poster
                .onDrag {
                    HapticManager.shared.playDragStart()
                    return NSItemProvider(object: url as NSURL)
                }
        } else {
            poster
        }
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
            if let trailerURL, UIApplication.shared.canOpenURL(trailerURL) {
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
        .sheet(item: $librarySearchQuery) { query in SourcesView(searchQuery: query).presentationDetents([.medium, .large]) }
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
    
    #if os(iOS)
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
    
    func start() {}
    func stop() {}

    func impact() {
        #if os(iOS)
        impactGenerator.impactOccurred()
        #endif
    }
    
    func success() {
        #if os(iOS)
        notificationGenerator.notificationOccurred(.success)
        #endif
    }

    func playScrollTick() {
        #if os(iOS)
        lightImpactGenerator.impactOccurred()
        #endif
    }

    func playDragStart() {
        #if os(iOS)
        rigidImpactGenerator.impactOccurred()
        #endif
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
                #if os(iOS)
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

