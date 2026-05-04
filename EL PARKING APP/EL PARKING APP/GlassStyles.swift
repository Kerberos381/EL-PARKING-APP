import SwiftUI

struct AppGlassFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.34))
            }
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.stroke(
                    colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.45),
                    lineWidth: 1
                )
            }
    }
}

extension View {
    func appGlassField() -> some View {
        modifier(AppGlassFieldModifier())
    }
}
