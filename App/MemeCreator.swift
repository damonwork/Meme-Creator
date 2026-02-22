/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

/// Main content view with tab-based navigation
struct MemeCreator: View {
    @EnvironmentObject var fetcher: PandaCollectionFetcher
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Editor Tab
            NavigationStack {
                MemeEditorView()
            }
            .tabItem {
                Label("Editor", systemImage: "wand.and.stars")
            }
            .tag(0)
            
            // Templates Tab
            NavigationStack {
                TemplatesView()
            }
            .tabItem {
                Label("Templates", systemImage: "square.grid.2x2")
            }
            .tag(1)
            
            // Gallery Tab
            NavigationStack {
                MemeGalleryView()
            }
            .tabItem {
                Label("My Memes", systemImage: "photo.stack")
            }
            .tag(2)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

#Preview {
    MemeCreator()
        .environmentObject(PandaCollectionFetcher())
}
