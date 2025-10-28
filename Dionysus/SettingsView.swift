import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var traktService = TraktService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Keys")) {
                    SecureApiKeyRow(
                        title: "TMDB API Key",
                        description: "Used for fetching movie & show metadata.",
                        key: $settings.tmdbApiKey
                    )
                    SecureApiKeyRow(
                        title: "Real-Debrid API Key",
                        description: "Used for finding Real-Debrid sources.",
                        key: $settings.realDebridApiKey
                    )
                }

                Section(header: Text("Trakt")) {
                    if traktService.isAuthenticating {
                        HStack {
                            ProgressView()
                            Text("Authenticating...")
                                .foregroundStyle(.secondary)
                        }
                    } else if traktService.isAuthenticated {
                        Button("Sign out from Trakt", role: .destructive) {
                            traktService.signOut()
                        }
                    } else {
                        Link("Sign in with Trakt", destination: traktService.authorizationURL)
                            .foregroundStyle(.blue)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("0.0.5 (Beta)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SecureApiKeyRow: View {
    let title: String
    let description: String
    @Binding var key: String
    @State private var isEditing = false
    @State private var tempKey = ""
    
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if isEditing {
                HStack {
                    SecureField("Enter key", text: $tempKey)
                        .focused($isFieldFocused)
                    Button("Save") {
                        key = tempKey
                        isEditing = false
                        isFieldFocused = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    Button("Cancel") {
                        isEditing = false
                        isFieldFocused = false
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
                .onAppear {
                    isFieldFocused = true
                }
            } else {
                HStack {
                    Text(key.isEmpty ? "Not Set" : "••••••••••••\(key.suffix(4))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(key.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button("Edit") {
                        tempKey = key
                        isEditing = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
