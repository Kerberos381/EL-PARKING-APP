//
//  UserAvatarView.swift
//  EL PARKING APP
//
//  Reusable initials avatar. Color is derived from the user's role.
//

import SwiftUI

struct UserAvatarView: View {
    let user: AppUser
    var size: CGFloat = 44
    var showStroke: Bool = false

    private var initials: String {
        let parts = user.displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(user.displayName.prefix(2)).uppercased()
    }

    private var monogramBackground: Color {
        // Keep monograms subtle and deterministic to avoid accent overuse.
        let palette: [UIColor] = [
            .secondarySystemFill,
            .tertiarySystemFill,
            UIColor.systemBlue.withAlphaComponent(0.12),
            UIColor.systemGreen.withAlphaComponent(0.12),
            UIColor.systemOrange.withAlphaComponent(0.12),
            UIColor.systemIndigo.withAlphaComponent(0.12)
        ]
        let seed = abs(user.email.lowercased().hashValue)
        return Color(uiColor: palette[seed % palette.count])
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(monogramBackground)
                .frame(width: size, height: size)
            Circle()
                .stroke(Color(uiColor: .quaternaryLabel), lineWidth: showStroke ? 1.5 : 1)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.33, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}
