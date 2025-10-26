import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var tmdbApiKey: String {
        didSet {
            UserDefaults.standard.set(tmdbApiKey, forKey: "tmdbApiKey")
        }
    }

    @Published var realDebridApiKey: String {
        didSet {
            UserDefaults.standard.set(realDebridApiKey, forKey: "realDebridApiKey")
        }
    }

    private init() {
        self.tmdbApiKey = UserDefaults.standard.string(forKey: "tmdbApiKey") ?? Secrets.tmdbApiKey
        self.realDebridApiKey = UserDefaults.standard.string(forKey: "realDebridApiKey") ?? Secrets.realDebridApiKey
    }
}
