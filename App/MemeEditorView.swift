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
        MemeTextLayer(text: "", position: CGSize(width: 0, height: 0))
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
    @State private var pandaCacheTask: Task<Void, Never>?
    @State private var cachedPandaURL: URL?
    @State private var pandaImageLoadError = false
    @FocusState private var focusedTextLayerID: UUID?
    
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
        .background(GlassBackground())
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
            focusedTextLayerID = nil
            loadCustomImage(from: newItem)
        }
        .onChange(of: fetcher.currentPanda) { _, _ in
            focusedTextLayerID = nil
            selectedLayerID = nil
            pandaImageLoadError = false
            cachePandaImage()
        }
        .onChange(of: selectedLayerID) { _, newValue in
            if let newValue {
                focusedTextLayerID = nil
                debugLog("Move mode enabled for layer \(newValue.uuidString.prefix(6))")
            } else {
                debugLog("Move mode disabled")
            }
        }
        .onChange(of: textLayers.count) { _, newCount in
            if let focusedTextLayerID,
               !textLayers.contains(where: { $0.id == focusedTextLayerID }) {
                self.focusedTextLayerID = nil
            }
            debugLog("Text layers count changed: \(newCount)")
        }
        .onAppear {
            cachePandaImage()
            debugLog("Editor appeared. Initial layers=\(textLayers.count) customImage=\(useCustomImage)")
        }
        .onDisappear {
            pandaCacheTask?.cancel()
            pandaCacheTask = nil
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
        .sheet(isPresented: Binding(
            get: { shareImage != nil },
            set: { if !$0 { shareImage = nil } }
        )) {
            if let shareImage {
                ShareSheetView(image: shareImage)
            }
        }
        .sensoryFeedback(.success, trigger: savedSuccessfully)
    }
    
    // MARK: - Portrait Layout
    
    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        let safeCanvasWidth = max(geometry.size.width - 32, 200)
        ScrollView {
            VStack(spacing: 16) {
                // Canvas
                memeCanvas(maxWidth: safeCanvasWidth)
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
        .safeAreaPadding(.bottom, 8)
    }
    
    // MARK: - Landscape Layout
    
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        let safeCanvasWidth = max(geometry.size.width * 0.55, 200)
        HStack(spacing: 16) {
            // Canvas on the left
            memeCanvas(maxWidth: safeCanvasWidth)
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
        let safeWidth = max(maxWidth, 200)
        let canvasHeight = max(min(safeWidth, 500.0), 200)
        
        ZStack {
            if useCustomImage, let customImage {
                MemeCanvasView(
                    uiImage: customImage,
                    textLayers: textLayers,
                    canvasSize: CGSize(width: safeWidth, height: canvasHeight)
                )
            } else if fetcher.isLoading {
                loadingView(size: CGSize(width: safeWidth, height: canvasHeight))
            } else if let errorMsg = fetcher.errorMessage {
                errorView(message: errorMsg, size: CGSize(width: safeWidth, height: canvasHeight))
            } else {
                // Use the pre-cached panda image for smoother updates
                pandaCanvasView(maxWidth: safeWidth, maxHeight: canvasHeight)
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
                                    let movedPosition = CGSize(
                                        width: textLayers[index].position.width + value.translation.width,
                                        height: textLayers[index].position.height + value.translation.height
                                    )
                                    textLayers[index].position = clampedPosition(
                                        movedPosition,
                                        in: CGSize(width: safeWidth, height: canvasHeight)
                                    )
                                }
                                dragOffset = .zero
                                selectedLayerID = nil
                            }
                    )
            }
        }
        .frame(maxWidth: safeWidth, minHeight: 200, maxHeight: canvasHeight)
        .glassCard(cornerRadius: 20)
    }
    
    @ViewBuilder
    private func pandaCanvasView(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        if let cachedPandaImage {
            ZStack {
                Image(uiImage: cachedPandaImage)
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
        } else if pandaImageLoadError {
            errorView(
                message: "Failed to load image",
                size: CGSize(width: maxWidth, height: maxHeight)
            )
        } else {
            loadingView(size: CGSize(width: maxWidth, height: maxHeight))
                .task {
                    cachePandaImage()
                }
        }
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
                        if fetcher.errorMessage != nil {
                            Task {
                                await fetcher.fetchData()
                            }
                        } else {
                            pandaImageLoadError = false
                            cachePandaImage()
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
                        focusedTextLayerID = nil
                        selectedLayerID = nil
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
                        let newLayer = MemeTextLayer()
                        withAnimation(.spring(response: 0.3)) {
                            textLayers.append(newLayer)
                            showControls = true
                        }
                        focusedTextLayerID = newLayer.id
                    }
                )
                .accessibilityLabel("Add text layer")
                .accessibilityHint("Add a new text overlay to the meme")
                
                // Toggle controls
                ActionButton(
                    icon: showControls ? "slider.horizontal.below.rectangle" : "slider.horizontal.3",
                    label: showControls ? "Hide" : "Controls",
                    action: {
                        if showControls {
                            focusedTextLayerID = nil
                        }
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
        .padding(10)
        .glassCard(cornerRadius: 18)
    }
    
    // MARK: - Toolbar Buttons
    
    @ViewBuilder
    private var toolbarButtons: some View {
        // Save button
        Button {
            focusedTextLayerID = nil
            saveMeme()
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .disabled(isSaving)
        .accessibilityLabel("Save meme")
        .accessibilityHint("Save the meme to your gallery and library")
        
        // Share button
        Button {
            focusedTextLayerID = nil
            Task {
                await prepareShareImage()
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(isSaving)
        .accessibilityLabel("Share meme")
        .accessibilityHint("Share the meme with others")
    }
    
    // MARK: - Text Layer Editors
    
    private var textLayerEditors: some View {
        VStack(spacing: 8) {
            ForEach(textLayers) { layer in
                if let index = textLayers.firstIndex(where: { $0.id == layer.id }) {
                    let layerID = textLayers[index].id
                    let layerNumber = index + 1

                    HStack(alignment: .top, spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedLayerID = selectedLayerID == layerID ? nil : layerID
                            }
                        } label: {
                            Image(systemName: selectedLayerID == layerID ? "arrow.up.and.down.and.arrow.left.and.right" : "move.3d")
                                .font(.title3)
                                .foregroundStyle(selectedLayerID == layerID ? .blue : .secondary)
                                .frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("Move text layer \(layerNumber)")
                        .accessibilityHint(selectedLayerID == layerID ? "Currently in move mode. Drag on canvas to reposition." : "Tap to enter move mode")
                        .padding(.top, 14)

                        TextLayerEditor(
                            layer: $textLayers[index],
                            focusedLayerID: $focusedTextLayerID,
                            onDelete: {
                                deleteTextLayer(withID: layerID)
                            }
                        )
                    }
                }
            }
        }
        .padding(8)
        .glassCard(cornerRadius: 18)
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
        .glassCard(cornerRadius: 20)
        .transition(.scale.combined(with: .opacity))
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.3)) {
                savedSuccessfully = false
            }
        }
    }
    
    // MARK: - Actions

    private func deleteTextLayer(withID id: UUID) {
        focusedTextLayerID = nil

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3)) {
                guard let index = textLayers.firstIndex(where: { $0.id == id }) else { return }

                if textLayers.count == 1 {
                    textLayers[index].text = ""
                    textLayers[index].fontSize = 48
                    textLayers[index].fontName = "Impact"
                    textLayers[index].textColor = .white
                    textLayers[index].strokeColor = .black
                    textLayers[index].strokeWidth = 2
                    textLayers[index].position = .zero
                    textLayers[index].rotation = 0
                    textLayers[index].alignment = .center
                } else {
                    textLayers.remove(at: index)
                }

                if selectedLayerID == id {
                    selectedLayerID = nil
                }
            }
        }
    }
    
    private func loadCustomImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        focusedTextLayerID = nil
        selectedLayerID = nil
        pandaCacheTask?.cancel()
        pandaCacheTask = nil
        debugLog("Import photo started")
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                withAnimation(.spring(response: 0.3)) {
                    customImage = image
                    useCustomImage = true
                }
                debugLog("Import photo succeeded")
            } else {
                errorMessage = "Failed to load the selected image."
                showError = true
                debugLog("Import photo failed")
            }
        }
    }
    
    private func cachePandaImage() {
        guard let url = fetcher.currentPanda.imageUrl else {
            pandaCacheTask?.cancel()
            pandaCacheTask = nil
            cachedPandaImage = nil
            cachedPandaURL = nil
            pandaImageLoadError = false
            return
        }

        if cachedPandaURL == url {
            if cachedPandaImage != nil || pandaCacheTask != nil {
                return
            }
        } else {
            pandaCacheTask?.cancel()
            pandaCacheTask = nil
        }

        pandaImageLoadError = false
        cachedPandaImage = nil
        cachedPandaURL = url

        pandaCacheTask = Task(priority: .userInitiated) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }

                await MainActor.run {
                    guard fetcher.currentPanda.imageUrl == url else { return }
                    pandaCacheTask = nil
                    cachedPandaImage = image
                    pandaImageLoadError = false
                    debugLog("Template image cached")
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard fetcher.currentPanda.imageUrl == url else { return }
                    pandaCacheTask = nil
                    pandaImageLoadError = true
                    debugLogThrottled("template-cache-failed", interval: 1.5, "Template image cache failed")
                }
            }
        }
    }
    
    private func resetEditor() {
        focusedTextLayerID = nil
        pandaCacheTask?.cancel()
        pandaCacheTask = nil

        withAnimation(.spring(response: 0.4)) {
            textLayers = [
                MemeTextLayer(text: "", position: CGSize(width: 0, height: 0))
            ]
            customImage = nil
            useCustomImage = false
            selectedLayerID = nil
            selectedPhotoItem = nil
            cachedPandaImage = nil
            cachedPandaURL = nil
            pandaImageLoadError = false
        }
        cachePandaImage()
        debugLog("Editor reset")
    }

    private func clampedPosition(_ position: CGSize, in canvasSize: CGSize) -> CGSize {
        let horizontalPadding: CGFloat = 24
        let verticalPadding: CGFloat = 24
        let maxX = max(canvasSize.width / 2 - horizontalPadding, 0)
        let maxY = max(canvasSize.height / 2 - verticalPadding, 0)

        return CGSize(
            width: min(max(position.width, -maxX), maxX),
            height: min(max(position.height, -maxY), maxY)
        )
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
        if let cached = cachedPandaImage,
           cachedPandaURL == fetcher.currentPanda.imageUrl {
            return cached
        }
        
        // Download panda image
        guard let url = fetcher.currentPanda.imageUrl,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let downloadedImage = UIImage(data: data) else {
            return nil
        }
        
        cachedPandaImage = downloadedImage
        cachedPandaURL = url
        return downloadedImage
    }
    
    private func prepareShareImage() async {
        focusedTextLayerID = nil
        debugLog("Share preparation started")
        isSaving = true
        defer { isSaving = false }
        
        guard let backgroundImage = await getBackgroundImage() else {
            errorMessage = "Failed to load the image for sharing."
            showError = true
            debugLog("Share preparation failed: background image unavailable")
            return
        }
        
        guard let rendered = renderMemeWithImage(backgroundImage) else {
            errorMessage = "Failed to render the meme for sharing."
            showError = true
            debugLog("Share preparation failed: render error")
            return
        }
        
        shareImage = rendered
        debugLog("Share preparation succeeded")
    }
    
    private func saveMeme() {
        focusedTextLayerID = nil
        debugLog("Save meme started")
        isSaving = true
        
        Task { @MainActor in
            defer { isSaving = false }
            
            guard let backgroundImage = await getBackgroundImage() else {
                errorMessage = "Failed to load the image."
                showError = true
                debugLog("Save meme failed: background image unavailable")
                return
            }
            
            guard let finalImage = renderMemeWithImage(backgroundImage),
                  let imageData = finalImage.jpegData(compressionQuality: 0.9) else {
                errorMessage = "Failed to render the meme image."
                showError = true
                debugLog("Save meme failed: render/jpeg conversion")
                return
            }
            
            // Save to Photos
            PhotoLibrarySaver.shared.save(finalImage) { error in
                if let error {
                    Task { @MainActor in
                        errorMessage = "Could not save to Photos: \(error.localizedDescription)"
                        showError = true
                        debugLog("Save to Photos failed: \(error.localizedDescription)")
                    }
                } else {
                    debugLog("Save to Photos succeeded")
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
                debugLog("Save meme failed: SwiftData save error \(error.localizedDescription)")
                return
            }

            withAnimation(.spring(response: 0.3)) {
                savedSuccessfully = true
            }
            debugLog("Save meme succeeded")
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
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
