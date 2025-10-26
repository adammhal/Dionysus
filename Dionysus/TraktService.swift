import Foundation
import SwiftUI

class TraktService: ObservableObject {
    static let shared = TraktService()

    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var watchedMovieIDs = Set<Int>()
    @Published var watchedShowIDs = Set<Int>()
    @Published var watchedEpisodeIDs = Set<String>()

    private var accessToken: String? {
        didSet {
            DispatchQueue.main.async {
                self.isAuthenticated = self.accessToken != nil
                if self.isAuthenticated {
                    self.fetchWatchedMovies()
                    self.fetchWatchedShows()
                }
            }
        }
    }
    private var refreshToken: String?

    private init() {
        self.accessToken = KeychainHelper.shared.read(for: "trakt_access_token")
        self.refreshToken = KeychainHelper.shared.read(for: "trakt_refresh_token")
    }

    var authorizationURL: URL {
        let baseURL = "https://trakt.tv/oauth/authorize"
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Secrets.traktClientID),
            URLQueryItem(name: "redirect_uri", value: Secrets.traktCallbackURL)
        ]
        return components.url!
    }

    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) {
        isAuthenticating = true
        let url = URL(string: "https://api.trakt.tv/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "code": code,
            "client_id": Secrets.traktClientID,
            "client_secret": Secrets.traktClientSecret,
            "redirect_uri": Secrets.traktCallbackURL,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String,
                  let refreshToken = json["refresh_token"] as? String else {
                return
            }
            self.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
        }.resume()
    }

    func signOut() {
        KeychainHelper.shared.delete(for: "trakt_access_token")
        KeychainHelper.shared.delete(for: "trakt_refresh_token")
        self.accessToken = nil
        self.refreshToken = nil
    }

    private func saveTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        KeychainHelper.shared.save(token: accessToken, for: "trakt_access_token")
        KeychainHelper.shared.save(token: refreshToken, for: "trakt_refresh_token")
    }

    func fetchWatchedMovies() {
        guard let accessToken = accessToken else { return }
        let url = URL(string: "https://api.trakt.tv/sync/watched/movies")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(Secrets.traktClientID, forHTTPHeaderField: "trakt-api-key")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let watchedMovies = try? JSONDecoder().decode([TraktWatchedMovie].self, from: data) else {
                return
            }
            let movieIDs = watchedMovies.compactMap { $0.movie.ids.tmdb }
            DispatchQueue.main.async {
                self.watchedMovieIDs = Set(movieIDs)
            }
        }.resume()
    }

    func fetchWatchedShows() {
        guard let accessToken = accessToken else { return }
        let url = URL(string: "https://api.trakt.tv/sync/watched/shows")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(Secrets.traktClientID, forHTTPHeaderField: "trakt-api-key")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let watchedShows = try? JSONDecoder().decode([TraktWatchedShow].self, from: data) else {
                return
            }
            let showIDs = watchedShows.compactMap { $0.show.ids.tmdb }
            var episodeIDs = Set<String>()
            for show in watchedShows {
                guard let showID = show.show.ids.tmdb else { continue }
                for season in show.seasons {
                    for episode in season.episodes {
                        episodeIDs.insert("\(showID)-\(season.number)-\(episode.number)")
                    }
                }
            }
            DispatchQueue.main.async {
                self.watchedShowIDs = Set(showIDs)
                self.watchedEpisodeIDs = episodeIDs
            }
        }.resume()
    }
}
