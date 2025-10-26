import Foundation

struct TraktWatchedMovie: Codable {
    let movie: TraktMovie
}

struct TraktMovie: Codable {
    let ids: TraktIDs
}

struct TraktWatchedShow: Codable {
    let show: TraktShow
    let seasons: [TraktWatchedSeason]
}

struct TraktShow: Codable {
    let ids: TraktIDs
}

struct TraktWatchedSeason: Codable {
    let number: Int
    let episodes: [TraktWatchedEpisode]
}

struct TraktWatchedEpisode: Codable {
    let number: Int
}

struct TraktIDs: Codable {
    let tmdb: Int?
}
