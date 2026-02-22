/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

/// Browse panda images from the API as templates
struct TemplatesView: View {
    @EnvironmentObject var fetcher: PandaCollectionFetcher
    @State private var selectedPanda: Panda?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]
    
    var body: some View {
        Group {
            if fetcher.isLoading {
                loadingState
            } else if let errorMsg = fetcher.errorMessage {
                errorState(message: errorMsg)
            } else {
                templateGrid
            }
        }
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if fetcher.imageData.sample.count <= 1 {
                await fetcher.fetchData()
            }
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Loading templates...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error State
    
    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Could Not Load Templates")
                .font(.title3)
                .fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await fetcher.fetchData()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading templates. \(message)")
        .accessibilityHint("Tap try again to reload")
    }
    
    // MARK: - Template Grid
    
    private var templateGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose a panda image to use as your meme background")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(fetcher.imageData.sample) { panda in
                        TemplateGridItem(panda: panda, isSelected: fetcher.currentPanda == panda)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    fetcher.currentPanda = panda
                                    selectedPanda = panda
                                }
                            }
                            .accessibilityLabel(panda.description)
                            .accessibilityHint("Tap to use this image as your meme template")
                            .accessibilityAddTraits(fetcher.currentPanda == panda ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Template Grid Item

struct TemplateGridItem: View {
    let panda: Panda
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: panda.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 130)
                        .clipped()
                        .cornerRadius(12)
                        
                case .failure:
                    placeholderView(icon: "exclamationmark.triangle")
                    
                case .empty:
                    placeholderView(icon: nil)
                    
                @unknown default:
                    EmptyView()
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            Text(panda.description)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    @ViewBuilder
    private func placeholderView(icon: String?) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.gray.opacity(0.15))
            .frame(height: 130)
            .overlay {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
    }
}

#Preview {
    NavigationStack {
        TemplatesView()
            .environmentObject(PandaCollectionFetcher())
    }
}
