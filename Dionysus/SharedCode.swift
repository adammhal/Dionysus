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

// In SharedCode.swift

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

    // Manually define the keys to match your JSON
    enum CodingKeys: String, CodingKey {
        case name, size, seeders, leechers, magnet, quality, provider
    }

    // Custom initializer to handle flexible data types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode standard properties normally
        name = try container.decode(String.self, forKey: .name)
        size = try container.decodeIfPresent(String.self, forKey: .size)
        magnet = try container.decodeIfPresent(String.self, forKey: .magnet)
        quality = try container.decodeIfPresent(String.self, forKey: .quality)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)

        do {
            // First, try to decode it as a String
            seeders = try container.decodeIfPresent(String.self, forKey: .seeders)
        } catch {
            // If that fails, try to decode it as an Int and convert it to a String
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: .seeders) {
                seeders = String(intValue)
            } else {
                seeders = nil
            }
        }

        // Special handling for 'leechers'
        do {
            // First, try to decode it as a String
            leechers = try container.decodeIfPresent(String.self, forKey: .leechers)
        } catch {
            // If that fails, try to decode it as an Int and convert it to a String
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: .leechers) {
                leechers = String(intValue)
            } else {
                leechers = nil
            }
        }
    }
    
    // Your existing computed properties remain unchanged
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
        
        async let movies: MovieResponse = fetch(from: movieUrl)
        async let tvShows: TVShowResponse = fetch(from: tvShowUrl)
        
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
        
        let (data, response) = try await URLSession.shared.data(from: url)

        if let jsonString = String(data: data, encoding: .utf8) {
            print("--- RAW TORRENT API RESPONSE ---")
            print(jsonString)
            print("------------------------------")
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
        
        async let movies: MovieResponse = fetch(from: movieUrl)
        async let tvShows: TVShowResponse = fetch(from: tvUrl)
        
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
    
    func fetchMovie(id: Int) async throws -> Movie {
        let url = URL(string: "\(baseUrl)/movie/\(id)?api_key=\(Secrets.tmdbApiKey)")!
        return try await fetch(from: url)
    }

    func fetchTVShow(id: Int) async throws -> TVShow {
        let url = URL(string: "\(baseUrl)/tv/\(id)?api_key=\(Secrets.tmdbApiKey)")!
        return try await fetch(from: url)
    }
    
    func fetchImages(for media: any Media) async throws -> ImagesResponse {
        let endpoint = media is Movie ? "/movie/\(media.id)/images" : "/tv/\(media.id)/images"
        let url = URL(string: "\(baseUrl)\(endpoint)?api_key=\(Secrets.tmdbApiKey)")!
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
            print("!!! FETCH INFO FAILED: Response was not HTTP")
            throw URLError(.cannotParseResponse)
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(RealDebridTorrentInfo.self, from: data)
        }

        print("!!! FETCH INFO FAILED: HTTP Status Code: \(httpResponse.statusCode)")
        if let errorBody = String(data: data, encoding: .utf8) {
            print("!!! ERROR BODY: \(errorBody)")
        }
        throw URLError(.badServerResponse)
    }

    func fetchTorrents(page: Int) async throws -> [RealDebridTorrent] {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents?page=\(page)&limit=50")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Secrets.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("!!! FETCH FAILED: Response was not HTTP")
            throw URLError(.cannotParseResponse)
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([RealDebridTorrent].self, from: data)
        }
        
        if httpResponse.statusCode == 204 {
            print("--- DEBUG: Received 204 No Content, treating as empty page.")
            return []
        }

        print("!!! FETCH FAILED: HTTP Status Code: \(httpResponse.statusCode)")
        if let errorBody = String(data: data, encoding: .utf8) {
            print("!!! ERROR BODY: \(errorBody)")
        }
        throw URLError(.badServerResponse)
    }

    func deleteTorrent(id: String) async throws {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/delete/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(Secrets.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("!!! DELETE FAILED: Response was not HTTP")
            throw URLError(.cannotParseResponse)
        }
        
        if httpResponse.statusCode != 204 {
            print("!!! DELETE FAILED: HTTP Status Code: \(httpResponse.statusCode)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("!!! ERROR BODY: \(errorBody)")
            }
            throw URLError(.badServerResponse)
        }
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
