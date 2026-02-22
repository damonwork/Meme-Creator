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
}
