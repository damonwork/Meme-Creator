/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI
import PhotosUI
import SwiftData

struct MemeEditorView: View {
    @EnvironmentObject var fetcher: PandaCollectionFetcher
    @Environment(\.modelContext) private var modelContext
    private let defaultTextPosition = CGSize(width: 0, height: 80)
    
    // Image state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customImage: UIImage?
    @State private var useCustomImage = false
    @State private var cachedPandaImage: UIImage?
    
    // Text layers
    @State private var textLayers: [MemeTextLayer] = [
        MemeTextLayer(text: "", position: CGSize(width: 0, height: 80))
    ]
    
    // Drag state
    @State private var selectedLayerID: UUID?
    @State private var dragOffset: CGSize = .zero
    
    // UI state
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var savedSuccessfully = false
    @State private var shareImage: UIImage?
    @State private var isSaving = false
    @State private var pandaCacheTask: Task<Void, Never>?
    @State private var cachedPandaURL: URL?
    @State private var pandaImageLoadError = false
    @State private var renderRevision = 0
    @FocusState private var focusedTextLayerID: UUID?

    // Animation state
    @State private var canvasAppeared = false
    @State private var controlsAppeared = false
    @State private var imageTransitionID = UUID()
    
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
            imageTransitionID = UUID()
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
            if newCount == 0 {
                textLayers = [MemeTextLayer(text: "", position: defaultTextPosition)]
                debugLog("Text layers count reached 0, restoring default layer")
                return
            }
            if newCount > 1, let firstLayer = textLayers.first {
                textLayers = [firstLayer]
                selectedLayerID = nil
                debugLog("Text layers count exceeded 1, keeping first layer only")
                return
            }
            if let focusedTextLayerID,
               !textLayers.contains(where: { $0.id == focusedTextLayerID }) {
                self.focusedTextLayerID = nil
            }
            debugLog("Text layers count changed: \(newCount)")
        }
        .onChange(of: activeLayerDebugFingerprint) { _, newValue in
            guard !newValue.isEmpty else { return }
            debugLogThrottled("active-layer-fingerprint", interval: 0.25, "Layer state changed: \(newValue)")
        }
        .onAppear {
            cachePandaImage()
            debugLog("Editor appeared. Initial layers=\(textLayers.count) customImage=\(useCustomImage)")

            // Staggered entrance animations
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.1)) {
                canvasAppeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.25)) {
                controlsAppeared = true
            }
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
            VStack(spacing: 20) {
                // Canvas with entrance animation
                memeCanvas(maxWidth: safeCanvasWidth)
                    .padding(.top, 12)
                    .scaleEffect(canvasAppeared ? 1.0 : 0.92)
                    .opacity(canvasAppeared ? 1.0 : 0)
                
                // Action buttons
                actionButtonsRow
                    .offset(y: controlsAppeared ? 0 : 20)
                    .opacity(controlsAppeared ? 1.0 : 0)
                
                // Text layer editors
                textLayerEditors
                    .offset(y: controlsAppeared ? 0 : 30)
                    .opacity(controlsAppeared ? 1.0 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
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
                .scaleEffect(canvasAppeared ? 1.0 : 0.92)
                .opacity(canvasAppeared ? 1.0 : 0)
            
            // Controls on the right
            ScrollView {
                VStack(spacing: 14) {
                    actionButtonsRow
                    textLayerEditors
                }
                .padding(.trailing, 16)
                .padding(.vertical, 8)
                .offset(y: controlsAppeared ? 0 : 20)
                .opacity(controlsAppeared ? 1.0 : 0)
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
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else if fetcher.isLoading {
                loadingView(size: CGSize(width: safeWidth, height: canvasHeight))
            } else if let errorMsg = fetcher.errorMessage {
                errorView(message: errorMsg, size: CGSize(width: safeWidth, height: canvasHeight))
            } else {
                pandaCanvasView(maxWidth: safeWidth, maxHeight: canvasHeight)
            }
            
            // Drag overlay for text repositioning
            if selectedLayerID != nil {
                // Visual drag-mode indicator border
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.5),
                                Color.cyan.opacity(0.5),
                                Color.blue.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: selectedLayerID)

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
                                    debugLog("Layer moved: id=\(id.uuidString.prefix(6)) pos=(\(Int(textLayers[index].position.width)),\(Int(textLayers[index].position.height)))")
                                }
                                dragOffset = .zero
                                selectedLayerID = nil
                            }
                    )
            }
        }
        .frame(maxWidth: safeWidth, minHeight: 200, maxHeight: canvasHeight)
        .glassCardElevated(cornerRadius: 22)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedLayerID != nil)
    }
    
    @ViewBuilder
    private func pandaCanvasView(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        if let cachedPandaImage {
            ZStack {
                Image(uiImage: cachedPandaImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .id(imageTransitionID)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: imageTransitionID)

                if let layer = textLayers.first, !layer.text.isEmpty {
                    MemeTextView(layer: layer)
                        .id(layerRenderKey(layer))
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Meme canvas with \(fetcher.currentPanda.description)")
            .accessibilityHint("Tap on text to select it for repositioning")
            .onAppear {
                logCanvasReflection(reason: "canvas-appear")
            }
            .onChange(of: activeLayerDebugFingerprint) { _, _ in
                logCanvasReflection(reason: "canvas-layer-change")
            }
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
    
    // MARK: - Loading View (Shimmer)
    
    @ViewBuilder
    private func loadingView(size: CGSize) -> some View {
        ZStack {
            ShimmerView()
                .frame(width: size.width - 16, height: size.height * 0.6)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 60, height: 60)

                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.secondary)
                }

                Text("Loading...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func errorView(message: String, size: CGSize) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
            }

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                if fetcher.errorMessage != nil {
                    Task { await fetcher.fetchData() }
                } else {
                    pandaImageLoadError = false
                    cachePandaImage()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(GlassPressButtonStyle())
        }
        .frame(width: size.width, height: size.height * 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .accessibilityHint("Tap retry to try again")
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            // Shuffle photo
            EditorActionButton(
                icon: "photo.on.rectangle.angled",
                label: "Shuffle",
                gradient: [Color(red: 0.25, green: 0.47, blue: 0.95), Color(red: 0.40, green: 0.65, blue: 1.0)],
                action: {
                    focusedTextLayerID = nil
                    selectedLayerID = nil
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        useCustomImage = false
                        imageTransitionID = UUID()
                        fetcher.shufflePanda()
                    }
                }
            )
            .disabled(fetcher.isLoading || fetcher.errorMessage != nil)
            .accessibilityLabel("Shuffle photo")
            .accessibilityHint("Load a random panda image")
            
            // Photo picker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                EditorActionButtonLabel(
                    icon: "photo.badge.plus",
                    label: "Import",
                    gradient: [Color(red: 0.55, green: 0.22, blue: 0.90), Color(red: 0.72, green: 0.45, blue: 1.0)]
                )
            }
            .buttonStyle(GlassPressButtonStyle())
            .accessibilityLabel("Import photo")
            .accessibilityHint("Choose a photo from your library")
            
            // Reset
            EditorActionButton(
                icon: "arrow.counterclockwise",
                label: "Reset",
                gradient: [Color(red: 0.85, green: 0.30, blue: 0.25), Color(red: 1.0, green: 0.50, blue: 0.40)],
                action: resetEditor
            )
            .accessibilityLabel("Reset editor")
            .accessibilityHint("Clear all text and reset to default")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 20)
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
                .symbolEffect(.bounce, value: isSaving)
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
            if !textLayers.isEmpty {
                let layerID = textLayers[0].id
                HStack(alignment: .top, spacing: 10) {
                    // Move button with animated indicator
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedLayerID = selectedLayerID == layerID ? nil : layerID
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    selectedLayerID == layerID
                                    ? LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 38, height: 38)

                            Image(systemName: selectedLayerID == layerID ? "arrow.up.and.down.and.arrow.left.and.right" : "move.3d")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selectedLayerID == layerID ? .white : .secondary)
                                .symbolEffect(.bounce, value: selectedLayerID == layerID)
                        }
                    }
                    .buttonStyle(GlassPressButtonStyle())
                    .accessibilityLabel("Move text layer 1")
                    .accessibilityHint(selectedLayerID == layerID ? "Currently in move mode. Drag on canvas to reposition." : "Tap to enter move mode")
                    .padding(.top, 14)

                    TextLayerEditor(
                        layer: $textLayers[0],
                        focusedLayerID: $focusedTextLayerID,
                        onDelete: {
                            deleteTextLayer(withID: layerID)
                        },
                        onApply: {
                            forceCanvasRefresh(reason: "editor-apply")
                        }
                    )
                }
            }
        }
        .padding(10)
        .glassCard(cornerRadius: 20)
    }
    
    // MARK: - Save Overlay
    
    private var savedOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .transition(.opacity)

            ZStack {
                // Particle burst
                ParticleBurstView(particleCount: 14)

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.green.opacity(0.2), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, Color(red: 0.2, green: 0.75, blue: 0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .green.opacity(0.3), radius: 12, x: 0, y: 4)
                    }

                    Text("Saved!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .padding(36)
                .glassCardElevated(cornerRadius: 28)
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                savedSuccessfully = false
            }
        }
    }
    
    // MARK: - Actions

    private func deleteTextLayer(withID id: UUID) {
        guard textLayers.indices.contains(0) else {
            textLayers = [MemeTextLayer(text: "", position: defaultTextPosition)]
            debugLog("Delete requested with no layer available, restored default layer")
            return
        }

        focusedTextLayerID = nil
        debugLog("Delete requested for layer \(id.uuidString.prefix(6))")

        withAnimation(.spring(response: 0.3)) {
            textLayers[0].text = ""
            textLayers[0].fontSize = 48
            textLayers[0].fontName = "Impact"
            textLayers[0].textColor = .white
            textLayers[0].strokeColor = .black
            textLayers[0].strokeWidth = 2
            textLayers[0].position = defaultTextPosition
            textLayers[0].rotation = 0
            textLayers[0].alignment = .center

            if selectedLayerID == id {
                selectedLayerID = nil
            }
        }
        forceCanvasRefresh(reason: "delete")

        debugLog("Delete applied. Active layer reset to defaults")
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    customImage = image
                    useCustomImage = true
                    imageTransitionID = UUID()
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        cachedPandaImage = image
                    }
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

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            textLayers = [
                MemeTextLayer(text: "", position: defaultTextPosition)
            ]
            customImage = nil
            useCustomImage = false
            selectedLayerID = nil
            selectedPhotoItem = nil
            cachedPandaImage = nil
            cachedPandaURL = nil
            pandaImageLoadError = false
            imageTransitionID = UUID()
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
        
        if let cached = cachedPandaImage,
           cachedPandaURL == fetcher.currentPanda.imageUrl {
            return cached
        }
        
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

            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                savedSuccessfully = true
            }
            debugLog("Save meme succeeded")
        }
    }

    private var activeLayerDebugFingerprint: String {
        guard let layer = textLayers.first else { return "" }

        return "id=\(layer.id.uuidString.prefix(6)) textChars=\(layer.text.count) "
        + "font=\(layer.fontName) size=\(Int(layer.fontSize)) "
        + "fill=\(debugColorRGBA(layer.textColor)) stroke=\(debugColorRGBA(layer.strokeColor)) "
        + "pos=(\(Int(layer.position.width)),\(Int(layer.position.height)))"
    }

    private func logCanvasReflection(reason: String) {
        guard let layer = textLayers.first else {
            debugLogThrottled("canvas-reflect-empty", interval: 0.4, "Canvas reflection [\(reason)]: no-layer")
            return
        }

        debugLogThrottled(
            "canvas-reflect-\(reason)",
            interval: 0.25,
            "Canvas reflection [\(reason)]: id=\(layer.id.uuidString.prefix(6)) visible=\(!layer.text.isEmpty) fill=\(debugColorRGBA(layer.textColor)) stroke=\(debugColorRGBA(layer.strokeColor)) size=\(Int(layer.fontSize)) font=\(layer.fontName)"
        )
    }

    private func forceCanvasRefresh(reason: String) {
        renderRevision &+= 1
        debugLogThrottled("force-canvas-refresh", interval: 0.2, "Force canvas refresh [\(reason)] rev=\(renderRevision)")
    }

    private func layerRenderKey(_ layer: MemeTextLayer) -> String {
        "\(layer.id.uuidString)-\(layer.text)-\(Int(layer.fontSize))-\(layer.fontName)-\(debugColorRGBA(layer.textColor))-\(debugColorRGBA(layer.strokeColor))-\(Int(layer.position.width))-\(Int(layer.position.height))-\(Int(layer.rotation))-rev\(renderRevision)"
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

// MARK: - Editor Action Button Components

struct EditorActionButton: View {
    let icon: String
    let label: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            EditorActionButtonLabel(icon: icon, label: label, gradient: gradient)
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

struct EditorActionButtonLabel: View {
    let icon: String
    let label: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .shadow(color: gradient.first?.opacity(0.35) ?? .clear, radius: 8, x: 0, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
        }
    }
}

#Preview {
    NavigationStack {
        MemeEditorView()
            .environmentObject(PandaCollectionFetcher())
    }
    .modelContainer(for: SavedMeme.self, inMemory: true)
}
