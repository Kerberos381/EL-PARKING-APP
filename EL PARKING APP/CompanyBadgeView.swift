//
//  CompanyBadgeView.swift
//  EL PARKING APP
//
//  Branded company seal + name. Used in admin user rows/detail and on
//  parking spot cells to mark group-reserved spots (GrandVision policy).
//

import SwiftUI

struct CompanyBadgeView: View {
    let badge: CompanyBadge
    var compact: Bool = false
    /// Seal only — used on spot cells where two badges must fit side by side.
    var iconOnly: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            ZStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: compact ? 18 : 22, weight: .black))
                    .foregroundStyle(brandGradient)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: compact ? 7 : 9, weight: .black))
                            .foregroundStyle(.white)
                    )
                Circle()
                    .fill(brandAccent.opacity(0.95))
                    .frame(width: compact ? 7 : 8, height: compact ? 7 : 8)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.95), lineWidth: 1)
                    )
                    .offset(x: compact ? 6 : 8, y: compact ? 6 : 8)
            }

            if !iconOnly {
                Text(brandName)
                    .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
        }
    }

    private var brandName: String {
        switch badge {
        case .omega: return "Omega"
        case .essilorLuxottica: return "EssilorLuxottica"
        case .grandVision: return "Grand Vision"
        case .none: return L10n.noneLabel
        }
    }

    private var brandSymbol: String {
        switch badge {
        case .omega: return "water.waves"
        case .essilorLuxottica: return "sparkles"
        case .grandVision: return "eye.fill"
        case .none: return "questionmark"
        }
    }

    private var textColor: Color {
        switch badge {
        case .omega: return Color(red: 0.08, green: 0.22, blue: 0.55)
        case .essilorLuxottica:
            return colorScheme == .dark ? .white : .black
        case .grandVision:
            return colorScheme == .dark ? .white : Color(red: 0.44, green: 0.07, blue: 0.12)
        case .none: return AppConfig.subtleGray
        }
    }

    private var brandAccent: Color {
        switch badge {
        case .omega: return Color(red: 0.10, green: 0.36, blue: 0.86)
        case .essilorLuxottica: return .black
        case .grandVision: return Color(red: 0.90, green: 0.17, blue: 0.24)
        case .none: return AppConfig.subtleGray
        }
    }

    private var brandGradient: LinearGradient {
        switch badge {
        case .omega:
            return LinearGradient(colors: [
                Color(red: 0.26, green: 0.50, blue: 0.95),
                Color(red: 0.11, green: 0.30, blue: 0.76)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .essilorLuxottica:
            return LinearGradient(colors: [.black, Color(white: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .grandVision:
            return LinearGradient(colors: [
                Color(red: 0.90, green: 0.17, blue: 0.24),
                Color(red: 0.20, green: 0.34, blue: 0.84)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .none:
            return LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
