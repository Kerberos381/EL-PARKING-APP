import SwiftUI

// MARK: - SkeletonBlock

struct SkeletonBlock: View {
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(height: height)
            .shimmering(active: true)
    }
}

// MARK: - AppEmptyStateCard

struct AppEmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var footnote: String? = nil
    var action: (() -> Void)? = nil

    init(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        actionIcon: String? = nil,
        footnote: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.footnote = footnote
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if let actionIcon {
                            Image(systemName: actionIcon)
                        }
                        Text(actionTitle)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(AppConfig.accent)
            }

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppConfig.cardBg)
        )
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        if active {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.2),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: -geo.size.width + phase * geo.size.width * 3)
                    }
                    .clipped()
                )
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }

    func appGlassField() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppConfig.radius12, style: .continuous)
                    .fill(AppConfig.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConfig.radius12, style: .continuous)
                    .strokeBorder(AppConfig.outlineVariant.opacity(0.5), lineWidth: 0.5)
            )
    }
}
