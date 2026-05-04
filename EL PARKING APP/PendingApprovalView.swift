//
//  PendingApprovalView.swift
//  EL PARKING APP
//
//  Shown when a user has registered but is not yet activated by an admin.
//

import SwiftUI

struct PendingApprovalView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var pulse = false
    @ObservedObject private var lang = LanguageManager.shared

    private var isRejected: Bool {
        authManager.currentUser?.isRejected == true
    }
    private var rejectionReason: String? {
        authManager.currentUser?.rejectionReason
    }

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.055)
                .ignoresSafeArea()

            RadialGradient(
                colors: [(isRejected ? AppConfig.spotOccupied : AppConfig.accent).opacity(0.08), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated icon
                ZStack {
                    Circle()
                        .fill((isRejected ? AppConfig.spotOccupied : AppConfig.accent).opacity(0.08))
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                            value: pulse
                        )
                    Circle()
                        .fill((isRejected ? AppConfig.spotOccupied : AppConfig.accent).opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: isRejected ? "xmark.circle" : "clock.badge.checkmark")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(isRejected ? AppConfig.spotOccupied : AppConfig.accentFg)
                }
                .onAppear { pulse = true }

                // Text
                VStack(spacing: 12) {
                    Text(isRejected ? L10n.accountRejected : L10n.accountPending)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(isRejected ? L10n.accountRejectedMsg : L10n.accountPendingMsg)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineSpacing(4)
                }

                // Info card
                VStack(alignment: .leading, spacing: 14) {
                    infoRow(icon: "envelope.fill", text: authManager.currentUser?.email ?? "")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(icon: "person.fill",   text: authManager.currentUser?.displayName ?? "")
                    if isRejected, let reason = rejectionReason, !reason.isEmpty {
                        Divider().background(Color.white.opacity(0.1))
                        infoRow(icon: "text.bubble.fill",
                                text: "\(L10n.rejectedReasonLabel) \(reason)",
                                accent: AppConfig.spotOccupied)
                    } else if !isRejected {
                        Divider().background(Color.white.opacity(0.1))
                        infoRow(icon: "info.circle.fill", text: L10n.contactITAdmin)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                // Sign out button
                Button { authManager.signOut() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(L10n.signOut).fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 28).padding(.vertical, 13)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())

                Text(AppConfig.companyName)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.bottom, 32)
            }
        }
    }

    private func infoRow(icon: String, text: String, accent: Color = AppConfig.accentFg) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accent.opacity(0.8))
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PendingApprovalView()
        .environmentObject(AuthManager())
}
