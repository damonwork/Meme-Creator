/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI
import SwiftData

struct MemeGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedMeme.createdAt, order: .reverse) private var savedMemes: [SavedMeme]
    
    @State private var selectedMeme: SavedMeme?
    @State private var showDeleteConfirmation = false
    @State private var memeToDelete: SavedMeme?
    @State private var persistenceErrorMessage: String?
    @State private var shareImage: UIImage?
    
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)
    ]
    
    var body: some View {
        Group {
            if savedMemes.isEmpty {
                emptyState
            } else {
                galleryGrid
            }
        }
        .navigationTitle("My Memes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMeme) { meme in
            MemeDetailView(meme: meme, onDelete: {
                deleteMeme(meme)
                selectedMeme = nil
            })
        }
        .sheet(isPresented: Binding(
            get: { shareImage != nil },
            set: { if !$0 { shareImage = nil } }
        )) {
            if let shareImage {
                ShareSheetView(image: shareImage)
            }
        }
        .alert("Delete Meme", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let meme = memeToDelete {
                    deleteMeme(meme)
                }
            }
            Button("Cancel", role: .cancel) {
                memeToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this meme? This action cannot be undone.")
        }
        .alert(
            "Storage Error",
            isPresented: Binding(
                get: { persistenceErrorMessage != nil },
                set: { if !$0 { persistenceErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? "")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Memes Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create and save memes in the editor\nto see them here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No saved memes. Create and save memes in the editor to see them here.")
    }
    
    // MARK: - Gallery Grid
    
    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(savedMemes) { meme in
                    MemeGridItem(meme: meme)
                        .onTapGesture {
                            selectedMeme = meme
                        }
                        .contextMenu {
                            Button {
                                selectedMeme = meme
                            } label: {
                                Label("View", systemImage: "eye")
                            }
                            
                            if let uiImage = meme.uiImage {
                                Button {
                                    shareImage = uiImage
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                            
                            Button(role: .destructive) {
                                memeToDelete = meme
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .accessibilityLabel("Meme: \(meme.title)")
                        .accessibilityHint("Tap to view, long press for options")
                }
            }
            .padding(16)
        }
    }
    
    private func deleteMeme(_ meme: SavedMeme) {
        withAnimation(.spring(response: 0.3)) {
            modelContext.delete(meme)

            do {
                try modelContext.save()
            } catch {
                persistenceErrorMessage = "Could not delete meme: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Grid Item

struct MemeGridItem: View {
    let meme: SavedMeme
    
    var body: some View {
        VStack(spacing: 6) {
            if let uiImage = meme.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipped()
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.2))
                    .frame(height: 140)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meme.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(meme.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Detail View

struct MemeDetailView: View {
    let meme: SavedMeme
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var copiedToClipboard = false
    @State private var savedToPhotos = false
    @State private var saveErrorMessage: String?
    @State private var shareImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let uiImage = meme.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding()
                    
                    HStack(spacing: 20) {
                        // Share
                        Button {
                            shareImage = uiImage
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                Text("Share")
                                    .font(.caption)
                            }
                            .frame(width: 70, height: 56)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Share meme")
                        
                        // Copy to clipboard
                        Button {
                            UIPasteboard.general.image = uiImage
                            copiedToClipboard.toggle()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                    .font(.title2)
                                Text(copiedToClipboard ? "Copied" : "Copy")
                                    .font(.caption)
                            }
                            .frame(width: 70, height: 56)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .sensoryFeedback(.success, trigger: copiedToClipboard)
                        .accessibilityLabel("Copy to clipboard")
                        
                        // Save to photos
                        Button {
                            PhotoLibrarySaver.shared.save(uiImage) { error in
                                Task { @MainActor in
                                    if let error {
                                        saveErrorMessage = "Could not save to Photos: \(error.localizedDescription)"
                                    } else {
                                        savedToPhotos.toggle()
                                    }
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                                    .font(.title2)
                                Text(savedToPhotos ? "Saved" : "Save")
                                    .font(.caption)
                            }
                            .frame(width: 70, height: 56)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .sensoryFeedback(.success, trigger: savedToPhotos)
                        .accessibilityLabel("Save to photo library")
                        
                        // Delete
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.title2)
                                Text("Delete")
                                    .font(.caption)
                            }
                            .frame(width: 70, height: 56)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Delete meme")
                    }
                    .foregroundStyle(.primary)
                }
                
                Spacer()
            }
            .navigationTitle(meme.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(
                "Error Saving Photo",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .sheet(isPresented: Binding(
                get: { shareImage != nil },
                set: { if !$0 { shareImage = nil } }
            )) {
                if let shareImage {
                    ShareSheetView(image: shareImage)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MemeGalleryView()
    }
    .modelContainer(for: SavedMeme.self, inMemory: true)
}
