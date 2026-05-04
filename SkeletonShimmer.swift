import SwiftUI

struct SkeletonBlock: View {
    var height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(height: height)
            .shimmering(active: true)
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.9

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.35),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: max(44, width * 0.28))
                        .offset(x: width * phase)
                        .blendMode(.plusLighter)
                    }
                    .clipped()
                    .allowsHitTesting(false)
                }
                .task {
                    phase = -0.9
                    withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
        }
    }
}

extension View {
    @ViewBuilder
    func shimmering(active: Bool) -> some View {
        if active {
            modifier(ShimmerModifier())
        } else {
            self
        }
    }
}
