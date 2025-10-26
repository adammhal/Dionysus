import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var traktService = TraktService.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Keys")) {
                    TextField("TMDB API Key", text: $settings.tmdbApiKey)
                    TextField("Real-Debrid API Key", text: $settings.realDebridApiKey)
                }

                Section(header: Text("Trakt")) {
                    if traktService.isAuthenticating {
                        HStack {
                            ProgressView()
                            Text("Authenticating...")
                        }
                    } else if traktService.isAuthenticated {
                        Button("Sign out from Trakt") {
                            traktService.signOut()
                        }
                    } else {
                        Link("Sign in with Trakt", destination: traktService.authorizationURL)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
