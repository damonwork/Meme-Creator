/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI
import PhotosUI
import SwiftData

struct MemeEditorView: View {
    @EnvironmentObject var fetcher: PandaCollectionFetcher
    @Environment(\.modelContext) private var modelContext
    
    // Image state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customImage: UIImage?
    @State private var useCustomImage = false
    @State private var cachedPandaImage: UIImage?
    
    // Text layers
    @State private var textLayers: [MemeTextLayer] = [
        MemeTextLayer(text: "", position: CGSize(width: 0, height: -120)),
        MemeTextLayer(text: "", position: CGSize(width: 0, height: 120))
    ]
    
    // Drag state
    @State private var selectedLayerID: UUID?
    @State private var dragOffset: CGSize = .zero
    
    // UI state
    @State private var showControls = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var savedSuccessfully = false
    @State private var shareImage: UIImage?
    @State private var isSaving = false
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            if isLandscape {
                landscapeLayout(geometry: geometry)
            } else {
                portraitLayout(geometry: geometry)
            }
        }
        .navigationTitle("Meme Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                toolbarButtons
            }
        }
        .task {
            if fetcher.imageData.sample.count <= 1 {
                await fetcher.fetchData()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadCustomImage(from: newItem)
        }
        .onChange(of: fetcher.currentPanda) { _, _ in
            // Cache panda image when it changes
            cachePandaImage()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if savedSuccessfully {
                savedOverlay
            }
        }
        .sensoryFeedback(.success, trigger: savedSuccessfully)
    }
    
    // MARK: - Portrait Layout
    
    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Canvas
                memeCanvas(maxWidth: geometry.size.width - 32)
                    .padding(.top, 8)
                
                // Action buttons
                actionButtonsRow
                
                // Text layer editors
                if showControls {
                    textLayerEditors
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showControls)
    }
    
    // MARK: - Landscape Layout
    
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 16) {
            // Canvas on the left
            memeCanvas(maxWidth: geometry.size.width * 0.55)
                .padding(.leading, 16)
            
            // Controls on the right
            ScrollView {
                VStack(spacing: 12) {
                    actionButtonsRow
                    
                    if showControls {
                        textLayerEditors
                    }
                }
                .padding(.trailing, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    // MARK: - Meme Canvas
    
    @ViewBuilder
    private func memeCanvas(maxWidth: CGFloat) -> some View {
        let canvasHeight = min(maxWidth, 500.0)
        
        ZStack {
            if useCustomImage, let customImage {
                MemeCanvasView(
                    uiImage: customImage,
                    textLayers: textLayers,
                    canvasSize: CGSize(width: maxWidth, height: canvasHeight)
                )
            } else if fetcher.isLoading {
                loadingView(size: CGSize(width: maxWidth, height: canvasHeight))
            } else if let errorMsg = fetcher.errorMessage {
                errorView(message: errorMsg, size: CGSize(width: maxWidth, height: canvasHeight))
            } else {
                // Use AsyncImage for panda images
                pandaCanvasView(maxWidth: maxWidth, maxHeight: canvasHeight)
            }
            
            // Drag overlay for text repositioning
            if selectedLayerID != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                if let id = selectedLayerID,
                                   let index = textLayers.firstIndex(where: { $0.id == id }) {
                                    textLayers[index].position.width += value.translation.width
                                    textLayers[index].position.height += value.translation.height
                                }
                                dragOffset = .zero
                                selectedLayerID = nil
                            }
                    )
            }
        }
        .frame(maxWidth: maxWidth, minHeight: 200, maxHeight: canvasHeight)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    @ViewBuilder
    private func pandaCanvasView(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        AsyncImage(url: fetcher.currentPanda.imageUrl) { phase in
            switch phase {
            case .success(let image):
                ZStack {
                    image
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    
                    ForEach(textLayers) { layer in
                        if !layer.text.isEmpty {
                            MemeTextView(layer: layer)
                                .offset(
                                    selectedLayerID == layer.id
                                    ? CGSize(
                                        width: layer.position.width + dragOffset.width,
                                        height: layer.position.height + dragOffset.height
                                    )
                                    : layer.position
                                )
                                .rotationEffect(.degrees(layer.rotation))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedLayerID = selectedLayerID == layer.id ? nil : layer.id
                                    }
                                }
                                .scaleEffect(selectedLayerID == layer.id ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3), value: selectedLayerID)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Meme canvas with \(fetcher.currentPanda.description)")
                .accessibilityHint("Tap on text to select it for repositioning")
                
            case .failure:
                errorView(
                    message: "Failed to load image",
                    size: CGSize(width: maxWidth, height: maxHeight)
                )
                
            case .empty:
                loadingView(size: CGSize(width: maxWidth, height: maxHeight))
                
            @unknown default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: fetcher.currentPanda.imageUrl)
    }
    
    @ViewBuilder
    private func loadingView(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(.ultraThinMaterial)
            .frame(width: size.width, height: size.height * 0.6)
            .overlay {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    @ViewBuilder
    private func errorView(message: String, size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(.ultraThinMaterial)
            .frame(width: size.width, height: size.height * 0.6)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await fetcher.fetchData()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Error: \(message)")
            .accessibilityHint("Tap retry to try again")
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Shuffle photo
                ActionButton(
                    icon: "photo.on.rectangle.angled",
                    label: "Shuffle",
                    action: {
                        withAnimation(.spring(response: 0.4)) {
                            useCustomImage = false
                            fetcher.shufflePanda()
                        }
                    }
                )
                .disabled(fetcher.isLoading || fetcher.errorMessage != nil)
                .accessibilityLabel("Shuffle photo")
                .accessibilityHint("Load a random panda image")
                
                // Photo picker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ActionButtonLabel(icon: "photo.badge.plus", label: "Import")
                }
                .accessibilityLabel("Import photo")
                .accessibilityHint("Choose a photo from your library")
                
                // Add text layer
                ActionButton(
                    icon: "textformat.size",
                    label: "Add Text",
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            textLayers.append(MemeTextLayer())
                            showControls = true
                        }
                    }
                )
                .accessibilityLabel("Add text layer")
                .accessibilityHint("Add a new text overlay to the meme")
                
                // Toggle controls
                ActionButton(
                    icon: showControls ? "slider.horizontal.below.rectangle" : "slider.horizontal.3",
                    label: showControls ? "Hide" : "Controls",
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            showControls.toggle()
                        }
                    }
                )
                .accessibilityLabel(showControls ? "Hide controls" : "Show controls")
                
                // Reset
                ActionButton(
                    icon: "arrow.counterclockwise",
                    label: "Reset",
                    action: resetEditor
                )
                .accessibilityLabel("Reset editor")
                .accessibilityHint("Clear all text and reset to default")
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Toolbar Buttons
    
    @ViewBuilder
    private var toolbarButtons: some View {
        // Save button
        Button {
            saveMeme()
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .disabled(isSaving)
        .accessibilityLabel("Save meme")
        .accessibilityHint("Save the meme to your gallery and library")
        
        // Share button
        Button {
            Task {
                await prepareShareImage()
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(isSaving)
        .accessibilityLabel("Share meme")
        .accessibilityHint("Share the meme with others")
        .sheet(isPresented: Binding(
            get: { shareImage != nil },
            set: { if !$0 { shareImage = nil } }
        )) {
            if let shareImage {
                ShareSheetView(image: shareImage)
            }
        }
    }
    
    // MARK: - Text Layer Editors
    
    private var textLayerEditors: some View {
        VStack(spacing: 8) {
            ForEach(Array(textLayers.enumerated()), id: \.element.id) { index, layer in
                HStack(alignment: .top, spacing: 8) {
                    // Drag handle
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedLayerID = selectedLayerID == layer.id ? nil : layer.id
                        }
                    } label: {
                        Image(systemName: selectedLayerID == layer.id ? "arrow.up.and.down.and.arrow.left.and.right" : "move.3d")
                            .font(.title3)
                            .foregroundStyle(selectedLayerID == layer.id ? .blue : .secondary)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Move text layer \(index + 1)")
                    .accessibilityHint(selectedLayerID == layer.id ? "Currently in move mode. Drag on canvas to reposition." : "Tap to enter move mode")
                    .padding(.top, 14)
                    
                    TextLayerEditor(
                        layer: $textLayers[index],
                        onDelete: {
                            withAnimation(.spring(response: 0.3)) {
                                textLayers.remove(at: index)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Save Overlay
    
    private var savedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
            Text("Saved!")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(30)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.3)) {
                savedSuccessfully = false
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadCustomImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                withAnimation(.spring(response: 0.3)) {
                    customImage = image
                    useCustomImage = true
                }
            } else {
                errorMessage = "Failed to load the selected image."
                showError = true
            }
        }
    }
    
    private func cachePandaImage() {
        guard let url = fetcher.currentPanda.imageUrl else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                cachedPandaImage = image
            }
        }
    }
    
    private func resetEditor() {
        withAnimation(.spring(response: 0.4)) {
            textLayers = [
                MemeTextLayer(text: "", position: CGSize(width: 0, height: -120)),
                MemeTextLayer(text: "", position: CGSize(width: 0, height: 120))
            ]
            customImage = nil
            useCustomImage = false
            selectedLayerID = nil
            selectedPhotoItem = nil
            cachedPandaImage = nil
        }
    }
    
    @MainActor
    private func renderMemeWithImage(_ backgroundImage: UIImage) -> UIImage? {
        let exportView = MemeCanvasView(
            uiImage: backgroundImage,
            textLayers: textLayers,
            canvasSize: CGSize(width: 600, height: 600),
            isExporting: true
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
    
    @MainActor
    private func getBackgroundImage() async -> UIImage? {
        if useCustomImage, let customImage {
            return customImage
        }
        
        // Use cached image or download
        if let cached = cachedPandaImage {
            return cached
        }
        
        // Download panda image
        guard let url = fetcher.currentPanda.imageUrl,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let downloadedImage = UIImage(data: data) else {
            return nil
        }
        
        cachedPandaImage = downloadedImage
        return downloadedImage
    }
    
    private func prepareShareImage() async {
        isSaving = true
        defer { isSaving = false }
        
        guard let backgroundImage = await getBackgroundImage() else {
            errorMessage = "Failed to load the image for sharing."
            showError = true
            return
        }
        
        guard let rendered = renderMemeWithImage(backgroundImage) else {
            errorMessage = "Failed to render the meme for sharing."
            showError = true
            return
        }
        
        shareImage = rendered
    }
    
    private func saveMeme() {
        isSaving = true
        
        Task { @MainActor in
            defer { isSaving = false }
            
            guard let backgroundImage = await getBackgroundImage() else {
                errorMessage = "Failed to load the image."
                showError = true
                return
            }
            
            guard let finalImage = renderMemeWithImage(backgroundImage),
                  let imageData = finalImage.jpegData(compressionQuality: 0.9) else {
                errorMessage = "Failed to render the meme image."
                showError = true
                return
            }
            
            // Save to Photos
            PhotoLibrarySaver.shared.save(finalImage) { error in
                if let error {
                    Task { @MainActor in
                        errorMessage = "Could not save to Photos: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
            
            // Save to SwiftData
            let savedMeme = SavedMeme(
                imageData: imageData,
                title: textLayers.first(where: { !$0.text.isEmpty })?.text ?? "Meme"
            )
            modelContext.insert(savedMeme)

            do {
                try modelContext.save()
            } catch {
                modelContext.delete(savedMeme)
                errorMessage = "Could not save meme data: \(error.localizedDescription)"
                showError = true
                return
            }

            withAnimation(.spring(response: 0.3)) {
                savedSuccessfully = true
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let image: UIImage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Action Button Components

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ActionButtonLabel(icon: icon, label: label)
        }
    }
}

struct ActionButtonLabel: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .frame(height: 24)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .frame(width: 64, height: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.primary)
    }
}

#Preview {
    NavigationStack {
        MemeEditorView()
            .environmentObject(PandaCollectionFetcher())
    }
    .modelContainer(for: SavedMeme.self, inMemory: true)
}
