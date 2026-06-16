import SwiftUI

extension Glass {
    /// Frosted variant — a milky neutral tint over the standard glass blur,
    /// closer to Apple's frosted appearance than plain `.regular`.
    static var frosted: Glass { .regular.tint(Color.white.opacity(0.12)) }
}

struct AppGlassFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect(
            .frosted,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

extension View {
    func appGlassField() -> some View {
        modifier(AppGlassFieldModifier())
    }
}

// MARK: - Elevation Shadows

/// Three-level elevation language. Black drop shadows are invisible on dark
/// backgrounds, so card/raised levels fade out in dark mode instead of
/// painting wasted layers.

/// Warm-tinted shadow base for the Calm palette — daylight instead of
/// fluorescent. Default palette keeps neutral black.
private var elevationShadowBase: Color {
    AppConfig.isCalmPalette
        ? Color(red: 0.24, green: 0.18, blue: 0.10)
        : .black
}

/// Resting cards and list groups.
struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: elevationShadowBase.opacity(colorScheme == .dark ? 0.0 : 0.06),
            radius: 10, y: 3
        )
    }
}

/// Floating elements: toasts, pickers, share cards.
struct RaisedShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: elevationShadowBase.opacity(colorScheme == .dark ? 0.45 : 0.18),
            radius: 20, y: 8
        )
    }
}

/// Modal hero moments (success ticket and similar).
struct ModalShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.30), radius: 40, y: 20)
    }
}

extension View {
    func cardShadow() -> some View { modifier(CardShadow()) }
    func raisedShadow() -> some View { modifier(RaisedShadow()) }
    func modalShadow() -> some View { modifier(ModalShadow()) }
}

// MARK: - Capsule Pill Chrome

/// Capsule background + hairline stroke shared by the app's filter pills
/// and filter menu labels.
struct CapsulePillChrome: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(isSelected ? AppConfig.tertiaryFillBg : AppConfig.cardBg)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSelected ? Color(uiColor: .separator) : AppConfig.separatorSoft,
                    lineWidth: 1
                )
            )
    }
}

extension View {
    func capsulePillChrome(isSelected: Bool = false) -> some View {
        modifier(CapsulePillChrome(isSelected: isSelected))
    }
}

// MARK: - Feed Card Scroll Transition

/// Subtle fade + scale as cards enter/leave the viewport.
struct FeedCardScrollTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let reduce = reduceMotion
        content.scrollTransition(.interactive) { view, phase in
            view
                .opacity(phase.isIdentity ? 1 : 0.75)
                .scaleEffect(phase.isIdentity || reduce ? 1 : 0.97)
        }
    }
}

extension View {
    func feedCardScrollTransition() -> some View {
        modifier(FeedCardScrollTransition())
    }
}

/// Small capsule count badge shown inside filter pills.
struct PillCountBadge: View {
    let count: Int
    var emphasized: Bool = false

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(emphasized ? Color(uiColor: .tertiarySystemFill) : AppConfig.surfaceLow)
            .clipShape(Capsule())
    }
}


// MARK: - Playful Motion (home tiles & big cards)

/// Bouncier sibling of ScaleButtonStyle for the playful home surfaces:
/// deeper press, one visible overshoot on release, soft haptic timed to
/// the spring peak so the bounce is felt as well as seen.
struct BouncyTileStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(
                configuration.isPressed
                    ? .snappy(duration: 0.14, extraBounce: 0.0)
                    : .spring(duration: 0.38, bounce: 0.30),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                guard !pressed, !reduceMotion else { return }
                // Soft tick at the overshoot peak (~120ms into the release spring).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    Haptics.impact(.soft)
                }
            }
    }
}

/// Touch-position 3D tilt for large cards — the card leans toward the
/// finger (max ~3°) and squashes slightly, springing back on release.
/// Uses a simultaneous gesture so buttons inside the card keep working.
struct SquishyEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var touch: CGPoint? = nil
    @State private var size: CGSize = .zero

    private var tiltX: Double {
        guard let t = touch, size.height > 0 else { return 0 }
        let normalized = (t.y / size.height - 0.5) * 2   // -1 … 1
        return Double(-normalized) * 3.0                 // top press tilts back
    }
    private var tiltY: Double {
        guard let t = touch, size.width > 0 else { return 0 }
        let normalized = (t.x / size.width - 0.5) * 2
        return Double(normalized) * 3.0
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { size = geo.size }
                        .onChange(of: geo.size) { _, new in size = new }
                }
            )
            .scaleEffect(touch != nil && !reduceMotion ? 0.98 : 1.0)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : tiltX), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(reduceMotion ? 0 : tiltY), axis: (x: 0, y: 1, z: 0))
            .animation(
                touch == nil
                    ? .spring(duration: 0.42, bounce: 0.28)
                    : .interactiveSpring(response: 0.18, dampingFraction: 0.86),
                value: touch
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in touch = value.location }
                    .onEnded { _ in touch = nil }
            )
    }
}

extension View {
    func squishyCard() -> some View { modifier(SquishyEffect()) }
}
