/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI
import SwiftData

@main
struct MemeCreatorApp: App {
    @StateObject private var fetcher = PandaCollectionFetcher()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
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
}
