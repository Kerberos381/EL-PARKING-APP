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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppConfig.darkText)
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
        .overlay(
            RoundedRectangle(cornerRadius: AppConfig.radius16)
                .stroke(AppConfig.separatorSoft, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
    }
}
