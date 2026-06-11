//
//  UIStateComponents.swift
//  EL PARKING APP
//

import SwiftUI

struct AppEmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var footnote: String? = nil
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        if AppConfig.enableNativeEmptyStates {
            nativeBody
        } else {
            legacyBody
        }
    }

    // MARK: - Native (ContentUnavailableView)

    private var nativeBody: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            if let footnote {
                Text("\(subtitle)\n\(footnote)")
            } else {
                Text(subtitle)
            }
        } actions: {
            if let actionTitle, let action {
                Button {
                    Haptics.action()
                    action()
                } label: {
                    if let actionIcon {
                        Label(actionTitle, systemImage: actionIcon)
                    } else {
                        Text(actionTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppConfig.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Legacy card (kept for easy revert via AppConfig.enableNativeEmptyStates)

    private var legacyBody: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.35))
                .padding(.top, 4)

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppConfig.darkText)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppConfig.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.75))
            }

            if let actionTitle, let action {
                Button {
                    Haptics.action()
                    action()
                } label: {
                    HStack(spacing: 7) {
                        if let actionIcon {
                            Image(systemName: actionIcon)
                                .font(.caption.weight(.bold))
                        }
                        Text(actionTitle)
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(AppConfig.onAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppConfig.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .cardShadow()
    }
}
