import Foundation
import SwiftUI
import ColorThiefSwift
import UIKit

struct MovieResponse: Codable {
    let results: [Movie]
}

struct TVShowResponse: Codable {
    let results: [TVShow]
}

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

    // Explicit CodingKeys to ensure correct mapping
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average" // Map snake_case
        case releaseDate = "release_date"
    }
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

    // Explicit CodingKeys to ensure correct mapping
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average" // Map snake_case
        case firstAirDate = "first_air_date"
    }
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

    init(name: String, size: String?, seeders: String?, leechers: String?, magnet: String?, quality: String?, provider: String?) {
            self.name = name
            self.size = size
            self.seeders = seeders
            self.leechers = leechers
            self.magnet = magnet
            self.quality = quality
            self.provider = provider
        }

    enum CodingKeys: String, CodingKey {
        case name, size, seeders, leechers, magnet, quality, provider
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        size = try container.decodeIfPresent(String.self, forKey: .size)
        magnet = try container.decodeIfPresent(String.self, forKey: .magnet)
        quality = try container.decodeIfPresent(String.self, forKey: .quality)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)

        do {
            seeders = try container.decodeIfPresent(String.self, forKey: .seeders)
        } catch {
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: .seeders) {
                seeders = String(intValue)
            } else {
                seeders = nil
            }
        }

        do {
            leechers = try container.decodeIfPresent(String.self, forKey: .leechers)
        } catch {
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: .leechers) {
                leechers = String(intValue)
            } else {
                leechers = nil
            }
        }
    }

    
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
    let numberOfEpisodes: Int?
    let seasons: [SeasonSummary]

     enum CodingKeys: String, CodingKey {
         case id, name, seasons
         case numberOfSeasons = "number_of_seasons"
         case numberOfEpisodes = "number_of_episodes"
     }
}

struct SeasonSummary: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let episodeCount: Int?

     enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
    }
}

struct SeasonDetails: Codable {
    let id: String // Keep if API returns "_id" as string
    let episodes: [Episode]
    let seasonNumber: Int? // Add if needed

    enum CodingKeys: String, CodingKey {
        case id = "_id" // Maps the JSON key "_id" to Swift property "id"
        case episodes
        case seasonNumber = "season_number" // Map if needed
    }
}


struct Episode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let episodeNumber: Int
    let seasonNumber: Int

     enum CodingKeys: String, CodingKey {
        case id, name
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
    }
}

struct Genre: Identifiable, Hashable {
    let id: Int
    let name: String
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

struct RealDebridFile: Codable, Identifiable, Hashable {
    let id: Int
    let path: String
    let bytes: Int
    let selected: Int
}

struct RealDebridTorrentInfo: Codable {
    let id: String
    let filename: String
    let bytes: Int
    let files: [RealDebridFile]
}

class APIService {
    static let shared = APIService()
    private init() {}

    private let baseUrl = "https://api.themoviedb.org/3"
    private let dionysusServerBaseURL = "https://dionysus-server-py-production.up.railway.app"

    private func fetch<T: Codable>(from url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                 print("API Error: Received status code \(httpResponse.statusCode) from \(url)")
                 if let responseBody = String(data: data, encoding: .utf8) {
                     print("API Error Body: \(responseBody)")
                 }
             } else {
                 print("API Error: Invalid response from \(url)")
             }
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        // Explicit CodingKeys handle mapping, strategy no longer needed here.
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
             print("Decoding Error: Failed to decode \(T.self) from \(url). Error: \(error)")
             if let jsonString = String(data: data, encoding: .utf8) {
                 print("Raw JSON Response: \(jsonString)")
             }
             throw error
        }
    }


    func fetchMovies(from endpoint: String) async throws -> [Movie] {
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
        let response: MovieResponse = try await fetch(from: url)
        return response.results
    }

    func fetchTVShows(from endpoint: String) async throws -> [TVShow] {
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
        let response: TVShowResponse = try await fetch(from: url)
        return response.results
    }

    func searchAll(query: String) async throws -> [MediaItem] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let movieUrl = URL(string: "\(baseUrl)/search/movie?api_key=\(SettingsManager.shared.tmdbApiKey)&query=\(encodedQuery)")!
        let tvShowUrl = URL(string: "\(baseUrl)/search/tv?api_key=\(SettingsManager.shared.tmdbApiKey)&query=\(encodedQuery)")!

        async let movies: MovieResponse = fetch(from: movieUrl)
        async let tvShows: TVShowResponse = fetch(from: tvShowUrl)

        let fetchedMovies = (try? await movies)?.results ?? []
        let fetchedTVShows = (try? await tvShows)?.results ?? []

        return (fetchedMovies.map(MediaItem.movie) + fetchedTVShows.map(MediaItem.tvShow))
            .sorted { $0.underlyingMedia.voteAverage > $1.underlyingMedia.voteAverage }
    }

    func fetchVideos(for media: any Media) async throws -> [Video] {
        let endpoint = media is Movie ? "/movie/\(media.id)/videos" : "/tv/\(media.id)/videos"
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
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

        print("🔍 [API] Searching torrents: \(urlString)")
        let url = URL(string: urlString)!

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ [API] Torrent search failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let torrentResponse = try decoder.decode(TorrentResponse.self, from: data)
        return torrentResponse.data
    }

    func fetchUserTorrentHashes() async throws -> Set<String> {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        
        print("🔍 [API] Fetching user torrents from: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ [API] Fetch user torrents failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            if let body = String(data: data, encoding: .utf8) {
                 print("❌ [API] Response Body: \(body)")
            }
            throw URLError(.badServerResponse)
        }
        let userTorrents = try JSONDecoder().decode([RealDebridTorrent].self, from: data)
        return Set(userTorrents.map { $0.hash.lowercased() })
    }

    func fetchTVShowDetails(id: Int) async throws -> TVShowDetails {
        let url = URL(string: "\(baseUrl)/tv/\(id)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
        return try await fetch(from: url)
    }

    func fetchSeasonDetails(tvShowId: Int, seasonNumber: Int) async throws -> SeasonDetails {
        let url = URL(string: "\(baseUrl)/tv/\(tvShowId)/season/\(seasonNumber)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
        return try await fetch(from: url)
    }

    func fetchDiscoverMedia(genreId: Int) async throws -> [MediaItem] {
        let movieUrl = URL(string: "\(baseUrl)/discover/movie?api_key=\(SettingsManager.shared.tmdbApiKey)&with_genres=\(genreId)")!
        let tvUrl = URL(string: "\(baseUrl)/discover/tv?api_key=\(SettingsManager.shared.tmdbApiKey)&with_genres=\(genreId)")!

        async let movies: MovieResponse = fetch(from: movieUrl)
        async let tvShows: TVShowResponse = fetch(from: tvUrl)

        let fetchedMovies = (try? await movies)?.results ?? []
        let fetchedTVShows = (try? await tvShows)?.results ?? []

        return (fetchedMovies.map(MediaItem.movie) + fetchedTVShows.map(MediaItem.tvShow))
            .sorted { $0.underlyingMedia.voteAverage > $1.underlyingMedia.voteAverage }
    }

    func addAndSelectTorrent(magnet: String) async throws {
        print("🔄 [API] Starting Add & Select Torrent flow...")
        let addedTorrent = try await addMagnetToRealDebrid(magnet: magnet)
        print("✅ [API] Magnet added successfully. Torrent ID: \(addedTorrent.id). Now selecting files...")
        try await selectTorrentFiles(torrentId: addedTorrent.id)
        print("✅ [API] Files selected successfully.")
    }

    private func addMagnetToRealDebrid(magnet: String) async throws -> RealDebridAddTorrentResponse {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/addMagnet")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // FIX: Use custom .urlQueryValueAllowed to ensure '&' and '=' inside the magnet are encoded.
        // Otherwise, the server sees the magnet link cut off at the first '&'.
        let safeMagnet = magnet.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
        request.httpBody = "magnet=\(safeMagnet)".data(using: .utf8)

        print("📡 [RD-API] Adding Magnet...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 [RD-API] Add Magnet Response Code: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                 if let body = String(data: data, encoding: .utf8) {
                     print("❌ [RD-API] Error Body: \(body)")
                 }
                throw URLError(.badServerResponse)
            }
        }
        
        return try JSONDecoder().decode(RealDebridAddTorrentResponse.self, from: data)
    }

    private func selectTorrentFiles(torrentId: String) async throws {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/\(torrentId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "files=all".data(using: .utf8)

        print("📡 [RD-API] Selecting all files for torrent: \(torrentId)")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 [RD-API] Select Files Response Code: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 204 {
                if let body = String(data: data, encoding: .utf8) {
                     print("❌ [RD-API] Select Files Error: \(body)")
                 }
                throw URLError(.badServerResponse)
            }
        }
    }

    func fetchMovie(id: Int) async throws -> Movie {
        let url = URL(string: "\(baseUrl)/movie/\(id)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
        return try await fetch(from: url)
    }

    func fetchTVShow(id: Int) async throws -> TVShow {
        let url = URL(string: "\(baseUrl)/tv/\(id)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
        return try await fetch(from: url)
    }

    func fetchImages(for media: any Media) async throws -> ImagesResponse {
        let endpoint = media is Movie ? "/movie/\(media.id)/images" : "/tv/\(media.id)/images"
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(SettingsManager.shared.tmdbApiKey)")!
        return try await fetch(from: url)
    }

    func getBrandedImageURL(for media: any Media) -> URL? {
        guard let backdropPath = media.backdropPath else { return nil }

        let mediaType = media is Movie ? "movie" : "tv"
        let urlString = "\(dionysusServerBaseURL)/api/v1/image/branded?backdrop_path=\(backdropPath)&media_type=\(mediaType)&media_id=\(media.id)"

        return URL(string: urlString)
    }

    func resolveYoutubeURL(for videoKey: String) async throws -> URL? {
        let urlString = "\(dionysusServerBaseURL)/api/v1/resolve_video?video_key=\(videoKey)"
        guard let url = URL(string: urlString) else { return nil }

        let response: VideoResolveResponse = try await fetch(from: url)
        return response.directURL
    }

    func fetchTorrentInfo(id: String) async throws -> RealDebridTorrentInfo {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/info/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Secrets.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(RealDebridTorrentInfo.self, from: data)
        }

        throw URLError(.badServerResponse)
    }

    func fetchTorrents(page: Int) async throws -> [RealDebridTorrent] {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents?page=\(page)&limit=50")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([RealDebridTorrent].self, from: data)
        }

        if httpResponse.statusCode == 204 {
            return []
        }

        throw URLError(.badServerResponse)
    }

    func deleteTorrent(id: String) async throws {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/delete/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }

        if httpResponse.statusCode != 204 {
            throw URLError(.badServerResponse)
        }
    }

    func fetchWatchProviders(for media: any Media) async throws -> WatchProviderCountryResult? {
        let mediaType = media is Movie ? "movie" : "tv"
        let url = URL(string: "\(baseUrl)/\(mediaType)/\(media.id)/watch/providers?api_key=\(SettingsManager.shared.tmdbApiKey)")!

        let response: WatchProviderResponse = try await fetch(from: url)

        let currentRegion = Locale.current.region?.identifier ?? "US"

        return response.results[currentRegion]
    }
}

extension UIColor {
    var hsbComponents: (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }
}

class ColorExtractor {
    static func extractPrimaryColors(from image: UIImage, count: Int = 5) -> [UIColor] {
        guard let palette = ColorThief.getPalette(from: image, colorCount: count) else {
            return []
        }

        let filteredColors = palette.filter { color -> Bool in
            let uiColor = color.makeUIColor()
            let hsb = uiColor.hsbComponents
            return hsb.s > 0.2 && hsb.b > 0.2 && hsb.b < 0.95
        }

        let primaryColors = Array(filteredColors.prefix(2)).map { $0.makeUIColor() }
        return primaryColors
    }
}

extension Color {
    func darker(by percentage: Double) -> Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return Color(UIColor(
                red: max(0, red - percentage),
                green: max(0, green - percentage),
                blue: max(0, blue - percentage),
                alpha: alpha
            ))
        }
        return self
    }
}

// Add this extension to define the stricter character set
extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

struct ImagesResponse: Codable {
    let logos: [Logo]
}

struct Logo: Codable {
    let aspectRatio: Double
    let filePath: String
    let language: String?

    enum CodingKeys: String, CodingKey {
        case aspectRatio = "aspect_ratio"
        case filePath = "file_path"
        case language = "iso_639_1"
    }
}

struct VideoResolveResponse: Codable {
    let directURL: URL
}

struct WatchProviderResponse: Codable {
    let id: Int
    let results: [String: WatchProviderCountryResult]
}

struct WatchProviderCountryResult: Codable {
    let link: String?
    let flatrate: [WatchProviderDetail]?
    let rent: [WatchProviderDetail]?
    let buy: [WatchProviderDetail]?
}

struct WatchProviderDetail: Codable, Identifiable, Hashable {
    let logoPath: String?
    let providerId: Int
    let providerName: String
    let displayPriority: Int?

    var id: Int { providerId }

    enum CodingKeys: String, CodingKey {
        case logoPath = "logo_path"
        case providerId = "provider_id" // Explicitly map provider_id
        case providerName = "provider_name"
        case displayPriority = "display_priority"
    }
}
