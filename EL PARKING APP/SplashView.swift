//
//  SplashView.swift
//  EL PARKING APP
//
//  Launch splash shown while auth state resolves.
//  The first frame matches the static launch screen background exactly
//  (no color blink), then the canvas eases toward the active palette:
//  ambient glow orbs drift on continuous sine paths, a dashed parking-bay
//  outline draws itself around the icon, one specular sweep crosses the
//  glyph, and the wordmark settles its letterspacing into place.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared         = false
    @State private var sweepPhase: CGFloat = -1.0
    @State private var bayProgress: CGFloat = 0
    @State private var subtitleTracking: CGFloat = 4.0

    private let startDate = Date()

    /// Must stay in sync with Assets.xcassets/LaunchBackground.
    private static let launchBackground = Color(red: 0.039, green: 0.039, blue: 0.055)
    /// Calm palette's "forest at dusk" — faded in over the launch color.
    private static let calmForest = Color(red: 34/255, green: 40/255, blue: 31/255)

    private let iconSize: CGFloat = 116
    private var iconShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: iconSize * 0.2237, style: .continuous)
    }

    var body: some View {
        ZStack {
            // Base always equals the static launch screen for a seamless handoff.
            Self.launchBackground
                .ignoresSafeArea()

            // Calm palette tints the canvas as the entrance plays.
            if AppConfig.isCalmPalette {
                Self.calmForest
                    .opacity(appeared ? 0.85 : 0)
                    .ignoresSafeArea()
            }

            // Continuous ambient drift — two glow orbs on slow sine paths.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSince(startDate)
                ambient(time: reduceMotion ? 0 : t)
            }
            .allowsHitTesting(false)

            VStack(spacing: 26) {
                iconBlock
                    .scaleEffect(appeared ? 1.0 : 0.84)
                    .opacity(appeared ? 1 : 0)

                wordmark
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }
        }
        .onAppear(perform: runEntrance)
    }

    // MARK: - Ambient

    private func ambient(time t: TimeInterval) -> some View {
        ZStack {
            // Primary glow — breathes and drifts behind the icon.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppConfig.accent.opacity(0.28), AppConfig.accent.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 230
                    )
                )
                .frame(width: 460, height: 460)
                .scaleEffect(1.0 + 0.07 * sin(t * 2 * .pi / 6.5))
                .offset(
                    x: 18 * sin(t * 2 * .pi / 9.0),
                    y: -30 + 12 * cos(t * 2 * .pi / 7.5)
                )

            // Counter-drifting secondary orb — adds depth, very faint.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(
                    x: -60 - 24 * sin(t * 2 * .pi / 11.0),
                    y: 120 + 16 * sin(t * 2 * .pi / 8.0)
                )
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Icon

    private var iconBlock: some View {
        ZStack {
            // Dashed parking bay drawing itself around the icon —
            // the same motif as the home empty-state hero.
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .trim(from: 0, to: bayProgress)
                .stroke(
                    Color.white.opacity(0.20),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [7, 6])
                )
                .frame(width: iconSize + 52, height: iconSize + 52)
                .rotationEffect(.degrees(-90))

            icon
        }
    }

    private var icon: some View {
        Image("AppIconImage")
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .clipShape(iconShape)
            .overlay {
                // Top-lit hairline so the black icon reads against the dark background.
                iconShape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .overlay {
                // Single specular sweep across the icon after it settles.
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.22), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 0.7)
                    .rotationEffect(.degrees(8))
                    .offset(x: sweepPhase * geo.size.width * 1.6)
                }
                .clipShape(iconShape)
                .allowsHitTesting(false)
            }
            .shadow(color: AppConfig.accent.opacity(0.25), radius: 28, y: 6)
            .shadow(color: Color.black.opacity(0.5), radius: 18, y: 10)
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        VStack(spacing: 5) {
            Text("EL Parking")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("EssilorLuxottica")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .tracking(subtitleTracking)
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }

    // MARK: - Choreography

    private func runEntrance() {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
                bayProgress = 1
                subtitleTracking = 1.2
            }
            return
        }

        withAnimation(.smooth(duration: 0.65)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 0.9).delay(0.25)) {
            bayProgress = 1
        }
        withAnimation(.smooth(duration: 1.1).delay(0.3)) {
            subtitleTracking = 1.2
        }
        withAnimation(.easeInOut(duration: 0.9).delay(0.7)) {
            sweepPhase = 1.0
        }
    }
}

#Preview {
    SplashView()
}
