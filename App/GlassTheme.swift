import SwiftUI

struct GlassBackground: View {
    var body: some View {
        ZStack {
            // Base gradient — cool blue-lavender to warm white
            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.94, blue: 1.0),
                    Color(red: 0.93, green: 0.91, blue: 0.99),
                    Color(red: 0.97, green: 0.96, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Top-right blue highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.55, green: 0.72, blue: 1.0).opacity(0.30), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: 130, y: -230)

            // Bottom-left purple accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.62, green: 0.42, blue: 0.95).opacity(0.14), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -140, y: 270)

            // Center soft white glow
            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 20, y: 60)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Card Modifier

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color(red: 0.25, green: 0.35, blue: 0.65).opacity(0.10), radius: 14, x: 0, y: 7)
    }

    /// Elevated glass card with stronger shadow and subtle inner glow — used for the canvas
    func glassCardElevated(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.60),
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: Color(red: 0.20, green: 0.28, blue: 0.60).opacity(0.18), radius: 24, x: 0, y: 12)
            .shadow(color: Color(red: 0.20, green: 0.28, blue: 0.60).opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerView: View {
    @State private var phase: CGFloat = -1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color.gray.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.35),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase * 350)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

// MARK: - Animated Press Button Style

struct GlassPressButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Floating Particle Burst (saved overlay decoration)

struct ParticleBurstView: View {
    let particleCount: Int
    @State private var isAnimating = false

    init(particleCount: Int = 12) {
        self.particleCount = particleCount
    }

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                Circle()
                    .fill(particleColor(for: index))
                    .frame(width: particleSize(for: index), height: particleSize(for: index))
                    .offset(particleOffset(for: index))
                    .opacity(isAnimating ? 0 : 0.9)
                    .scaleEffect(isAnimating ? 0.3 : 1.0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                isAnimating = true
            }
        }
    }

    private func particleColor(for index: Int) -> Color {
        let colors: [Color] = [
            .green, .blue, .purple, .orange, .yellow, .mint, .cyan, .pink
        ]
        return colors[index % colors.count]
    }

    private func particleSize(for index: Int) -> CGFloat {
        CGFloat((index % 3) + 1) * 4
    }

    private func particleOffset(for index: Int) -> CGSize {
        let angle = (Double(index) / Double(particleCount)) * 2 * .pi
        let radius: CGFloat = isAnimating ? CGFloat(80 + (index % 3) * 25) : 0
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }
}

// MARK: - Stagger Animation Helper

extension View {
    /// Applies an appear animation with staggered delay
    func staggeredAppear(index: Int, baseDelay: Double = 0.05) -> some View {
        self
            .transition(.asymmetric(
                insertion: .scale(scale: 0.92).combined(with: .opacity),
                removal: .opacity
            ))
    }
}
