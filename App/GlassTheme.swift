import SwiftUI

struct GlassBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.9, green: 0.94, blue: 0.98),
                Color(red: 0.98, green: 0.96, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .offset(x: 120, y: -220)
        }
        .overlay {
            Circle()
                .fill(Color.blue.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 45)
                .offset(x: -130, y: 260)
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
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}
