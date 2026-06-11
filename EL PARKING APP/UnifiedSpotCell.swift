//
//  UnifiedSpotCell.swift
//  EL PARKING APP
//
//  Shared spot cell used in both OverviewView and BookingSheet.
//  Two modes: .full (tall 3:4 for overview) and .compact (shorter for booking picker).
//

import SwiftUI

enum SpotCellMode {
    case full      // Overview: tall 3:4 aspect, large number, status icons
    case compact   // Booking picker: shorter, still same visual language
}

enum SpotCellStatus: Equatable {
    case available
    case occupied(name: String?, plate: String?)  // name for everyone, plate for admins
    case partial(name: String?, plate: String?, ranges: String?)
    case mine
    case blocked
    case selected                                  // booking picker: user selected this spot
}

struct UnifiedSpotCell: View {
    let spot: ParkingSpot
    let status: SpotCellStatus
    let mode: SpotCellMode
    /// Ownership badges (company seals) shown when the spot belongs to a
    /// different group than the viewer — see AppConfig.spotGroupBadges.
    var spotGroupBadges: [CompanyBadge] = []
    var isFavourite: Bool = false
    var onFavouriteTap: (() -> Void)? = nil
    let onTap: () -> Void

    @State private var selectionScale: CGFloat = 1.0

    private var isDisabled: Bool {
        if case .blocked = status { return true }
        if case .occupied = status, mode == .compact { return true }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(bgColor)
                    .overlay(borderOverlay)

                // Accessibility watermark — giant ghost icon, barely visible
                if spot.isAccessible && mode == .full {
                    Image(systemName: "figure.roll")
                        .font(.system(size: 110, weight: .black))
                        .foregroundStyle(accessibilityWatermarkColor)
                        .offset(y: -4)
                }

                switch mode {
                case .full:
                    fullLayout
                case .compact:
                    compactLayout
                }
            }
            .frame(maxWidth: .infinity)
            .modifier(AspectModifier(mode: mode))
            .opacity(cellOpacity)
            .scaleEffect(selectionScale)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .onChange(of: status) { _, newStatus in
            if case .selected = newStatus {
                selectionScale = 1.0
                withAnimation(.quick) {
                    selectionScale = 1.08
                }
                withAnimation(.standard.delay(0.14)) {
                    selectionScale = 1.0
                }
            }
        }
    }

    // MARK: - Full Layout (Overview)

    private var fullLayout: some View {
        VStack(spacing: 6) {
            // Top row: status icon left, star favourite right
            HStack {
                topIcon
                if !spotGroupBadges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(spotGroupBadges, id: \.rawValue) { badge in
                            CompanyBadgeView(
                                badge: badge,
                                compact: true,
                                iconOnly: spotGroupBadges.count > 1
                            )
                        }
                    }
                    .accessibilityLabel(
                        spotGroupBadges.map(\.displayName).joined(separator: ", ") + " spot"
                    )
                }
                Spacer()
                if let tap = onFavouriteTap {
                    Button(action: tap) {
                        Image(systemName: isFavourite ? "star.fill" : "star")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(isFavourite
                                ? Color.yellow
                                : (isMineOrSelected
                                    ? AppConfig.onAccent.opacity(0.45)
                                    : AppConfig.subtleGray.opacity(0.45)))
                            .symbolEffect(.bounce, value: isFavourite)
                            .background {
                                StarBurstView(isActive: isFavourite)
                            }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .frame(height: 30)

            Spacer()

            // Spot number
            Text(spot.id)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(numberColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            // Status label
            statusLabel

            Spacer()

            // Bottom action
            bottomAction
        }
    }

    // MARK: - Compact Layout (Booking Picker)

    private var compactLayout: some View {
        ZStack {
            // Accessibility watermark — ghost icon behind content
            if spot.isAccessible {
                Image(systemName: "figure.roll")
                    .font(.system(size: 55, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            VStack(spacing: 4) {
                // Top icon (smaller)
                topIconCompact

                if !spotGroupBadges.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(spotGroupBadges, id: \.rawValue) { badge in
                            CompanyBadgeView(badge: badge, compact: true, iconOnly: true)
                                .scaleEffect(0.8)
                        }
                    }
                    .accessibilityLabel(
                        spotGroupBadges.map(\.displayName).joined(separator: ", ") + " spot"
                    )
                }

                // Spot number
                Text(spot.id)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(numberColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                // Status label
                statusLabelCompact
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Top Icons

    @ViewBuilder
    private var topIcon: some View {
        switch status {
        case .mine:
            EmptyView()
        case .selected:
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundStyle(AppConfig.onAccent)
        case .blocked:
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(AppConfig.subtleGray)
        case .occupied:
            EmptyView()
        case .partial:
            EmptyView()
        case .available:
            EmptyView()
        }
    }

    @ViewBuilder
    private var topIconCompact: some View {
        switch status {
        case .selected:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppConfig.onAccent)
        case .occupied:
            EmptyView().frame(height: 0)
        case .partial:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.55))
        case .blocked:
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
        default:
            EmptyView().frame(height: 0)
        }
    }

    // MARK: - Status Labels

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .mine:
            Text("YOURS")
                .font(.caption2.weight(.bold))
                .tracking(2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.9))
        case .selected:
            Text("SELECTED")
                .font(.caption2.weight(.bold))
                .tracking(2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.9))
        case .occupied(let name, _):
            VStack(spacing: 2) {
                Text(formattedSpotUserName(name))
                    .font(.system(size: name != nil ? 11 : 10, weight: .semibold))
                    .tracking(name != nil ? 0 : 1)
                    .foregroundStyle(AppConfig.darkText.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
        case .partial(let name, _, let ranges):
            VStack(spacing: 2) {
                Text("PARTIAL")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.75))
                if let ranges, !ranges.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(ranges)
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let split = splitSpotUserName(name)
                    Text(split.givenNames)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let surname = split.surname {
                        Text(surname)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                } else if ranges == nil || ranges?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                    Text("Booked")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.65))
                }
            }
        case .blocked:
            Text("BLOCKED")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
        case .available:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusLabelCompact: some View {
        switch status {
        case .selected:
            Text("SELECTED")
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.9))
        case .mine:
            Text("YOU")
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.9))
        case .occupied(let name, _):
            Text(formattedSpotUserName(name))
                .font(.system(size: name != nil ? 9 : 8, weight: .semibold))
                .tracking(name != nil ? 0 : 1)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        case .partial:
            Text("PARTIAL")
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
        case .blocked:
            Text("BLOCKED")
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
        default:
            EmptyView()
        }
    }

    /// Formats full name for narrow spot cards:
    /// line 1 = given name(s), line 2 = surname.
    private func formattedSpotUserName(_ name: String?) -> String {
        guard let name else { return "TAKEN" }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "TAKEN" }

        let parts = trimmed.split(whereSeparator: \.isWhitespace)
        guard parts.count > 1 else { return trimmed }

        let surname = String(parts.last!)
        let givenNames = parts.dropLast().joined(separator: " ")
        return "\(givenNames)\n\(surname)"
    }

    private func splitSpotUserName(_ name: String) -> (givenNames: String, surname: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(whereSeparator: \.isWhitespace)
        guard parts.count > 1 else { return (trimmed, nil) }

        let surname = String(parts.last!)
        let givenNames = parts.dropLast().joined(separator: " ")
        return (givenNames, surname)
    }

    private var isMine: Bool {
        if case .mine = status { return true }
        return false
    }

    private var isMineOrSelected: Bool {
        if case .mine = status { return true }
        if case .selected = status { return true }
        return false
    }

    // MARK: - Bottom Action (Full mode only)

    @ViewBuilder
    private var bottomAction: some View {
        if case .available = status {
            HStack {
                Spacer()
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppConfig.onAccent)
                    .frame(width: 32, height: 32)
                    .background(AppConfig.accent)
                    .clipShape(Circle())
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        } else {
            Spacer().frame(height: 12)
        }
    }

    // MARK: - Accessibility Badge

    /// Filled circle badge with wheelchair icon — scales for full vs compact mode.
    private func accessibilityBadge(size: CGFloat, iconSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(accessibilityBgColor)
            Image(systemName: "figure.roll")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(accessibilityFgColor)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var compactAccessibilityBadge: some View {
        accessibilityBadge(size: 16, iconSize: 8)
    }

    /// Giant ghost watermark — light grey, barely there
    private var accessibilityWatermarkColor: Color {
        Color.gray.opacity(0.07)
    }

    private var accessibilityBgColor: Color {
        switch status {
        case .mine, .selected: return AppConfig.onAccent.opacity(0.2)
        case .blocked:         return Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.15)
        default:               return Color(red: 0.2, green: 0.55, blue: 1.0)
        }
    }

    private var accessibilityFgColor: Color {
        switch status {
        case .mine, .selected: return AppConfig.onAccent.opacity(0.85)
        case .blocked:         return Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.5)
        default:               return .white
        }
    }

    private var accessibilityCompactDisabledFgColor: Color {
        switch status {
        case .blocked:
            return AppConfig.subtleGray.opacity(0.65)
        default:
            return AppConfig.darkText.opacity(0.45)
        }
    }

    // MARK: - Colors

    private var bgColor: Color {
        switch status {
        case .available:  return AppConfig.cardBg
        case .occupied:   return AppConfig.surfaceHigh
        case .partial:    return AppConfig.surfaceLow
        case .mine:       return mode == .full ? AppConfig.surfaceLow : AppConfig.accent.opacity(0.28)
        case .blocked:    return AppConfig.surfaceHigh
        case .selected:   return mode == .full ? AppConfig.surfaceHigh : AppConfig.accent.opacity(0.28)
        }
    }

    private var numberColor: Color {
        switch status {
        case .available:  return AppConfig.darkText
        case .occupied:   return AppConfig.darkText.opacity(0.6)
        case .partial:    return AppConfig.darkText.opacity(0.7)
        case .mine:       return AppConfig.darkText
        case .blocked:    return AppConfig.subtleGray.opacity(0.5)
        case .selected:   return AppConfig.darkText
        }
    }

    private var cellOpacity: Double {
        switch status {
        case .occupied: return mode == .compact ? 0.55 : 1.0
        case .partial:  return 1.0
        case .blocked:  return 0.4
        default:        return 1.0
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if case .available = status {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppConfig.separatorSoft, lineWidth: 1)
        } else if case .partial = status {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppConfig.warning.opacity(0.95), lineWidth: 2)
        } else if case .mine = status, mode == .full {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppConfig.separatorSoft, lineWidth: 1)
        } else if case .selected = status, mode == .full {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppConfig.separatorStrong, lineWidth: 1.5)
        }
    }
}

// MARK: - Aspect Modifier

private struct AspectModifier: ViewModifier {
    let mode: SpotCellMode

    func body(content: Content) -> some View {
        switch mode {
        case .full:
            content.aspectRatio(3.0/4.0, contentMode: .fit)
        case .compact:
            content.frame(height: 80)
        }
    }
}

// MARK: - Star Burst

/// One-shot radial burst of 6 dots fired when a spot is favorited.
struct StarBurstView: View {
    let isActive: Bool

    @State private var burst = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6.0 * 2 * .pi
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 3.5, height: 3.5)
                    .offset(
                        x: burst ? cos(angle) * 16 : 0,
                        y: burst ? sin(angle) * 16 : 0
                    )
                    .opacity(burst ? 0 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, nowFavourite in
            guard nowFavourite, !reduceMotion else { return }
            burst = false
            withAnimation(.easeOut(duration: 0.45)) { burst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { burst = false }
        }
    }
}
