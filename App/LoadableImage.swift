/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

struct LoadableImage: View {
    var imageMetadata: Panda
    var onRetry: (() -> Void)?
    
    var body: some View {
        AsyncImage(url: imageMetadata.imageUrl) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .accessibilityHidden(false)
                    .accessibilityLabel(Text(imageMetadata.description))
                    .transition(.opacity)
                    
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Failed to load image.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if let onRetry {
                        Button("Try Again") {
                            onRetry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: 300, minHeight: 200)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Image failed to load")
                .accessibilityHint("Tap try again to reload")
                
            case .empty:
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 200)
                
            @unknown default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: imageMetadata.imageUrl)
    }
}

#Preview {
    LoadableImage(imageMetadata: Panda.defaultPanda)
}
