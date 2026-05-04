//
//  WhatsNewView.swift
//  EL PARKING APP
//
//  Modal sheet displayed once per version after a significant update.
//

import SwiftUI

struct WhatsNewView: View {

    let release: AppRelease
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared
    @State private var visibleFeatures: Set<String> = []

    private var featureCountLabel: String {
        let n = release.features.count
        if LanguageManager.shared.language == .czech {
            return n == 1 ? "1 nová funkce" : "\(n) nové funkce"
        } else {
            return n == 1 ? "1 new feature" : "\(n) new features"
        }
    }

    // Map color keys from AppReleaseNotes to actual swatches
    private func iconBg(_ key: String) -> Color {
        switch key {
        case "green":  return Color(red: 0.20, green: 0.65, blue: 0.40)
        case "orange": return Color(red: 0.90, green: 0.55, blue: 0.15)
        case "red":    return Color(red: 0.85, green: 0.25, blue: 0.25)
        case "blue":   return Color(red: 0.25, green: 0.50, blue: 0.90)
        default:       return AppConfig.accent
        }
    }

    var body: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────────
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppConfig.accent.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "sparkles")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(AppConfig.accentFg)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 8) {
                        Text(L10n.whatsNew)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(AppConfig.darkText)
                        HStack(spacing: 10) {
                            Text("v\(release.version)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppConfig.accentFg)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppConfig.accent.opacity(0.15))
                                .clipShape(Capsule())

                            HStack(spacing: 5) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10, weight: .bold))
                                Text(featureCountLabel)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(AppConfig.subtleGray)
                        }

                        // Progress dots — one per feature
                        if release.features.count > 1 {
                            HStack(spacing: 5) {
                                ForEach(Array(release.features.enumerated()), id: \.offset) { idx, f in
                                    Capsule()
                                        .fill(visibleFeatures.contains(f.title)
                                              ? AppConfig.accentFg
                                              : AppConfig.subtleGray.opacity(0.25))
                                        .frame(width: visibleFeatures.contains(f.title) ? 14 : 6,
                                               height: 4)
                                        .animation(.emphasis, value: visibleFeatures)
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
                .padding(.bottom, 32)

                // ── Feature List ─────────────────────────────────────────────
                VStack(spacing: 26) {
                    ForEach(Array(release.features.enumerated()), id: \.element.title) { idx, feature in
                        featureRow(feature)
                            .opacity(visibleFeatures.contains(feature.title) ? 1 : 0)
                            .scaleEffect(visibleFeatures.contains(feature.title) ? 1 : 0.94)
                            .offset(y: visibleFeatures.contains(feature.title) ? 0 : 10)
                            .onAppear {
                                withAnimation(.emphasis
                                    .delay(Double(idx) * 0.06)) {
                                    _ = visibleFeatures.insert(feature.title)
                                }
                            }
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 32)

                // ── Continue Button ──────────────────────────────────────────
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Text(L10n.continueBtn)
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(AppConfig.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(AppConfig.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(_ feature: ReleaseFeature) -> some View {
        HStack(alignment: .top, spacing: 18) {
            // Icon
            Image(systemName: feature.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(iconBg(feature.color))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: iconBg(feature.color).opacity(0.35), radius: 6, y: 3)

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppConfig.darkText)
                Text(feature.description)
                    .font(.system(size: 14))
                    .foregroundStyle(AppConfig.subtleGray)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview {
    WhatsNewView(release: AppRelease(
        version: "1.1",
        features: [
            ReleaseFeature(icon: "bell.badge.fill", color: "accent",
                           title: "Custom Reminders",
                           description: "Pick exactly how far ahead you're notified."),
            ReleaseFeature(icon: "faceid", color: "accent",
                           title: "Smarter Face ID",
                           description: "No re-lock on quick app switches."),
            ReleaseFeature(icon: "wifi.slash", color: "blue",
                           title: "Offline Parking Grid",
                           description: "Spots load from cache when offline."),
        ]
    ))
}
