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

    var pickerDisplayTitle: String {
        let parts = title.split(separator: "·", maxSplits: 1, omittingEmptySubsequences: true)
        if let first = parts.first {
            return String(first).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title
    }

    static let all: [VehicleMiniaturePreset] = [
        .init(id: "volvo_ex30_yellow", title: "Volvo EX30 · Moss Yellow", searchDescription: "Volvo EX30 Moss Yellow", matchTokens: ["volvo ex30 moss yellow"]),
        .init(id: "volvo_ex30_gray", title: "Volvo EX30 · Gray", searchDescription: "Volvo EX30 Gray", matchTokens: ["volvo ex30 gray", "volvo ex30 grey"]),

        .init(id: "tesla_model3_white", title: "Tesla Model 3 · White", searchDescription: "Tesla Model 3 White", matchTokens: ["tesla model 3 white", "model 3 white"]),
        .init(id: "tesla_model3_red", title: "Tesla Model 3 · Red", searchDescription: "Tesla Model 3 Red", matchTokens: ["tesla model 3 red", "model 3 red"]),
        .init(id: "tesla_model3_black", title: "Tesla Model 3 · Black", searchDescription: "Tesla Model 3 Black", matchTokens: ["tesla model 3 black", "model 3 black"]),
        .init(id: "tesla_model3_blue", title: "Tesla Model 3 · Blue", searchDescription: "Tesla Model 3 Blue", matchTokens: ["tesla model 3 blue", "model 3 blue"]),
        .init(id: "tesla_model3_gray", title: "Tesla Model 3 · Gray", searchDescription: "Tesla Model 3 Gray", matchTokens: ["tesla model 3 gray", "tesla model 3 grey", "model 3 gray", "model 3 grey"]),

        .init(id: "octavia_rs", title: "Škoda Octavia RS", searchDescription: "Skoda Octavia RS", matchTokens: ["skoda octavia rs", "octavia rs"]),
        .init(id: "octavia_rs_dragon", title: "Škoda Octavia RS · Dragon Green", searchDescription: "Skoda Octavia RS Dragon Green", matchTokens: ["octavia rs dragon", "octavia rs dragon green", "octavia rs dragon skin", "octavia rs dragon skin green"]),
        .init(id: "octavia_rs_white", title: "Škoda Octavia RS · White", searchDescription: "Skoda Octavia RS White", matchTokens: ["octavia rs white"]),
        .init(id: "octavia_rs_gray", title: "Škoda Octavia RS · Gray", searchDescription: "Skoda Octavia RS Gray", matchTokens: ["octavia rs gray", "octavia rs grey"]),

        .init(id: "octavia_combi_mamba", title: "Škoda Octavia Combi RS · Mamba", searchDescription: "Skoda Octavia Combi RS Mamba Green", matchTokens: ["octavia combi rs mamba", "octavia combi rs dragon"]),
        .init(id: "octavia_combi_white", title: "Škoda Octavia Combi · White", searchDescription: "Skoda Octavia Combi White", matchTokens: ["octavia combi white"]),
        .init(id: "octavia_combi_gray", title: "Škoda Octavia Combi · Gray", searchDescription: "Skoda Octavia Combi Gray", matchTokens: ["octavia combi gray", "octavia combi grey"]),

        .init(id: "skoda_superb_white", title: "Škoda Superb · White", searchDescription: "Skoda Superb White", matchTokens: ["superb white"]),
        .init(id: "skoda_superb_gray", title: "Škoda Superb · Gray", searchDescription: "Skoda Superb Gray", matchTokens: ["superb gray", "superb grey"]),
        .init(id: "skoda_superb_green", title: "Škoda Superb · Green", searchDescription: "Skoda Superb Green", matchTokens: ["superb green"]),
        .init(id: "skoda_superb_combi_lk", title: "Škoda Superb Combi L&K", searchDescription: "Skoda Superb Combi L&K", matchTokens: ["skoda superb combi", "superb combi", "superb l&k", "superb lk", "superb estate"]),

        .init(id: "skoda_kodiaq", title: "Škoda Kodiaq", searchDescription: "Skoda Kodiaq", matchTokens: ["kodiaq"]),
        .init(id: "skoda_kodiaq_white", title: "Škoda Kodiaq · White", searchDescription: "Skoda Kodiaq White", matchTokens: ["kodiaq white", "skoda kodiaq white"]),
        .init(id: "skoda_kodiaq_gray", title: "Škoda Kodiaq · Gray", searchDescription: "Skoda Kodiaq Gray", matchTokens: ["kodiaq gray", "kodiaq grey", "skoda kodiaq gray", "skoda kodiaq grey"]),
        .init(id: "skoda_kodiaq_black", title: "Škoda Kodiaq · Black", searchDescription: "Skoda Kodiaq Black", matchTokens: ["kodiaq black", "skoda kodiaq black"]),
        .init(id: "skoda_karoq_style", title: "Škoda Karoq Style", searchDescription: "Skoda Karoq Style", matchTokens: ["skoda karoq", "karoq style", "karoq"]),

        .init(id: "mercedes_eqa_250", title: "Mercedes EQA 250", searchDescription: "Mercedes EQA 250", matchTokens: ["mercedes eqa", "mercedes eqa 250", "eqa", "eqa 250"]),
        .init(id: "mercedes_c220d_4matic", title: "Mercedes C 220 d 4MATIC", searchDescription: "Mercedes C 220 d 4MATIC", matchTokens: ["mercedes c class", "mercedes c 220", "c220d", "c220 d", "4matic"]),
        .init(id: "bmw_i4", title: "BMW i4", searchDescription: "BMW i4", matchTokens: ["bmw i4", "i4"]),
        .init(id: "audi_q4", title: "Audi Q4", searchDescription: "Audi Q4", matchTokens: ["audi q4", "q4 e tron", "q4 etron", "q4"]),
        .init(id: "audi_a4_avant_b9", title: "Audi A4 Avant B9", searchDescription: "Audi A4 Avant B9", matchTokens: ["audi a4", "a4 avant", "a4 b9", "avant b9"]),
        .init(id: "alfa_romeo_stelvio", title: "Alfa Romeo Stelvio", searchDescription: "Alfa Romeo Stelvio", matchTokens: ["alfa romeo stelvio", "stelvio"]),
        .init(id: "vw_tiguan", title: "Volkswagen Tiguan", searchDescription: "Volkswagen Tiguan", matchTokens: ["volkswagen tiguan", "vw tiguan", "tiguan"]),
        .init(id: "vw_golf_variant", title: "Volkswagen Golf Variant", searchDescription: "Volkswagen Golf Variant", matchTokens: ["volkswagen golf variant", "vw golf variant", "golf variant"]),
        .init(id: "octavia_combi_style", title: "Škoda Octavia Combi Style", searchDescription: "Skoda Octavia Combi Style", matchTokens: ["skoda octavia combi", "octavia combi style", "octavia estate", "octavia sw"]),

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

    static func pickerOptions(make: String = "", model: String = "") -> [VehicleMiniaturePreset] {
        let available = availablePickerOptions
        let makeText = make.vehicleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelText = model.vehicleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !makeText.isEmpty else {
            return available
        }

        let makeOnly = available.filter { preset in
            presetPickerSearchText(for: preset).contains(makeText)
        }
        guard !makeOnly.isEmpty else { return [] }

        guard !modelText.isEmpty else {
            return makeOnly
        }

        let modelNarrowed = makeOnly.filter { preset in
            presetPickerSearchText(for: preset).contains(modelText)
        }
        return modelNarrowed.isEmpty ? makeOnly : modelNarrowed
    }

    private static let availablePickerOptions: [VehicleMiniaturePreset] = {
        var seenVisualSignatures = Set<String>()
        return all.filter { preset in
            guard let assetName = VehicleMiniatureAsset.assetName(forPresetID: preset.id) else {
                return true
            }
            guard VehicleMiniatureAsset.imageExists(assetName) else {
                return false
            }
            let signature = VehicleMiniatureAsset.visualSignature(forAssetName: assetName) ?? "asset:\(assetName)"
            guard !seenVisualSignatures.contains(signature) else {
                return false
            }
            seenVisualSignatures.insert(signature)
            return true
        }
    }()

    private static func presetPickerSearchText(for preset: VehicleMiniaturePreset) -> String {
        "\(preset.title) \(preset.searchDescription) \(preset.matchTokens.joined(separator: " "))".vehicleSearchText
    }

    static func matching(description: String, carType: String = "") -> VehicleMiniaturePreset? {
        let text = "\(carType) \(description)".vehicleSearchText
        if let exact = all.first(where: { $0.searchDescription.vehicleSearchText == text }) {
            return exact
        }
        let matches = all.compactMap { preset -> (VehicleMiniaturePreset, Int)? in
            let score = preset.matchTokens
                .map { $0.vehicleSearchText }
                .filter { text.contains($0) }
                .map(\.count)
                .max() ?? 0
            guard score > 0 else { return nil }
            return (preset, score)
        }
        return matches.max(by: { lhs, rhs in lhs.1 < rhs.1 })?.0
    }
}

struct VehicleMiniaturePresetPickerSheet: View {
    let title: String
    let selectedColorHex: String
    let selectedPresetID: String?
    let selectedMake: String
    let selectedModel: String
    let onSelect: (VehicleMiniaturePreset) -> Void

    @Environment(\.dismiss) private var dismiss

    private var options: [VehicleMiniaturePreset] {
        VehicleMiniaturePreset.pickerOptions(make: selectedMake, model: selectedModel)
    }

    private var optionIDs: [String] {
        options.map { $0.id }
    }

    private struct PreparedOption: Identifiable {
        let preset: VehicleMiniaturePreset
        let make: String?
        var id: String { preset.id }
    }

    private var preparedOptions: [PreparedOption] {
        options.map { preset in
            let parsed = CarData.splitMakeModel(preset.searchDescription).make
            return PreparedOption(preset: preset, make: parsed.isEmpty ? nil : parsed)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if options.isEmpty {
                    ContentUnavailableView(
                        "No Icons For This Make",
                        systemImage: "car.rear.and.tire.marks",
                        description: Text("Add a preset for \(selectedMake).")
                    )
                } else {
                    List {
                        ForEach(preparedOptions) { option in
                            Button {
                                Haptics.selection()
                                onSelect(option.preset)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    VehicleMiniatureView(
                                        carType: "",
                                        colorHex: selectedColorHex,
                                        description: option.preset.searchDescription,
                                        presetID: option.preset.id
                                    )
                                    .frame(width: 110, height: 62)

                                    if let presetMake = option.make {
                                        CarMakerLogoBadge(make: presetMake, size: 20)
                                    }

                                    Text(option.preset.pickerDisplayTitle)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppConfig.darkText)
                                        .lineLimit(1)
                                    Spacer()
                                    if selectedPresetID == option.preset.id {
                                        Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppConfig.accentFg)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                VehicleMiniatureAsset.prewarmPickerPresetAssets(for: optionIDs)
            }
            .onChange(of: optionIDs) { _, ids in
                VehicleMiniatureAsset.prewarmPickerPresetAssets(for: ids)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct VehicleMiniatureView: View {
    let carType: String
    let colorHex: String
    let description: String
    var presetID: String? = nil
    var useFastRendering: Bool = false

    private var kind: VehicleMiniatureKind {
        VehicleMiniatureKind.resolve(carType: carType, description: description)
    }

    var body: some View {
        Group {
            if let presetID,
               let presetAssetName = VehicleMiniatureAsset.assetName(forPresetID: presetID),
               let imageName = VehicleMiniatureAsset.availableImageName(for: presetAssetName) {
                vehicleAssetImage(imageName)
            } else if let assetName = VehicleMiniatureAsset.resolve(
                carType: carType,
                description: description
            ), let imageName = VehicleMiniatureAsset.availableImageName(for: assetName) {
                vehicleAssetImage(imageName)
            } else if let genericAssetName = VehicleMiniatureAsset.genericName(for: kind),
                      VehicleMiniatureAsset.imageExists(genericAssetName) {
                vehicleAssetImage(genericAssetName)
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

    @ViewBuilder
    private func vehicleAssetImage(_ name: String) -> some View {
        if useFastRendering {
            Image(name)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
        } else {
            #if canImport(UIKit)
            if let normalized = VehicleMiniatureAsset.normalizedUIImage(named: name) {
                Image(uiImage: normalized)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(name)
                    .resizable()
                    .scaledToFit()
            }
            #else
            Image(name)
                .resizable()
                .scaledToFit()
            #endif
        }
    }

    static func hasSpecificMiniature(carType: String, description: String, presetID: String? = nil) -> Bool {
        if let presetID,
           let presetAssetName = VehicleMiniatureAsset.assetName(forPresetID: presetID),
           VehicleMiniatureAsset.hasSpecificAsset(assetName: presetAssetName) {
            return true
        }

        if let resolvedAsset = VehicleMiniatureAsset.resolve(carType: carType, description: description),
           VehicleMiniatureAsset.hasSpecificAsset(assetName: resolvedAsset) {
            return true
        }

        return false
    }
}

private enum VehicleMiniatureAsset {
    static func prewarmPickerPresetAssets(for presetIDs: [String]) {
        let resolvedNames: [String] = presetIDs.compactMap { presetID in
            guard let name = assetName(forPresetID: presetID) else { return nil }
            return availableImageName(for: name)
        }
        let assetNames = Set<String>(resolvedNames)
        guard !assetNames.isEmpty else { return }

        #if canImport(UIKit)
        prewarmQueue.async {
            for name in assetNames {
                autoreleasepool {
                    _ = normalizedUIImage(named: name)
                }
            }
        }
        #endif
    }

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
            return volvoEX30AssetName(for: text)
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
        if text.containsAny(["mercedes eqa 250", "mercedes eqa", "eqa 250", "eqa"]) {
            return "vehicle_mini_mercedes_eqa_250"
        }
        if text.containsAny(["mercedes c 220 d 4matic", "mercedes c220", "c220d", "c220 d", "c class"]) {
            return "vehicle_mini_mercedes_c220d_4matic"
        }
        if text.containsAny(["bmw i4", "i4"]) {
            return "vehicle_mini_bmw_i4"
        }
        if text.containsAny(["audi q4", "q4 e tron", "q4 etron", "q4"]) {
            return "vehicle_mini_audi_q4"
        }
        if text.containsAny(["volkswagen tiguan", "vw tiguan", "tiguan"]) {
            return "vehicle_mini_vw_tiguan"
        }
        if text.containsAny(["volkswagen golf variant", "vw golf variant", "golf variant"]) {
            return "vehicle_mini_vw_golf_variant"
        }
        if text.containsAny(["audi a4 avant b9", "a4 avant", "audi a4"]) {
            return "vehicle_mini_audi_a4_avant_b9"
        }
        if text.containsAny(["alfa romeo stelvio", "stelvio"]) {
            return "vehicle_mini_alfa_romeo_stelvio"
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
        if text.containsAny(["skoda karoq", "karoq"]) {
            return "vehicle_mini_skoda_karoq_style"
        }
        if text.containsAny(["hyundai bayon", "bayon"]) {
            return explicitColorAsset(base: "vehicle_mini_hyundai_bayon", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["hyundai kona", "kona electric", "kona", "kia niro", "niro ev", "niro"]) {
            return explicitColorAsset(base: "vehicle_mini_hyundai_kona_electric", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["superb combi", "superb estate", "superb lk", "superb l&k"]) {
            return "vehicle_mini_skoda_superb_combi_lk"
        }
        if text.contains("superb") {
            return explicitColorAsset(base: "vehicle_mini_superb", text: text, defaultSuffix: "white")
        }
        if text.containsAny(["octavia combi style", "octavia sw", "octavia estate"]) {
            return "vehicle_mini_skoda_octavia_combi_style"
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

    static func hasSpecificAsset(assetName: String) -> Bool {
        guard imageExists(assetName) else { return false }
        return !assetName.hasPrefix("vehicle_mini_generic_")
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

    #if canImport(UIKit)
    static func visualSignature(forAssetName name: String) -> String? {
        guard let normalized = normalizedUIImage(named: name),
              let data = normalized.pngData() else { return nil }
        return dataFingerprint(data)
    }

    private static func dataFingerprint(_ data: Data) -> String {
        var hash: UInt64 = 1469598103934665603 // FNV offset basis
        let prime: UInt64 = 1099511628211
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(hash, radix: 16)
    }

    static func normalizedUIImage(named name: String) -> UIImage? {
        imageCacheLock.lock()
        if let cached = normalizedImageCache[name] {
            imageCacheLock.unlock()
            return cached
        }
        imageCacheLock.unlock()

        guard let original = UIImage(named: name) else { return nil }
        // Strict fit pipeline: preserve whole miniature image, avoid edge clipping.
        let normalized = normalizedCanvasImage(from: original)

        imageCacheLock.lock()
        normalizedImageCache[name] = normalized
        imageCacheLock.unlock()
        return normalized
    }

    private static func normalizedCanvasImage(from image: UIImage) -> UIImage {
        let canvas = CGSize(width: 540, height: 300) // 1.8 ratio
        let renderer = UIGraphicsImageRenderer(size: canvas)
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return image }

        // Keep small safe margins and always fit whole image.
        let contentRect = CGRect(
            x: canvas.width * 0.06,
            y: canvas.height * 0.08,
            width: canvas.width * 0.88,
            height: canvas.height * 0.84
        )

        let drawScale = min(contentRect.width / sourceSize.width, contentRect.height / sourceSize.height)

        let drawSize = CGSize(width: sourceSize.width * drawScale, height: sourceSize.height * drawScale)
        let drawOrigin = CGPoint(
            x: contentRect.midX - drawSize.width / 2.0,
            y: contentRect.midY - drawSize.height / 2.0
        )

        return renderer.image { _ in
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }
    #endif

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
        case "volvo_ex30_gray": return "vehicle_mini_volvo_ex30_moss_yellow_gray"

        case "tesla_model3_white": return "vehicle_mini_tesla_model3_white"
        case "tesla_model3_red": return "vehicle_mini_tesla_model3_red"
        case "tesla_model3_black": return "vehicle_mini_tesla_model3_black"
        case "tesla_model3_blue": return "vehicle_mini_tesla_model3_blue"
        case "tesla_model3_gray": return "vehicle_mini_tesla_model3_gray"

        case "octavia_rs": return "vehicle_mini_skoda_octavia_rs"
        case "octavia_rs_dragon": return "vehicle_mini_skoda_octavia_rs_dragon_green"
        case "octavia_rs_white": return "vehicle_mini_skoda_octavia_rs_white"
        case "octavia_rs_gray": return "vehicle_mini_skoda_octavia_rs_gray"

        case "octavia_combi_mamba": return "vehicle_mini_octavia_combi_green"
        case "octavia_combi_white": return "vehicle_mini_octavia_combi_white"
        case "octavia_combi_gray": return "vehicle_mini_octavia_combi_gray"

        case "skoda_superb_white": return "vehicle_mini_superb_white"
        case "skoda_superb_gray": return "vehicle_mini_superb_gray"
        case "skoda_superb_green": return "vehicle_mini_superb_green"
        case "skoda_superb_combi_lk": return "vehicle_mini_skoda_superb_combi_lk"

        case "skoda_kodiaq": return "vehicle_mini_skoda_kodiaq"
        case "skoda_kodiaq_white": return "vehicle_mini_skoda_kodiaq_white"
        case "skoda_kodiaq_gray": return "vehicle_mini_skoda_kodiaq_gray"
        case "skoda_kodiaq_black": return "vehicle_mini_skoda_kodiaq_black"
        case "skoda_karoq_style": return "vehicle_mini_skoda_karoq_style"

        case "mercedes_eqa_250": return "vehicle_mini_mercedes_eqa_250"
        case "mercedes_c220d_4matic": return "vehicle_mini_mercedes_c220d_4matic"
        case "bmw_i4": return "vehicle_mini_bmw_i4"
        case "audi_q4": return "vehicle_mini_audi_q4"
        case "audi_a4_avant_b9": return "vehicle_mini_audi_a4_avant_b9"
        case "alfa_romeo_stelvio": return "vehicle_mini_alfa_romeo_stelvio"
        case "vw_tiguan": return "vehicle_mini_vw_tiguan"
        case "vw_golf_variant": return "vehicle_mini_vw_golf_variant"
        case "octavia_combi_style": return "vehicle_mini_skoda_octavia_combi_style"

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

    private static func volvoEX30AssetName(for text: String) -> String {
        if text.containsAny(["gray", "grey", "silver", "seda"]) {
            return "vehicle_mini_volvo_ex30_moss_yellow_gray"
        }
        return "vehicle_mini_volvo_ex30_moss_yellow_yellow"
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
    #if canImport(UIKit)
    private static var normalizedImageCache: [String: UIImage] = [:]
    private static let prewarmQueue = DispatchQueue(label: "vehicle.miniature.prewarm", qos: .utility)
    #endif
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
