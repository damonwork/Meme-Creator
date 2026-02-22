/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [(icon: String, title: String, description: String)] = [
        (
            "wand.and.stars",
            "Create Memes",
            "Add text with the classic meme style — bold white text with black outlines. Customize fonts, colors, and sizes."
        ),
        (
            "hand.draw",
            "Position Freely",
            "Drag text layers anywhere on your image. Add as many text layers as you want for the perfect meme."
        ),
        (
            "photo.badge.plus",
            "Use Any Image",
            "Choose from panda templates or import your own photos from your library."
        ),
        (
            "square.and.arrow.up",
            "Save & Share",
            "Save memes to your photo library and share them with friends directly from the app."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Pages
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    let page = pages[index]
                    onboardingPage(icon: page.icon, title: page.title, description: page.description)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)
            
            // Bottom section
            VStack(spacing: 16) {
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4)) {
                            currentPage += 1
                        }
                        debugLog("Onboarding next: page \(currentPage + 1)")
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            hasSeenOnboarding = true
                        }
                        debugLog("Onboarding completed")
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(currentPage < pages.count - 1 ? "Next page" : "Get started with Meme Creator")
                
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        withAnimation(.easeOut(duration: 0.3)) {
                            hasSeenOnboarding = true
                        }
                        debugLog("Onboarding skipped")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Skip onboarding")
                }
            }
            .padding(.bottom, 40)
        }
        .background(GlassBackground())
    }
    
    @ViewBuilder
    private func onboardingPage(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 70, weight: .light))
                .foregroundStyle(.tint)
                .frame(height: 90)
                .accessibilityHidden(true)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(22)
            .glassCard(cornerRadius: 24)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
