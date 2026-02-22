/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI
import SwiftData
import Foundation

@main
struct MemeCreatorApp: App {
    @StateObject private var fetcher = PandaCollectionFetcher()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        ensureApplicationSupportDirectoryExists()
    }
    
    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                MemeCreator()
                    .environmentObject(fetcher)
                    .transition(.opacity)
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .transition(.opacity)
            }
        }
        .modelContainer(for: SavedMeme.self)
    }

    private func ensureApplicationSupportDirectoryExists() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            debugLog("Failed to create Application Support directory: \(error.localizedDescription)")
        }
    }
}
