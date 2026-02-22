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
    
    var body: some View {
        ZStack {
            ForEach(Array(strokeOffsets.enumerated()), id: \.offset) { _, offset in
                Text(layer.text)
                    .font(.custom(layer.fontName, size: layer.fontSize))
                    .fontWeight(.heavy)
                    .foregroundColor(layer.strokeColor)
                    .offset(offset)
            }
            
            // Fill
            Text(layer.text)
                .font(.custom(layer.fontName, size: layer.fontSize))
                .fontWeight(.heavy)
                .foregroundColor(layer.textColor)
        }
        .multilineTextAlignment(layer.alignment)
        .padding(.horizontal, 8)
    }
}

/// The text layer editor panel
struct TextLayerEditor: View {
    @Binding var layer: MemeTextLayer
    let onDelete: () -> Void
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Text input
            HStack {
                TextField("Enter meme text", text: $layer.text)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFocused)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.done)
                    .onSubmit {
                        isTextFocused = false
                    }
                    .accessibilityLabel("Meme text input")
                    .accessibilityHint("Type your meme text here")
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                }
                .accessibilityLabel("Delete text layer")
            }
            
            if !layer.text.isEmpty {
                // Font picker
                HStack {
                    Text("Font")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    Picker("Font", selection: $layer.fontName) {
                        ForEach(MemeTextLayer.availableFonts, id: \.name) { font in
                            Text(font.displayName)
                                .tag(font.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Font selector")
                }
                
                // Font size
                HStack {
                    Text("Size")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    Slider(value: $layer.fontSize, in: 16...120, step: 1)
                        .accessibilityLabel("Font size")
                        .accessibilityValue("\(Int(layer.fontSize)) points")
                    
                    Text("\(Int(layer.fontSize))")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 30)
                }
                
                // Colors
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Text("Fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        ColorPicker("", selection: $layer.textColor)
                            .labelsHidden()
                            .accessibilityLabel("Text fill color")
                    }
                    
                    HStack(spacing: 6) {
                        Text("Stroke")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        ColorPicker("", selection: $layer.strokeColor)
                            .labelsHidden()
                            .accessibilityLabel("Text stroke color")
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
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
