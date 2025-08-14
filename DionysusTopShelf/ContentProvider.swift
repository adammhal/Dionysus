import TVServices

class ServiceProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        Task {
            let content = await createTopShelfContent()
            completionHandler(content)
        }
    }

    private func createTopShelfContent() async -> TVTopShelfContent? {
        do {
            let movies = try await APIService.shared.fetchMovies(from: "/trending/movie/week")
            let shows = try await APIService.shared.fetchTVShows(from: "/trending/tv/week")
            let media = (movies.map(MediaItem.movie) + shows.map(MediaItem.tvShow)).shuffled()

            if media.isEmpty {
                return nil
            }

            var finalItems: [TVTopShelfCarouselItem] = []
            for mediaItem in media {
                let underlyingMedia = mediaItem.underlyingMedia
                
                let identifier = "media_\(underlyingMedia.id)"
                let item = TVTopShelfCarouselItem(identifier: identifier)
                
                item.title = underlyingMedia.title
                item.summary = underlyingMedia.overview
                
                if let brandedImageURL = APIService.shared.getBrandedImageURL(for: underlyingMedia) {
                    item.setImageURL(brandedImageURL, for: .screenScale1x)
                } else {
                    continue
                }
                
                do {
                    let videos = try await APIService.shared.fetchVideos(for: underlyingMedia)
                    if let videoKey = videos.first?.key {
                        if let directTrailerURL = try await APIService.shared.resolveYoutubeURL(for: videoKey) {
                            item.previewVideoURL = directTrailerURL
                        }
                    }
                } catch {
                    
                }
                
                let mediaType = underlyingMedia is Movie ? "movie" : "tv"
                if let displayURL = URL(string: "dionysus://\(mediaType)/\(underlyingMedia.id)") {
                    item.displayAction = TVTopShelfAction(url: displayURL)
                }
                let releaseYear = (underlyingMedia.releaseDate?.split(separator: "-").first).map(String.init) ?? ""
                let searchQuery = (underlyingMedia is TVShow) ? "\(underlyingMedia.title) complete" : "\(underlyingMedia.title) \(releaseYear)"
                if let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let playURL = URL(string: "dionysus://sources/\(mediaType)/\(underlyingMedia.id)?query=\(encodedQuery)") {
                    item.playAction = TVTopShelfAction(url: playURL)
                }
                
                finalItems.append(item)
            }
            
            if finalItems.isEmpty {
                return nil
            }
            
            let carouselContent = TVTopShelfCarouselContent(style: .details, items: finalItems)
            return carouselContent

        } catch {
            return nil
        }
    }
}
