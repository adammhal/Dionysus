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

extension RealDebridFile {
    private static let subtitleExtensions: Set<String> = [
        ".srt", ".vtt", ".ass", ".ssa", ".sub", ".idx", ".smi", ".ttml", ".sup"
    ]

    var isSubtitle: Bool {
        let lower = path.lowercased()
        return RealDebridFile.subtitleExtensions.contains { lower.hasSuffix($0) }
    }

    var isRarRelated: Bool {
        let lower = path.lowercased()
        // Only flag actual archive files — .nfo/.sfv appear in non-RAR scene releases too
        if lower.hasSuffix(".rar") { return true }
        // Match .r00–.r99 multi-part RAR extensions
        let ext = (lower as NSString).pathExtension
        if ext.count == 3, ext.hasPrefix("r"), ext.dropFirst().allSatisfy(\.isNumber) { return true }
        return false
    }

    var subtitleLanguage: String? {
        guard isSubtitle else { return nil }
        let base = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent.lowercased()
        let parts = base.components(separatedBy: CharacterSet(charactersIn: "._- "))
        let map: [String: String] = [
            "english": "English", "eng": "English", "en": "English",
            "french": "French", "fre": "French", "fra": "French", "fr": "French",
            "spanish": "Spanish", "spa": "Spanish", "es": "Spanish",
            "german": "German", "ger": "German", "deu": "German", "de": "German",
            "portuguese": "Portuguese", "por": "Portuguese", "pt": "Portuguese",
            "italian": "Italian", "ita": "Italian", "it": "Italian",
            "dutch": "Dutch", "nld": "Dutch", "nl": "Dutch",
            "japanese": "Japanese", "jpn": "Japanese", "ja": "Japanese",
            "korean": "Korean", "kor": "Korean", "ko": "Korean",
            "chinese": "Chinese", "chi": "Chinese", "zho": "Chinese", "zh": "Chinese",
            "arabic": "Arabic", "ara": "Arabic", "ar": "Arabic",
            "russian": "Russian", "rus": "Russian", "ru": "Russian",
        ]
        return parts.compactMap { map[$0] }.first
    }
}

struct RealDebridTorrentInfo: Codable, Identifiable {
    let id: String
    let filename: String
    let hash: String
    let bytes: Int
    let status: String
    let links: [String]
    let files: [RealDebridFile]
}

struct RealDebridUnrestrictResponse: Codable {
    let id: String
    let filename: String
    let mimeType: String
    let download: String
    let streamable: Int

    var isPlayable: Bool { mimeType.hasPrefix("video/") }
}

struct RealDebridSubtitleTrack: Codable {
    let lang: String?
    let lang_iso: String?
}

struct RealDebridMediaDetails: Codable {
    let subtitles: [String: RealDebridSubtitleTrack]?
}

struct RealDebridMediaInfosResponse: Codable {
    let details: RealDebridMediaDetails
    let modelUrl: String?

    var subtitleLanguages: [String] {
        guard let subs = details.subtitles else { return [] }
        let langs = subs.values
            .compactMap { $0.lang }
            .filter { !$0.isEmpty && $0 != "Unknown" }
        return Array(Set(langs)).sorted()
    }

    // subtitle track keys from the response (e.g. "eng1", "fre1") sorted by key
    var subtitleTrackKeys: [String] {
        details.subtitles?.keys.sorted() ?? []
    }
}

struct RealDebridTranscodeResponse: Codable {
    struct AppleStreams: Codable {
        let full: String
    }
    let apple: AppleStreams
}

enum APIError: LocalizedError {
    case unauthorized(service: String)
    case forbidden(service: String)
    case notFound(endpoint: String)
    case serverError(service: String, statusCode: Int)
    case networkUnavailable
    case decodingFailed(type: String)
    case invalidResponse(service: String)
    case rateLimited(service: String)
    case unknown(statusCode: Int, body: String?)
    case torrentFailed(status: String)
    case infringingFile

    var errorDescription: String? {
        switch self {
        case .unauthorized(let service):
            return "\(service) API key is invalid or expired. Update it in Settings."
        case .forbidden(let service):
            return "Access denied by \(service). Check your account or API key."
        case .notFound(let endpoint):
            return "The requested resource was not found: \(endpoint)"
        case .serverError(let service, let statusCode):
            return "\(service) server error (HTTP \(statusCode)). Try again later."
        case .networkUnavailable:
            return "Network connection unavailable. Check your internet connection."
        case .decodingFailed(let type):
            return "Failed to parse \(type) response from server."
        case .invalidResponse(let service):
            return "Received an invalid response from \(service)."
        case .rateLimited(let service):
            return "Too many requests to \(service). Wait a moment and try again."
        case .unknown(let statusCode, let body):
            var message = "Request failed with HTTP \(statusCode)."
            if let body = body, !body.isEmpty {
                message += " Response: \(body)"
            }
            return message
        case .torrentFailed(let status):
            let reason: String
            switch status {
            case "error": reason = "encountered an error"
            case "dead": reason = "is no longer available"
            case "virus": reason = "was flagged as malware"
            case "magnet_error": reason = "has an invalid magnet link"
            default: reason = "failed (status: \(status))"
            }
            return "Torrent \(reason) on Real-Debrid."
        case .infringingFile:
            return "Real-Debrid has blocked this torrent due to a copyright claim. Try a different source."
        }
    }

    static func from(httpResponse: HTTPURLResponse, data: Data, service: String) -> APIError {
        let body = String(data: data, encoding: .utf8)
        switch httpResponse.statusCode {
        case 401:
            return .unauthorized(service: service)
        case 403:
            return .forbidden(service: service)
        case 404:
            return .notFound(endpoint: httpResponse.url?.path ?? "unknown")
        case 429:
            return .rateLimited(service: service)
        case 451:
            return .infringingFile
        case 500...599:
            return .serverError(service: service, statusCode: httpResponse.statusCode)
        default:
            return .unknown(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

class APIService {
    static let shared = APIService()
    private init() {}

    private let baseUrl = "https://api.themoviedb.org/3"
    private let dionysusServerBaseURL = "https://dionysus-server-py-production.up.railway.app"

    private func fetch<T: Codable>(from url: URL, service: String = "TMDB") async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw APIError.networkUnavailable
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(service: service)
        }
        guard httpResponse.statusCode == 200 else {
            let error = APIError.from(httpResponse: httpResponse, data: data, service: service)
            print("[API] \(service) request failed: \(error.localizedDescription)")
            throw error
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[API] Decoding error for \(T.self) from \(url): \(error)")
            throw APIError.decodingFailed(type: String(describing: T.self))
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

        print("[API] Searching torrents: \(urlString)")
        let url = URL(string: urlString)!

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw APIError.networkUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                let error = APIError.from(httpResponse: httpResponse, data: data, service: "Dionysus Search")
                print("[API] Torrent search failed: \(error.localizedDescription)")
                throw error
            }
            throw APIError.invalidResponse(service: "Dionysus Search")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let torrentResponse = try decoder.decode(TorrentResponse.self, from: data)
            return torrentResponse.data
        } catch {
            print("[API] Decoding error for torrent search: \(error)")
            throw APIError.decodingFailed(type: "TorrentResponse")
        }
    }

    func fetchUserTorrentHashes() async throws -> Set<String> {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        
        print("[API] Fetching user torrents from: \(url)")
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw APIError.networkUnavailable
        }
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                let error = APIError.from(httpResponse: httpResponse, data: data, service: "Real-Debrid")
                print("[API] Fetch user torrents failed: \(error.localizedDescription)")
                throw error
            }
            throw APIError.invalidResponse(service: "Real-Debrid")
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
        print("[API] Starting Add & Select Torrent flow...")
        let addedTorrent = try await addMagnetToRealDebrid(magnet: magnet)
        print("[API] Magnet added successfully. Torrent ID: \(addedTorrent.id). Now selecting files...")
        try await selectTorrentFiles(torrentId: addedTorrent.id)
        print("[API] Files selected successfully.")
    }

    func addMagnetForInspection(magnet: String) async throws -> (torrentId: String, info: RealDebridTorrentInfo) {
        let added = try await addMagnetToRealDebrid(magnet: magnet)
        let info = try await waitForFileSelection(id: added.id)
        return (added.id, info)
    }

    func confirmTorrentSelection(id: String) async throws {
        try await selectTorrentFiles(torrentId: id)
    }

    private func addMagnetToRealDebrid(magnet: String) async throws -> RealDebridAddTorrentResponse {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/addMagnet")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Use custom .urlQueryValueAllowed to ensure '&' and '=' inside the magnet are encoded.
        let safeMagnet = magnet.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
        request.httpBody = "magnet=\(safeMagnet)".data(using: .utf8)

        print("[RD-API] Adding Magnet...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }
        print("[RD-API] Add Magnet Response Code: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 201 {
            let error = APIError.from(httpResponse: httpResponse, data: data, service: "Real-Debrid")
            print("[RD-API] Add Magnet error: \(error.localizedDescription)")
            throw error
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

        print("[RD-API] Selecting all files for torrent: \(torrentId)")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }
        print("[RD-API] Select Files Response Code: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 204 {
            let error = APIError.from(httpResponse: httpResponse, data: data, service: "Real-Debrid")
            print("[RD-API] Select Files error: \(error.localizedDescription)")
            throw error
        }
    }

    private func waitForFileSelection(id: String) async throws -> RealDebridTorrentInfo {
        for _ in 0..<15 {
            let info = try await fetchTorrentInfo(id: id)
            if info.status != "magnet_conversion" {
                return info
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        throw APIError.serverError(service: "Real-Debrid", statusCode: 408)
    }

    func pollUntilDownloaded(id: String) async throws -> RealDebridTorrentInfo {
        let terminalErrors: Set<String> = ["error", "dead", "virus", "magnet_error"]
        for _ in 0..<30 {
            let info = try await fetchTorrentInfo(id: id)
            if info.status == "downloaded" { return info }
            if terminalErrors.contains(info.status) {
                throw APIError.torrentFailed(status: info.status)
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw APIError.serverError(service: "Real-Debrid", statusCode: 408)
    }

    func unrestrict(link: String) async throws -> RealDebridUnrestrictResponse {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/unrestrict/link")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let safeLink = link.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
        request.httpBody = "link=\(safeLink)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }
        if httpResponse.statusCode != 200 {
            throw APIError.from(httpResponse: httpResponse, data: data, service: "Real-Debrid")
        }
        print("[Unrestrict] Raw JSON: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        return try JSONDecoder().decode(RealDebridUnrestrictResponse.self, from: data)
    }

    func fetchStreamURL(id: String) async throws -> URL {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/streaming/transcode/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[Transcode] Status: \(statusCode), body: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        guard statusCode == 200 else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }
        let result = try JSONDecoder().decode(RealDebridTranscodeResponse.self, from: data)
        guard let streamURL = URL(string: result.apple.full) else {
            throw APIError.decodingFailed(type: "RealDebridTranscodeResponse")
        }
        return streamURL
    }

    func fetchMediaInfos(id: String) async throws -> RealDebridMediaInfosResponse {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/streaming/mediaInfos/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[MediaInfos] Status: \(statusCode), body: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        guard statusCode == 200 else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }
        return try JSONDecoder().decode(RealDebridMediaInfosResponse.self, from: data)
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
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(RealDebridTorrentInfo.self, from: data)
        }

        throw APIError.from(httpResponse: httpResponse, data: data, service: "Real-Debrid")
    }

    func fetchTorrents(page: Int) async throws -> [RealDebridTorrent] {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents?page=\(page)&limit=50")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([RealDebridTorrent].self, from: data)
        }

        if httpResponse.statusCode == 204 {
            return []
        }

        throw APIError.from(httpResponse: httpResponse, data: data, service: "Real-Debrid")
    }

    func deleteTorrent(id: String) async throws {
        let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/delete/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(SettingsManager.shared.realDebridApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(service: "Real-Debrid")
        }

        if httpResponse.statusCode != 204 {
            throw APIError.from(httpResponse: httpResponse, data: data, service: "Real-Debrid")
        }
    }

    func pingServer() async {
        guard let url = URL(string: "\(dionysusServerBaseURL)/health") else { return }
        let request = URLRequest(url: url, timeoutInterval: 30)
        _ = try? await URLSession.shared.data(for: request)
        print("🏓 [API] Server ping complete")
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
