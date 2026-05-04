//
//  VehicleMiniatureView.swift
//  EL PARKING APP
//
//  Offline vehicle miniatures with model-inspired assets and drawn fallbacks.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct VehicleMiniatureView: View {
    let carType: String
    let colorHex: String
    let description: String

    private var kind: VehicleMiniatureKind {
        VehicleMiniatureKind.resolve(carType: carType, description: description)
    }

    private var paintColor: Color {
        guard let normalizedPaintHex else { return AppConfig.subtleGray }
        return Color(hex: normalizedPaintHex)
    }

    private var normalizedPaintHex: String? {
        let trimmed = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard raw.count == 6, raw.allSatisfy(\.isHexDigit) else { return nil }
        return "#\(raw.uppercased())"
    }

    var body: some View {
        Group {
            if let assetName = VehicleMiniatureAsset.resolve(
                carType: carType,
                description: description
            ), let imageName = VehicleMiniatureAsset.availableImageName(for: assetName, colorHex: normalizedPaintHex) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else if let genericAssetName = VehicleMiniatureAsset.genericName(for: kind),
                      VehicleMiniatureAsset.imageExists(genericAssetName) {
                Image(genericAssetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: kind == .motorcycle ? "scooter" : "car.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppConfig.subtleGray)
                    .padding(.horizontal, 6)
            }
        }
        .aspectRatio(1.8, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private enum VehicleMiniatureAsset {
    static func resolve(carType: String, description: String) -> String? {
        let text = "\(carType) \(description)".vehicleSearchText

        if text.contains("octavia") && text.containsAny(["rs", "vrs", "r s"]) {
            if text.containsAny(["dragon green", "dragon-green", "dragon"]) {
                return "vehicle_mini_skoda_octavia_rs_dragon_green"
            }
            return "vehicle_mini_skoda_octavia_rs"
        }
        if text.containsAny(["countryman", "mini countryman"]) {
            return "vehicle_mini_mini_countryman"
        }
        if text.containsAny(["bmw 3", "3 series", "320", "330", "m340"]) {
            return "vehicle_mini_bmw_3"
        }
        if text.containsAny(["volvo ex30", "volvo ex 30", "ex30", "ex 30"]) {
            return "vehicle_mini_volvo_ex30_moss_yellow"
        }
        if text.containsAny(["tesla model y", "model y", "modely"]) {
            return "vehicle_mini_tesla_model_y"
        }
        if text.containsAny(["tesla model 3", "tesla 3", "model 3", "model3", "tesla"]) {
            return "vehicle_mini_tesla_model3"
        }
        if text.containsAny(["ford focus", "focus"]) {
            return "vehicle_mini_ford_focus"
        }
        if text.containsAny(["subaru outback", "outback"]) {
            return "vehicle_mini_subaru_outback"
        }
        if text.containsAny(["kia ev9", "ev9", "ev 9"]) {
            return "vehicle_mini_kia_ev9"
        }
        if text.containsAny(["skoda kodiaq", "kodiaq"]) {
            return "vehicle_mini_skoda_kodiaq"
        }
        if text.containsAny(["hyundai bayon", "bayon"]) {
            return "vehicle_mini_hyundai_bayon"
        }
        if text.containsAny(["hyundai kona", "kona electric", "kona", "kia niro", "niro ev", "niro"]) {
            return "vehicle_mini_hyundai_kona_electric"
        }
        if text.contains("superb") {
            return "vehicle_mini_superb"
        }
        if text.contains("octavia") && text.containsAny(["combi", "kombi", "estate", "wagon"]) {
            return "vehicle_mini_octavia_combi"
        }
        if text.contains("octavia") {
            return "vehicle_mini_superb_sedan"
        }
        if text.contains("fabia") {
            return "vehicle_mini_fabia_hatch"
        }
        if text.containsAny(["golf", "id.3", "id3"]) {
            return "vehicle_mini_golf_hatch"
        }
        if text.containsAny(["transporter", "multivan", "vito", "sprinter", "transit", "dodavka", "van"]) {
            return "vehicle_mini_van"
        }
        if text.containsAny(["touareg", "xc60", "x5", "gle"]) {
            return "vehicle_mini_large_suv"
        }
        if text.containsAny(["karoq", "kamiq", "tiguan", "t-roc", "qashqai", "xc40", "x1", "x3", "tucson", "sportage"]) {
            return "vehicle_mini_compact_suv"
        }
        if text.containsAny(["enyaq", "id.4", "id4", "electric", "elektro"]) {
            return "vehicle_mini_electric_crossover"
        }
        return nil
    }

    static func variantName(for assetName: String, colorHex: String?) -> String {
        guard supportsPaletteVariants(assetName) else { return assetName }
        guard let suffix = colorVariantSuffix(for: colorHex) else { return assetName }
        return "\(assetName)_\(suffix)"
    }

    static func availableImageName(for assetName: String, colorHex: String?) -> String? {
        let variant = variantName(for: assetName, colorHex: colorHex)
        if imageExists(variant) { return variant }
        if imageExists(assetName) { return assetName }
        return nil
    }

    static func imageExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name) != nil
        #else
        true
        #endif
    }

    static func genericName(for kind: VehicleMiniatureKind) -> String? {
        switch kind {
        case .hatchback:
            return "vehicle_mini_generic_hatchback_white"
        case .sedan:
            return "vehicle_mini_generic_sedan_white"
        case .combi:
            return "vehicle_mini_generic_estate_white"
        case .suv:
            return "vehicle_mini_generic_suv_white"
        case .coupe:
            return "vehicle_mini_generic_coupe_white"
        case .cabriolet:
            return "vehicle_mini_generic_convertible_white"
        case .pickup:
            return "vehicle_mini_generic_pickup_white"
        case .van:
            return "vehicle_mini_generic_van_white"
        case .bus:
            return "vehicle_mini_generic_bus_white"
        case .motorcycle:
            return "vehicle_mini_generic_motorcycle_white"
        case .electric:
            return "vehicle_mini_generic_electric_white"
        case .other:
            return "vehicle_mini_generic_other_white"
        }
    }

    private static func supportsPaletteVariants(_ assetName: String) -> Bool {
        !assetName.hasPrefix("vehicle_mini_generic_") &&
        assetName != "vehicle_mini_skoda_octavia_rs_dragon_green"
    }

    private static func colorVariantSuffix(for colorHex: String?) -> String? {
        guard
            let rawColorHex = colorHex,
            let rgb = rgbComponents(from: rawColorHex)
        else {
            return nil
        }

        return colorVariants.min { lhs, rhs in
            lhs.distanceSquared(to: rgb) < rhs.distanceSquared(to: rgb)
        }?.suffix
    }

    private static func rgbComponents(from colorHex: String) -> (red: Int, green: Int, blue: Int)? {
        let trimmed = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard raw.count == 6, let value = Int(raw, radix: 16) else { return nil }
        return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
    }

    private static let colorVariants: [ColorVariant] = [
        ColorVariant(suffix: "white", red: 255, green: 255, blue: 255),
        ColorVariant(suffix: "silver", red: 192, green: 192, blue: 192),
        ColorVariant(suffix: "gray", red: 128, green: 128, blue: 128),
        ColorVariant(suffix: "black", red: 17, green: 17, blue: 17),
        ColorVariant(suffix: "red", red: 204, green: 51, blue: 51),
        ColorVariant(suffix: "bordeaux", red: 125, green: 17, blue: 40),
        ColorVariant(suffix: "blue", red: 26, green: 115, blue: 232),
        ColorVariant(suffix: "navy", red: 0, green: 48, blue: 135),
        ColorVariant(suffix: "green", red: 24, green: 128, blue: 56),
        ColorVariant(suffix: "yellow", red: 249, green: 168, blue: 37),
        ColorVariant(suffix: "orange", red: 232, green: 113, blue: 10),
        ColorVariant(suffix: "brown", red: 121, green: 85, blue: 72)
    ]

    private struct ColorVariant {
        let suffix: String
        let red: Int
        let green: Int
        let blue: Int

        func distanceSquared(to rgb: (red: Int, green: Int, blue: Int)) -> Int {
            let redDelta = red - rgb.red
            let greenDelta = green - rgb.green
            let blueDelta = blue - rgb.blue
            return redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta
        }
    }
}

private enum VehicleMiniatureKind {
    case hatchback
    case sedan
    case combi
    case suv
    case coupe
    case cabriolet
    case pickup
    case van
    case bus
    case motorcycle
    case electric
    case other

    static func resolve(carType: String, description: String) -> VehicleMiniatureKind {
        let text = "\(carType) \(description)".vehicleSearchText

        if text.containsAny(["motorcycle", "motorka", "moto", "skutr", "scooter"]) { return .motorcycle }
        if text.containsAny(["pickup", "pick up", "ranger", "hilux"]) { return .pickup }
        if text.containsAny(["bus", "minibus"]) { return .bus }
        if text.containsAny(["dodavka", "van", "transporter", "multivan", "vito", "sprinter", "transit", "mpv"]) { return .van }
        if text.containsAny(["cabrio", "cabriolet", "convertible"]) { return .cabriolet }
        if text.containsAny(["coupe", "coup"]) { return .coupe }
        if text.containsAny(["combi", "kombi", "estate", "wagon", "variant", "touring"]) { return .combi }
        if text.containsAny(["suv", "crossover", "kamiq", "karoq", "kodiaq", "enyaq", "ex30", "xc40", "xc60", "rav4", "tucson", "sportage", "tiguan", "t-roc", "qashqai", "q3", "q5", "x1", "x3", "x5", "glc", "gle", "id.4", "id4"]) { return .suv }
        if text.containsAny(["sedan", "saloon", "limousine", "octavia", "superb", "passat", "mondeo", "camry", "a4", "a6", "serie 3", "3 series", "c-class", "e-class"]) { return .sedan }
        if text.containsAny(["hatchback", "hatch", "fabia", "scala", "golf", "polo", "focus", "i30", "ceed", "yaris", "corolla", "id.3", "id3"]) { return .hatchback }
        if text.contains("electric") || text.contains("elektro") { return .electric }

        switch carType.vehicleSearchText {
        case "hatchback": return .hatchback
        case "sedan": return .sedan
        case "combi", "estate", "wagon": return .combi
        case "suv": return .suv
        case "coupe": return .coupe
        case "cabriolet", "convertible": return .cabriolet
        case "pickup": return .pickup
        case "van": return .van
        case "bus": return .bus
        case "motorcycle": return .motorcycle
        case "electric": return .electric
        default: return .other
        }
    }
}

private func drawCar(in context: inout GraphicsContext, size: CGSize, kind: VehicleMiniatureKind, paint: Color) {
    let w = size.width
    let h = size.height
    let wheelRadius = h * (kind == .bus ? 0.12 : 0.14)
    let wheelY = h * 0.78
    let lineWidth = max(1, h * 0.025)

    let shadow = CGRect(x: w * 0.13, y: h * 0.80, width: w * 0.74, height: h * 0.12)
    context.fill(Path(ellipseIn: shadow), with: .color(Color.black.opacity(0.10)))

    var body = Path()
    switch kind {
    case .van, .bus:
        body = Path(roundedRect: CGRect(x: w * 0.08, y: h * 0.27, width: w * 0.84, height: h * 0.46),
                    cornerRadius: h * (kind == .bus ? 0.06 : 0.10))
    case .pickup:
        body.move(to: CGPoint(x: w * 0.09, y: h * 0.70))
        body.addLine(to: CGPoint(x: w * 0.09, y: h * 0.58))
        body.addQuadCurve(to: CGPoint(x: w * 0.32, y: h * 0.46), control: CGPoint(x: w * 0.17, y: h * 0.50))
        body.addLine(to: CGPoint(x: w * 0.52, y: h * 0.46))
        body.addLine(to: CGPoint(x: w * 0.62, y: h * 0.58))
        body.addLine(to: CGPoint(x: w * 0.91, y: h * 0.58))
        body.addLine(to: CGPoint(x: w * 0.91, y: h * 0.70))
        body.closeSubpath()
    case .cabriolet:
        body.move(to: CGPoint(x: w * 0.10, y: h * 0.69))
        body.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.56), control: CGPoint(x: w * 0.12, y: h * 0.57))
        body.addLine(to: CGPoint(x: w * 0.50, y: h * 0.52))
        body.addLine(to: CGPoint(x: w * 0.68, y: h * 0.58))
        body.addQuadCurve(to: CGPoint(x: w * 0.91, y: h * 0.68), control: CGPoint(x: w * 0.82, y: h * 0.56))
        body.closeSubpath()
    default:
        let roof = roofPoints(for: kind, width: w, height: h)
        body.move(to: CGPoint(x: w * 0.08, y: h * 0.69))
        body.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.55), control: CGPoint(x: w * 0.08, y: h * 0.57))
        body.addLine(to: roof.front)
        body.addQuadCurve(to: roof.topFront, control: CGPoint(x: roof.front.x + w * 0.02, y: roof.front.y - h * 0.09))
        body.addLine(to: roof.topRear)
        body.addQuadCurve(to: roof.rear, control: CGPoint(x: roof.topRear.x + w * 0.07, y: roof.topRear.y + h * 0.03))
        body.addLine(to: CGPoint(x: w * 0.91, y: h * 0.58))
        body.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.69), control: CGPoint(x: w * 0.94, y: h * 0.62))
        body.closeSubpath()
    }

    context.fill(body, with: .color(paint))
    context.stroke(body, with: .color(Color.black.opacity(0.16)), lineWidth: lineWidth)

    drawWindows(in: &context, size: size, kind: kind)

    if kind == .electric {
        let bolt = Path { path in
            path.move(to: CGPoint(x: w * 0.53, y: h * 0.51))
            path.addLine(to: CGPoint(x: w * 0.47, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.49, y: h * 0.73))
        }
        context.stroke(bolt, with: .color(Color.white.opacity(0.90)), lineWidth: max(1.4, h * 0.055))
    }

    drawWheel(in: &context, center: CGPoint(x: w * 0.27, y: wheelY), radius: wheelRadius)
    drawWheel(in: &context, center: CGPoint(x: w * 0.73, y: wheelY), radius: wheelRadius)
}

private func drawWindows(in context: inout GraphicsContext, size: CGSize, kind: VehicleMiniatureKind) {
    let w = size.width
    let h = size.height
    let glass = Color.white.opacity(0.50)

    switch kind {
    case .van:
        context.fill(Path(roundedRect: CGRect(x: w * 0.24, y: h * 0.35, width: w * 0.46, height: h * 0.18), cornerRadius: h * 0.035), with: .color(glass))
    case .bus:
        context.fill(Path(roundedRect: CGRect(x: w * 0.18, y: h * 0.34, width: w * 0.62, height: h * 0.17), cornerRadius: h * 0.025), with: .color(glass))
        for x in stride(from: w * 0.34, through: w * 0.66, by: w * 0.16) {
            var divider = Path()
            divider.move(to: CGPoint(x: x, y: h * 0.35))
            divider.addLine(to: CGPoint(x: x, y: h * 0.50))
            context.stroke(divider, with: .color(Color.black.opacity(0.12)), lineWidth: max(0.8, h * 0.014))
        }
    case .pickup:
        context.fill(Path(roundedRect: CGRect(x: w * 0.31, y: h * 0.49, width: w * 0.19, height: h * 0.13), cornerRadius: h * 0.025), with: .color(glass))
    case .cabriolet:
        var windshield = Path()
        windshield.move(to: CGPoint(x: w * 0.44, y: h * 0.51))
        windshield.addLine(to: CGPoint(x: w * 0.50, y: h * 0.37))
        context.stroke(windshield, with: .color(glass), lineWidth: max(1.4, h * 0.045))
    default:
        let windowPath = roofWindowPath(for: kind, width: w, height: h)
        context.fill(windowPath, with: .color(glass))
    }
}

private func drawMotorcycle(in context: inout GraphicsContext, size: CGSize, paint: Color) {
    let w = size.width
    let h = size.height
    let wheelRadius = h * 0.17
    let wheelY = h * 0.74
    let stroke = StrokeStyle(lineWidth: max(1.6, h * 0.055), lineCap: .round, lineJoin: .round)

    drawWheel(in: &context, center: CGPoint(x: w * 0.25, y: wheelY), radius: wheelRadius)
    drawWheel(in: &context, center: CGPoint(x: w * 0.74, y: wheelY), radius: wheelRadius)

    var frame = Path()
    frame.move(to: CGPoint(x: w * 0.25, y: wheelY))
    frame.addLine(to: CGPoint(x: w * 0.43, y: h * 0.52))
    frame.addLine(to: CGPoint(x: w * 0.58, y: wheelY))
    frame.addLine(to: CGPoint(x: w * 0.74, y: wheelY))
    frame.addLine(to: CGPoint(x: w * 0.60, y: h * 0.48))
    frame.addLine(to: CGPoint(x: w * 0.43, y: h * 0.52))
    context.stroke(frame, with: .color(paint), style: stroke)

    var handle = Path()
    handle.move(to: CGPoint(x: w * 0.60, y: h * 0.48))
    handle.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.36), control: CGPoint(x: w * 0.68, y: h * 0.44))
    context.stroke(handle, with: .color(paint), style: stroke)

    var seat = Path()
    seat.move(to: CGPoint(x: w * 0.38, y: h * 0.45))
    seat.addLine(to: CGPoint(x: w * 0.53, y: h * 0.43))
    context.stroke(seat, with: .color(Color.black.opacity(0.55)), style: StrokeStyle(lineWidth: max(1.6, h * 0.065), lineCap: .round))
}

private func drawWheel(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
    context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(Color.black.opacity(0.82)))
    context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.42, y: center.y - radius * 0.42, width: radius * 0.84, height: radius * 0.84)), with: .color(Color.white.opacity(0.45)))
}

private func roofPoints(for kind: VehicleMiniatureKind, width w: CGFloat, height h: CGFloat) -> (front: CGPoint, topFront: CGPoint, topRear: CGPoint, rear: CGPoint) {
    switch kind {
    case .suv:
        return (CGPoint(x: w * 0.28, y: h * 0.55), CGPoint(x: w * 0.38, y: h * 0.30), CGPoint(x: w * 0.68, y: h * 0.31), CGPoint(x: w * 0.82, y: h * 0.55))
    case .combi:
        return (CGPoint(x: w * 0.27, y: h * 0.54), CGPoint(x: w * 0.38, y: h * 0.33), CGPoint(x: w * 0.70, y: h * 0.34), CGPoint(x: w * 0.83, y: h * 0.55))
    case .coupe:
        return (CGPoint(x: w * 0.30, y: h * 0.55), CGPoint(x: w * 0.43, y: h * 0.34), CGPoint(x: w * 0.62, y: h * 0.36), CGPoint(x: w * 0.76, y: h * 0.57))
    case .hatchback:
        return (CGPoint(x: w * 0.26, y: h * 0.55), CGPoint(x: w * 0.37, y: h * 0.34), CGPoint(x: w * 0.60, y: h * 0.34), CGPoint(x: w * 0.72, y: h * 0.57))
    default:
        return (CGPoint(x: w * 0.26, y: h * 0.55), CGPoint(x: w * 0.38, y: h * 0.34), CGPoint(x: w * 0.62, y: h * 0.34), CGPoint(x: w * 0.77, y: h * 0.57))
    }
}

private func roofWindowPath(for kind: VehicleMiniatureKind, width w: CGFloat, height h: CGFloat) -> Path {
    let roof = roofPoints(for: kind, width: w, height: h)
    var path = Path()
    path.move(to: CGPoint(x: roof.front.x + w * 0.035, y: roof.front.y - h * 0.03))
    path.addLine(to: CGPoint(x: roof.topFront.x + w * 0.03, y: roof.topFront.y + h * 0.035))
    path.addLine(to: CGPoint(x: roof.topRear.x - w * 0.035, y: roof.topRear.y + h * 0.035))
    path.addLine(to: CGPoint(x: roof.rear.x - w * 0.035, y: roof.rear.y - h * 0.03))
    path.closeSubpath()
    return path
}

private extension String {
    var vehicleSearchText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "cs_CZ"))
            .lowercased()
    }

    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}
