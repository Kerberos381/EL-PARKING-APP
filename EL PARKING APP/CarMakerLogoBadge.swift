//
//  CarMakerLogoBadge.swift
//  EL PARKING APP
//
//  Compact brand-style badge for car maker rows.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CarMakerLogoBadge: View {
    let make: String
    var size: CGFloat = 18

    private var canonicalMake: String {
        CarData.canonicalMake(from: make) ?? make.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var initials: String {
        switch canonicalMake {
        case "Škoda": return "Š"
        case "BMW": return "BMW"
        case "MINI": return "MINI"
        case "MG": return "MG"
        case "Kia": return "KIA"
        case "Tesla": return "T"
        case "Audi": return "AUDI"
        case "Volkswagen": return "VW"
        case "Mercedes-Benz": return "MB"
        case "Hyundai": return "H"
        case "Toyota": return "T"
        case "Volvo": return "V"
        case "Ford": return "F"
        case "Subaru": return "S"
        case "Porsche": return "P"
        case "Alfa Romeo": return "AR"
        case "Nissan": return "N"
        case "Peugeot": return "P"
        case "Renault": return "R"
        case "Honda": return "H"
        case "Opel": return "O"
        case "Mazda": return "M"
        case "Citroën": return "C"
        case "Seat": return "S"
        case "Dacia": return "D"
        default:
            let chunks = canonicalMake
                .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
                .map(String.init)
                .filter { !$0.isEmpty }
            if chunks.count >= 2 {
                let first = chunks[0].prefix(1).uppercased()
                let second = chunks[1].prefix(1).uppercased()
                return "\(first)\(second)"
            }
            return String(canonicalMake.prefix(2)).uppercased()
        }
    }

    private var logoAssetName: String? {
        switch canonicalMake {
        case "Škoda": return "car_maker_logo_skoda"
        case "Hyundai": return "car_maker_logo_hyundai"
        case "Toyota": return "car_maker_logo_toyota"
        case "Volkswagen": return "car_maker_logo_volkswagen"
        case "Kia": return "car_maker_logo_kia"
        case "Dacia": return "car_maker_logo_dacia"
        case "Ford": return "car_maker_logo_ford"
        case "Mercedes-Benz": return "car_maker_logo_mercedes_benz"
        case "Renault": return "car_maker_logo_renault"
        case "BMW": return "car_maker_logo_bmw"
        case "Audi": return "car_maker_logo_audi"
        case "Volvo": return "car_maker_logo_volvo"
        case "Tesla": return "car_maker_logo_tesla"
        case "MG": return "car_maker_logo_mg"
        case "Nissan": return "car_maker_logo_nissan"
        case "Peugeot": return "car_maker_logo_peugeot"
        case "MINI": return "car_maker_logo_mini"
        case "Subaru": return "car_maker_logo_subaru"
        case "Porsche": return "car_maker_logo_porsche"
        case "Honda": return "car_maker_logo_honda"
        case "Alfa Romeo": return "car_maker_logo_alfa_romeo"
        case "Opel": return "car_maker_logo_opel"
        case "Mazda": return "car_maker_logo_mazda"
        case "Citroën": return "car_maker_logo_citroen"
        case "Seat": return "car_maker_logo_seat"
        default: return nil
        }
    }

    private var hasLogoAsset: Bool {
        guard let logoAssetName else { return false }
        #if canImport(UIKit)
        return UIImage(named: logoAssetName) != nil
        #else
        return false
        #endif
    }

    var body: some View {
        if let logoAssetName, hasLogoAsset {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    Image(logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.14)
                )
                .frame(width: size * 1.5, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4B5563"), Color(hex: "#6B7280")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(initials)
                    .font(.system(size: max(7, size * 0.40), weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
            )
            .accessibilityHidden(true)
        }
    }
}
