import SwiftUI

struct UserAvatarView: View {
    let user: AppUser
    var size: CGFloat = 40
    var showStroke: Bool = false

    private var initials: String {
        let parts = user.displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(AppConfig.surfaceHigh)

            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(AppConfig.darkText)
        }
        .frame(width: size, height: size)
        .overlay {
            if showStroke {
                Circle()
                    .strokeBorder(AppConfig.outlineVariant, lineWidth: 1.5)
            }
        }
    }
}
