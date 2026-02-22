/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI
import Foundation

/// Represents a single text layer on a meme
struct MemeTextLayer: Identifiable, Equatable {
    let id = UUID()
    var text: String = ""
    var fontSize: CGFloat = 48
    var fontName: String = "Impact"
    var textColor: Color = .white
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var position: CGSize = .zero  // offset from center
    var rotation: Double = 0
    var alignment: TextAlignment = .center
    
    static func == (lhs: MemeTextLayer, rhs: MemeTextLayer) -> Bool {
        lhs.id == rhs.id
    }
    
    static let availableFonts: [(name: String, displayName: String)] = [
        ("Impact", "Impact"),
        ("Arial-BoldMT", "Arial Bold"),
        ("Helvetica-Bold", "Helvetica Bold"),
        ("Futura-Bold", "Futura Bold"),
        ("GillSans-Bold", "Gill Sans Bold"),
        ("Avenir-Heavy", "Avenir Heavy"),
        ("Menlo-Bold", "Menlo Bold"),
        ("Georgia-Bold", "Georgia Bold"),
        ("Courier-Bold", "Courier Bold"),
        ("AmericanTypewriter-Bold", "Typewriter Bold")
    ]
}

/// The meme canvas view that renders the image with text overlays
struct MemeCanvasView: View {
    let uiImage: UIImage?
    let textLayers: [MemeTextLayer]
    let canvasSize: CGSize
    let isExporting: Bool
    
    init(uiImage: UIImage? = nil, textLayers: [MemeTextLayer], canvasSize: CGSize = CGSize(width: 400, height: 400), isExporting: Bool = false) {
        self.uiImage = uiImage
        self.textLayers = textLayers
        self.canvasSize = canvasSize
        self.isExporting = isExporting
    }
    
    var body: some View {
        ZStack {
            // Background image
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: isExporting ? 0 : 15)
                    .fill(.gray.opacity(0.2))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Select an image to start")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            
            // Text layers
            ForEach(textLayers) { layer in
                if !layer.text.isEmpty {
                    MemeTextView(layer: layer, highQualityStroke: isExporting)
                        .id(layerRenderKey(layer))
                        .offset(layer.position)
                        .rotationEffect(.degrees(layer.rotation))
                }
            }
        }
        .frame(maxWidth: canvasSize.width, maxHeight: canvasSize.height)
        .if(!isExporting) { view in
            view
                .cornerRadius(15)
                .shadow(radius: 5)
        }
    }

    private func layerRenderKey(_ layer: MemeTextLayer) -> String {
        "\(layer.id.uuidString)-\(layer.text)-\(Int(layer.fontSize))-\(layer.fontName)-\(debugColorRGBA(layer.textColor))-\(debugColorRGBA(layer.strokeColor))-\(Int(layer.position.width))-\(Int(layer.position.height))-\(Int(layer.rotation))"
    }
}

/// Individual meme text with stroke effect
struct MemeTextView: View {
    let layer: MemeTextLayer
    let highQualityStroke: Bool

    init(layer: MemeTextLayer, highQualityStroke: Bool = false) {
        self.layer = layer
        self.highQualityStroke = highQualityStroke
    }

    private var strokeOffsets: [CGSize] {
        let width = layer.strokeWidth
        var offsets: [CGSize] = [
            CGSize(width: width, height: 0),
            CGSize(width: -width, height: 0),
            CGSize(width: 0, height: width),
            CGSize(width: 0, height: -width)
        ]

        if highQualityStroke {
            offsets.append(contentsOf: [
                CGSize(width: width, height: width),
                CGSize(width: -width, height: -width),
                CGSize(width: width, height: -width),
                CGSize(width: -width, height: width)
            ])
        }

        return offsets
    }

    private var previewStrokeOffset: CGFloat {
        max(layer.strokeWidth * 0.7, 1)
    }
    
    var body: some View {
        Group {
            if highQualityStroke {
                ZStack {
                    ForEach(Array(strokeOffsets.enumerated()), id: \.offset) { _, offset in
                        Text(layer.text)
                            .font(.custom(layer.fontName, size: layer.fontSize))
                            .fontWeight(.heavy)
                            .foregroundColor(layer.strokeColor)
                            .offset(offset)
                    }

                    Text(layer.text)
                        .font(.custom(layer.fontName, size: layer.fontSize))
                        .fontWeight(.heavy)
                        .foregroundColor(layer.textColor)
                }
            } else {
                Text(layer.text)
                    .font(.custom(layer.fontName, size: layer.fontSize))
                    .fontWeight(.heavy)
                    .foregroundColor(layer.textColor)
                    .shadow(color: layer.strokeColor.opacity(0.95), radius: 0, x: previewStrokeOffset, y: previewStrokeOffset)
                    .shadow(color: layer.strokeColor.opacity(0.95), radius: 0, x: -previewStrokeOffset, y: -previewStrokeOffset)
            }
        }
        .multilineTextAlignment(layer.alignment)
        .padding(.horizontal, 8)
    }
}

/// The text layer editor panel — redesigned with modern glass sections
struct TextLayerEditor: View {
    @Binding var layer: MemeTextLayer
    let focusedLayerID: FocusState<UUID?>.Binding
    let onDelete: () -> Void
    let onApply: () -> Void

    private var fillColorBinding: Binding<Color> {
        Binding(
            get: { layer.textColor },
            set: { newValue in
                layer.textColor = newValue
                onApply()
                debugLogThrottled(
                    "text-fill-color-\(layer.id.uuidString)",
                    interval: 0.2,
                    "Text style changed: id=\(layer.id.uuidString.prefix(6)) fill=\(debugColorRGBA(newValue))"
                )
            }
        )
    }

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { layer.strokeColor },
            set: { newValue in
                layer.strokeColor = newValue
                onApply()
                debugLogThrottled(
                    "text-stroke-color-\(layer.id.uuidString)",
                    interval: 0.2,
                    "Text style changed: id=\(layer.id.uuidString.prefix(6)) stroke=\(debugColorRGBA(newValue))"
                )
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Text input section
            textInputSection

            // Size section
            sizeSection

            // Colors + actions section
            colorsAndActionsSection
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Text Input

    private var textInputSection: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Enter meme text", text: $layer.text)
                    .font(.body)
                    .focused(focusedLayerID, equals: layer.id)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.done)
                    .onChange(of: layer.text) { _, newValue in
                        onApply()
                        debugLogThrottled(
                            "text-input-\(layer.id.uuidString)",
                            "Text layer updated: id=\(layer.id.uuidString.prefix(6)) chars=\(newValue.count)"
                        )
                    }
                    .onChange(of: focusedLayerID.wrappedValue == layer.id) { _, isFocused in
                        debugLog("Text field focus changed: id=\(layer.id.uuidString.prefix(6)) focused=\(isFocused)")
                    }
                    .onSubmit {
                        focusedLayerID.wrappedValue = nil
                        onApply()
                        debugLog("Text field submit: id=\(layer.id.uuidString.prefix(6))")
                    }
                    .accessibilityLabel("Meme text input")
                    .accessibilityHint("Type your meme text here")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.55))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
            }

            // Delete button
            Button(role: .destructive) {
                if focusedLayerID.wrappedValue == layer.id {
                    focusedLayerID.wrappedValue = nil
                }
                onDelete()
                onApply()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .buttonStyle(GlassPressButtonStyle())
            .accessibilityLabel("Delete text layer")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedLayerID.wrappedValue = nil
                }
            }
        }
    }

    // MARK: - Size Section

    private var sizeSection: some View {
        HStack(spacing: 10) {
            // Size label with icon
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Size")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, alignment: .leading)
            
            // Custom styled slider track
            Slider(value: $layer.fontSize, in: 16...120, step: 1)
                .tint(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .onChange(of: layer.fontSize) { _, newValue in
                    onApply()
                    debugLogThrottled(
                        "text-font-size-\(layer.id.uuidString)",
                        interval: 0.2,
                        "Text style changed: id=\(layer.id.uuidString.prefix(6)) size=\(Int(newValue))"
                    )
                }
                .accessibilityLabel("Font size")
                .accessibilityValue("\(Int(layer.fontSize)) points")
            
            // Size value badge
            Text("\(Int(layer.fontSize))")
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(.blue)
                .frame(width: 32)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                )
        }
    }

    // MARK: - Colors and Actions

    private var colorsAndActionsSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                colorChip(title: "Fill", selection: fillColorBinding, accessibilityLabel: "Text fill color")
                colorChip(title: "Stroke", selection: strokeColorBinding, accessibilityLabel: "Text stroke color")
                Spacer(minLength: 8)
                applyButton
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    colorChip(title: "Fill", selection: fillColorBinding, accessibilityLabel: "Text fill color")
                    colorChip(title: "Stroke", selection: strokeColorBinding, accessibilityLabel: "Text stroke color")
                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer(minLength: 0)
                    applyButton
                }
            }
        }
    }

    private func colorChip(title: String, selection: Binding<Color>, accessibilityLabel: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textCase(.uppercase)
                .fixedSize(horizontal: true, vertical: false)

            ColorPicker("", selection: selection)
                .labelsHidden()
                .accessibilityLabel(accessibilityLabel)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.35))
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var applyButton: some View {
        Button {
            focusedLayerID.wrappedValue = nil
            onApply()
            debugLog("Text style apply tapped: id=\(layer.id.uuidString.prefix(6))")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text("Apply")
                    .font(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color(red: 0.35, green: 0.55, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(GlassPressButtonStyle())
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
