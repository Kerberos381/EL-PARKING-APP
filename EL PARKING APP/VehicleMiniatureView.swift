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

struct VehicleMiniaturePreset: Identifiable, Hashable {
    let id: String
    let title: String
    let searchDescription: String
    let matchTokens: [String]

    static let all: [VehicleMiniaturePreset] = [
        .init(id: "volvo_ex30_yellow", title: "Volvo EX30 · Moss Yellow", searchDescription: "Volvo EX30 Moss Yellow", matchTokens: ["volvo ex30 moss yellow"]),
        .init(id: "volvo_ex30_black", title: "Volvo EX30 · Black", searchDescription: "Volvo EX30 Black", matchTokens: ["volvo ex30 black"]),
        .init(id: "volvo_ex30_white", title: "Volvo EX30 · White", searchDescription: "Volvo EX30 White", matchTokens: ["volvo ex30 white"]),
        .init(id: "volvo_ex30_gray", title: "Volvo EX30 · Gray", searchDescription: "Volvo EX30 Gray", matchTokens: ["volvo ex30 gray", "volvo ex30 grey"]),
        .init(id: "volvo_ex30_blue", title: "Volvo EX30 · Blue", searchDescription: "Volvo EX30 Blue", matchTokens: ["volvo ex30 blue"]),

        .init(id: "tesla_model3_white", title: "Tesla Model 3 · White", searchDescription: "Tesla Model 3 White", matchTokens: ["tesla model 3 white", "model 3 white"]),
        .init(id: "tesla_model3_red", title: "Tesla Model 3 · Red", searchDescription: "Tesla Model 3 Red", matchTokens: ["tesla model 3 red", "model 3 red"]),
        .init(id: "tesla_model3_black", title: "Tesla Model 3 · Black", searchDescription: "Tesla Model 3 Black", matchTokens: ["tesla model 3 black", "model 3 black"]),
        .init(id: "tesla_model3_blue", title: "Tesla Model 3 · Blue", searchDescription: "Tesla Model 3 Blue", matchTokens: ["tesla model 3 blue", "model 3 blue"]),
        .init(id: "tesla_model3_gray", title: "Tesla Model 3 · Gray", searchDescription: "Tesla Model 3 Gray", matchTokens: ["tesla model 3 gray", "tesla model 3 grey", "model 3 gray", "model 3 grey"]),

        .init(id: "octavia_rs_dragon", title: "Škoda Octavia RS · Dragon Green", searchDescription: "Skoda Octavia RS Dragon Green", matchTokens: ["octavia rs dragon", "octavia rs dragon green", "octavia rs dragon skin"]),
        .init(id: "octavia_rs_white", title: "Škoda Octavia RS · White", searchDescription: "Skoda Octavia RS White", matchTokens: ["octavia rs white"]),
        .init(id: "octavia_rs_gray", title: "Škoda Octavia RS · Gray", searchDescription: "Skoda Octavia RS Gray", matchTokens: ["octavia rs gray", "octavia rs grey"]),

        .init(id: "octavia_combi_mamba", title: "Škoda Octavia Combi RS · Mamba", searchDescription: "Skoda Octavia Combi RS Mamba Green", matchTokens: ["octavia combi rs mamba", "octavia combi rs dragon"]),
        .init(id: "octavia_combi_white", title: "Škoda Octavia Combi · White", searchDescription: "Skoda Octavia Combi White", matchTokens: ["octavia combi white"]),
        .init(id: "octavia_combi_gray", title: "Škoda Octavia Combi · Gray", searchDescription: "Skoda Octavia Combi Gray", matchTokens: ["octavia combi gray", "octavia combi grey"]),

        .init(id: "skoda_superb_white", title: "Škoda Superb · White", searchDescription: "Skoda Superb White", matchTokens: ["superb white"]),
        .init(id: "skoda_superb_gray", title: "Škoda Superb · Gray", searchDescription: "Skoda Superb Gray", matchTokens: ["superb gray", "superb grey"]),
        .init(id: "skoda_superb_green", title: "Škoda Superb · Green", searchDescription: "Skoda Superb Green", matchTokens: ["superb green"]),

        .init(id: "skoda_kodiaq", title: "Škoda Kodiaq", searchDescription: "Skoda Kodiaq", matchTokens: ["kodiaq"]),
        .init(id: "skoda_kodiaq_white", title: "Škoda Kodiaq · White", searchDescription: "Skoda Kodiaq White", matchTokens: ["kodiaq white", "skoda kodiaq white"]),
        .init(id: "skoda_kodiaq_gray", title: "Škoda Kodiaq · Gray", searchDescription: "Skoda Kodiaq Gray", matchTokens: ["kodiaq gray", "kodiaq grey", "skoda kodiaq gray", "skoda kodiaq grey"]),
        .init(id: "skoda_kodiaq_black", title: "Škoda Kodiaq · Black", searchDescription: "Skoda Kodiaq Black", matchTokens: ["kodiaq black", "skoda kodiaq black"]),
        .init(id: "tesla_model_y", title: "Tesla Model Y", searchDescription: "Tesla Model Y", matchTokens: ["model y", "tesla model y"]),
        .init(id: "tesla_model_y_white", title: "Tesla Model Y · White", searchDescription: "Tesla Model Y White", matchTokens: ["model y white", "tesla model y white"]),
        .init(id: "tesla_model_y_black", title: "Tesla Model Y · Black", searchDescription: "Tesla Model Y Black", matchTokens: ["model y black", "tesla model y black"]),
        .init(id: "tesla_model_y_gray", title: "Tesla Model Y · Gray", searchDescription: "Tesla Model Y Gray", matchTokens: ["model y gray", "model y grey", "tesla model y gray", "tesla model y grey"]),
        .init(id: "bmw_3", title: "BMW 3 Series", searchDescription: "BMW 3 Series", matchTokens: ["bmw 3", "3 series", "320", "330", "m340"]),
        .init(id: "mini_countryman", title: "MINI Countryman", searchDescription: "MINI Countryman", matchTokens: ["countryman", "mini countryman"]),
        .init(id: "mini_countryman_green_electric", title: "MINI Countryman Electric · Green", searchDescription: "MINI Countryman Electric Green", matchTokens: ["mini countryman electric green", "countryman electric green", "countryman ev green", "mini countryman green electric"]),
        .init(id: "mini_countryman_white", title: "MINI Countryman · White", searchDescription: "MINI Countryman White", matchTokens: ["countryman white", "mini countryman white"]),
        .init(id: "mini_countryman_black", title: "MINI Countryman · Black", searchDescription: "MINI Countryman Black", matchTokens: ["countryman black", "mini countryman black"]),
        .init(id: "subaru_outback", title: "Subaru Outback", searchDescription: "Subaru Outback", matchTokens: ["subaru outback", "outback"]),
        .init(id: "ford_focus", title: "Ford Focus", searchDescription: "Ford Focus", matchTokens: ["ford focus", "focus"]),
        .init(id: "hyundai_bayon", title: "Hyundai Bayon", searchDescription: "Hyundai Bayon", matchTokens: ["hyundai bayon", "bayon"])
    ]

    static var pickerOptions: [VehicleMiniaturePreset] {
        var seenAssets = Set<String>()
        return all.filter { preset in
            guard let assetName = VehicleMiniatureAsset.assetName(forPresetID: preset.id) else {
                return true
            }
            guard VehicleMiniatureAsset.imageExists(assetName) else {
                return false
            }
            guard !seenAssets.contains(assetName) else {
                return false
            }
            seenAssets.insert(assetName)
            return true
        }
    }

    static func matching(description: String, carType: String = "") -> VehicleMiniaturePreset? {
        let text = "\(carType) \(description)".vehicleSearchText
        if let exact = all.first(where: { $0.searchDescription.vehicleSearchText == text }) {
            return exact
        }
        return all.first { preset in
            preset.matchTokens.contains { text.contains($0.vehicleSearchText) }
        }
    }
}

struct VehicleMiniaturePresetPickerSheet: View {
    let title: String
    let selectedColorHex: String
    let selectedPresetID: String?
    let onSelect: (VehicleMiniaturePreset) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(VehicleMiniaturePreset.pickerOptions) { preset in
                    Button {
                        Haptics.selection()
                        onSelect(preset)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VehicleMiniatureView(
                                carType: "",
                                colorHex: selectedColorHex,
                                description: preset.searchDescription
                            )
                            .frame(width: 70, height: 38)

                            Text(preset.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppConfig.darkText)

                            Spacer()

                            if selectedPresetID == preset.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppConfig.accentFg)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

struct VehicleMiniatureView: View {
    let carType: String
    let colorHex: String
    let description: String

    private var kind: VehicleMiniatureKind {
        VehicleMiniatureKind.resolve(carType: carType, description: description)
    }

    var body: some View {
        Group {
            if let assetName = VehicleMiniatureAsset.resolve(
                carType: carType,
                description: description
            ), let imageName = VehicleMiniatureAsset.availableImageName(for: assetName) {
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
        if let preset = VehicleMiniaturePreset.matching(description: description, carType: carType),
           let presetAssetName = assetName(forPresetID: preset.id) {
            return presetAssetName
        }

        let text = "\(carType) \(description)".vehicleSearchText

        if text.contains("octavia") &&
            text.containsAny(["combi", "kombi", "estate", "wagon"]) &&
            text.containsAny(["rs", "vrs", "r s"]) {
            if text.containsAny(["mamba", "dragon green", "dragon-green", "dragon skin", "dragonskin", "dragon"]) {
                return "vehicle_mini_octavia_combi_green"
            }
            return explicitColorAsset(base: "vehicle_mini_octavia_combi", text: text, defaultSuffix: "white")
        }

        if text.contains("octavia") && text.containsAny(["rs", "vrs", "r s"]) {
            if text.containsAny(["mamba", "dragon green", "dragon-green", "dragon skin", "dragonskin", "dragon"]) {
                return "vehicle_mini_skoda_octavia_rs_dragon_green"
            }
            return explicitColorAsset(base: "vehicle_mini_skoda_octavia_rs", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["countryman", "mini countryman"]) {
            if text.containsAny(["electric", "ev"]) {
                return "vehicle_mini_mini_countryman_green"
            }
            return explicitColorAsset(base: "vehicle_mini_mini_countryman", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["bmw 3", "3 series", "320", "330", "m340"]) {
            return explicitColorAsset(base: "vehicle_mini_bmw_3", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["volvo ex30", "volvo ex 30", "ex30", "ex 30"]) {
            return explicitColorAsset(base: "vehicle_mini_volvo_ex30_moss_yellow", text: text, defaultSuffix: "yellow")
        }
        if text.containsAny(["tesla model y", "model y", "modely"]) {
            return explicitColorAsset(base: "vehicle_mini_tesla_model_y", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["tesla model 3", "tesla 3", "model 3", "model3", "tesla"]) {
            return explicitColorAsset(base: "vehicle_mini_tesla_model3", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["ford focus", "focus"]) {
            return explicitColorAsset(base: "vehicle_mini_ford_focus", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["subaru outback", "outback"]) {
            return explicitColorAsset(base: "vehicle_mini_subaru_outback", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["kia ev9", "ev9", "ev 9"]) {
            return explicitColorAsset(base: "vehicle_mini_kia_ev9", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["skoda kodiaq", "kodiaq"]) {
            return explicitColorAsset(base: "vehicle_mini_skoda_kodiaq", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["hyundai bayon", "bayon"]) {
            return explicitColorAsset(base: "vehicle_mini_hyundai_bayon", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["hyundai kona", "kona electric", "kona", "kia niro", "niro ev", "niro"]) {
            return explicitColorAsset(base: "vehicle_mini_hyundai_kona_electric", text: text, defaultSuffix: "white")
        }
        if text.contains("superb") {
            return explicitColorAsset(base: "vehicle_mini_superb", text: text, defaultSuffix: "white")
        }
        if text.contains("octavia") && text.containsAny(["combi", "kombi", "estate", "wagon"]) {
            return explicitColorAsset(base: "vehicle_mini_octavia_combi", text: text, defaultSuffix: "white")
        }
        if text.contains("octavia") {
            return explicitColorAsset(base: "vehicle_mini_skoda_octavia_rs", text: text, defaultSuffix: "white")
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

    static func availableImageName(for assetName: String) -> String? {
        if imageExists(assetName) {
            return assetName
        }

        if let baseName = baseAssetName(removingColorSuffixFrom: assetName),
           imageExists(baseName) {
            return baseName
        }

        return nil
    }

    static func imageExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        imageCacheLock.lock()
        if let cached = imageExistsCache[name] {
            imageCacheLock.unlock()
            return cached
        }
        imageCacheLock.unlock()

        let exists = UIImage(named: name) != nil

        imageCacheLock.lock()
        imageExistsCache[name] = exists
        imageCacheLock.unlock()
        return exists
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

    static func assetName(forPresetID id: String) -> String? {
        switch id {
        case "volvo_ex30_yellow": return "vehicle_mini_volvo_ex30_moss_yellow_yellow"
        case "volvo_ex30_black": return "vehicle_mini_volvo_ex30_moss_yellow_black"
        case "volvo_ex30_white": return "vehicle_mini_volvo_ex30_moss_yellow_white"
        case "volvo_ex30_gray": return "vehicle_mini_volvo_ex30_moss_yellow_gray"
        case "volvo_ex30_blue": return "vehicle_mini_volvo_ex30_moss_yellow_blue"

        case "tesla_model3_white": return "vehicle_mini_tesla_model3_white"
        case "tesla_model3_red": return "vehicle_mini_tesla_model3_red"
        case "tesla_model3_black": return "vehicle_mini_tesla_model3_black"
        case "tesla_model3_blue": return "vehicle_mini_tesla_model3_blue"
        case "tesla_model3_gray": return "vehicle_mini_tesla_model3_gray"

        case "octavia_rs_dragon": return "vehicle_mini_skoda_octavia_rs_dragon_green"
        case "octavia_rs_white": return "vehicle_mini_skoda_octavia_rs_white"
        case "octavia_rs_gray": return "vehicle_mini_skoda_octavia_rs_gray"

        case "octavia_combi_mamba": return "vehicle_mini_octavia_combi_green"
        case "octavia_combi_white": return "vehicle_mini_octavia_combi_white"
        case "octavia_combi_gray": return "vehicle_mini_octavia_combi_gray"

        case "skoda_superb_white": return "vehicle_mini_superb_white"
        case "skoda_superb_gray": return "vehicle_mini_superb_gray"
        case "skoda_superb_green": return "vehicle_mini_superb_green"

        case "skoda_kodiaq": return "vehicle_mini_skoda_kodiaq"
        case "skoda_kodiaq_white": return "vehicle_mini_skoda_kodiaq_white"
        case "skoda_kodiaq_gray": return "vehicle_mini_skoda_kodiaq_gray"
        case "skoda_kodiaq_black": return "vehicle_mini_skoda_kodiaq_black"

        case "tesla_model_y": return "vehicle_mini_tesla_model_y"
        case "tesla_model_y_white": return "vehicle_mini_tesla_model_y_white"
        case "tesla_model_y_black": return "vehicle_mini_tesla_model_y_black"
        case "tesla_model_y_gray": return "vehicle_mini_tesla_model_y_gray"

        case "bmw_3": return "vehicle_mini_bmw_3"
        case "bmw_3_white": return "vehicle_mini_bmw_3_white"
        case "bmw_3_black": return "vehicle_mini_bmw_3_black"

        case "mini_countryman": return "vehicle_mini_mini_countryman"
        case "mini_countryman_white": return "vehicle_mini_mini_countryman_white"
        case "mini_countryman_black": return "vehicle_mini_mini_countryman_black"
        case "mini_countryman_green_electric": return "vehicle_mini_mini_countryman_green"

        case "subaru_outback": return "vehicle_mini_subaru_outback"
        case "subaru_outback_white": return "vehicle_mini_subaru_outback_white"
        case "ford_focus": return "vehicle_mini_ford_focus"
        case "ford_focus_white": return "vehicle_mini_ford_focus_white"
        case "hyundai_bayon": return "vehicle_mini_hyundai_bayon"
        default: return nil
        }
    }

    private static func explicitColorAsset(base: String, text: String, defaultSuffix: String) -> String {
        if let suffix = preferredColorSuffix(in: text) {
            return "\(base)_\(suffix)"
        }
        if imageExists(base) {
            return base
        }
        return "\(base)_\(defaultSuffix)"
    }

    private static func preferredColorSuffix(in text: String) -> String? {
        if text.containsAny(["dragon skin", "dragon-green", "dragon green", "mamba"]) {
            return "green"
        }
        if text.contains("white") { return "white" }
        if text.containsAny(["grey", "gray"]) { return "gray" }
        if text.contains("black") { return "black" }
        if text.contains("red") { return "red" }
        if text.containsAny(["navy", "dark blue"]) { return "navy" }
        if text.contains("blue") { return "blue" }
        if text.contains("green") { return "green" }
        if text.contains("yellow") { return "yellow" }
        if text.contains("orange") { return "orange" }
        if text.containsAny(["brown", "beige"]) { return "brown" }
        if text.containsAny(["silver", "metallic"]) { return "silver" }
        return nil
    }

    private static func baseAssetName(removingColorSuffixFrom assetName: String) -> String? {
        for suffix in colorSuffixes where assetName.hasSuffix(suffix) {
            return String(assetName.dropLast(suffix.count))
        }
        return nil
    }

    private static let colorSuffixes = [
        "_white", "_silver", "_gray", "_black", "_red", "_bordeaux",
        "_blue", "_navy", "_green", "_yellow", "_orange", "_brown"
    ]

    private static let imageCacheLock = NSLock()
    private static var imageExistsCache: [String: Bool] = [:]
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
