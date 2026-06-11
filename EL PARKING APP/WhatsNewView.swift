//
//  WhatsNewView.swift
//  EL PARKING APP
//
//  Modal sheet displayed once per version after a significant update.
//  Follows the standard Apple "What's New" template: large centered title,
//  plain accent-tinted feature rows, single Continue button.
//

import SwiftUI

struct WhatsNewView: View {

    let release: AppRelease
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text(L10n.whatsNew)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppConfig.darkText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 64)

                    Text("\(L10n.versionLabel) \(release.version)")
                        .font(.footnote)
                        .foregroundStyle(AppConfig.subtleGray)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(release.features, id: \.title) { feature in
                            FeatureListRow(
                                icon: feature.icon,
                                title: feature.title,
                                description: feature.description
                            )
                        }
                    }
                    .padding(.top, 44)
                    .padding(.horizontal, 36)
                }
            }

            Button {
                dismiss()
            } label: {
                Text(L10n.continueBtn)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppConfig.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppConfig.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(AppConfig.pageBg.ignoresSafeArea())
    }
}

// MARK: - Feature Row (shared with OnboardingView)

/// Apple-template feature row: accent SF Symbol, semibold title,
/// secondary description. No fills, shadows, or per-row coloring.
struct FeatureListRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(AppConfig.accentFg)
                .frame(width: 40)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppConfig.subtleGray)
                    .fixedSize(horizontal: false, vertical: true)
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
