/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.7
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -10

    private struct OnboardingPage {
        let icon: String
        let title: String
        let description: String
        let accentColor: Color
        let gradientColors: [Color]
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "wand.and.stars",
            title: "Create Memes",
            description: "Add text with the classic meme style — bold white text with black outlines. Customize fonts, colors, and sizes.",
            accentColor: Color(red: 0.25, green: 0.47, blue: 0.95),
            gradientColors: [
                Color(red: 0.08, green: 0.18, blue: 0.55),
                Color(red: 0.20, green: 0.42, blue: 0.88),
                Color(red: 0.55, green: 0.72, blue: 1.0)
            ]
        ),
        OnboardingPage(
            icon: "hand.draw",
            title: "Position Freely",
            description: "Drag text layers anywhere on your image. Add as many text layers as you want for the perfect meme.",
            accentColor: Color(red: 0.55, green: 0.22, blue: 0.90),
            gradientColors: [
                Color(red: 0.28, green: 0.08, blue: 0.55),
                Color(red: 0.55, green: 0.22, blue: 0.90),
                Color(red: 0.80, green: 0.60, blue: 1.0)
            ]
        ),
        OnboardingPage(
            icon: "photo.badge.plus",
            title: "Use Any Image",
            description: "Choose from panda templates or import your own photos from your library.",
            accentColor: Color(red: 0.95, green: 0.45, blue: 0.15),
            gradientColors: [
                Color(red: 0.55, green: 0.18, blue: 0.02),
                Color(red: 0.90, green: 0.40, blue: 0.10),
                Color(red: 1.0, green: 0.75, blue: 0.45)
            ]
        ),
        OnboardingPage(
            icon: "square.and.arrow.up",
            title: "Save & Share",
            description: "Save memes to your photo library and share them with friends directly from the app.",
            accentColor: Color(red: 0.18, green: 0.72, blue: 0.48),
            gradientColors: [
                Color(red: 0.05, green: 0.35, blue: 0.22),
                Color(red: 0.15, green: 0.65, blue: 0.42),
                Color(red: 0.50, green: 0.92, blue: 0.72)
            ]
        )
    ]

    private var currentPageData: OnboardingPage { pages[currentPage] }

    var body: some View {
        ZStack {
            // Dynamic background per page
            animatedBackground

            VStack(spacing: 0) {
                // Page content area
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        onboardingPage(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: currentPage)

                // Bottom controls
                bottomControls
            }
        }
        .ignoresSafeArea()
        .onAppear { animateIconIn() }
        .onChange(of: currentPage) { _, _ in animateIconIn() }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        ZStack {
            LinearGradient(
                colors: currentPageData.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative blurred circles
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 350, height: 350)
                .blur(radius: 50)
                .offset(x: 140, y: -280)

            Circle()
                .fill(currentPageData.accentColor.opacity(0.25))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -130, y: 300)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 200, height: 200)
                .blur(radius: 35)
                .offset(x: 60, y: 150)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.55), value: currentPage)
    }

    // MARK: - Page Content

    @ViewBuilder
    private func onboardingPage(page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon with animation
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 130, height: 130)
                    .blur(radius: 2)

                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 110, height: 110)

                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .rotationEffect(.degrees(iconRotation))
            .accessibilityHidden(true)

            // Text card
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.35))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
                }
            }
            .padding(.bottom, 4)

            // Next / Get Started button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        currentPage += 1
                    }
                    debugLog("Onboarding next: page \(currentPage + 1)")
                } else {
                    withAnimation(.easeOut(duration: 0.35)) {
                        hasSeenOnboarding = true
                    }
                    debugLog("Onboarding completed")
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(currentPageData.gradientColors.first ?? .blue)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 16)
                    .background {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    }
            }
            .accessibilityLabel(currentPage < pages.count - 1 ? "Next page" : "Get started with Meme Creator")
            .sensoryFeedback(.selection, trigger: currentPage)

            // Skip button
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasSeenOnboarding = true
                    }
                    debugLog("Onboarding skipped")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .accessibilityLabel("Skip onboarding")
            } else {
                // Invisible placeholder to keep layout stable
                Text(" ")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 52)
    }

    // MARK: - Icon Animation

    private func animateIconIn() {
        iconScale = 0.65
        iconOpacity = 0
        iconRotation = -12

        withAnimation(.spring(response: 0.52, dampingFraction: 0.65)) {
            iconScale = 1.0
            iconOpacity = 1
            iconRotation = 0
        }
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
