//
//  VehicleCatalogStore.swift
//  EL PARKING APP
//
//  Reads the Firebase-hosted vehicle catalog (single source of truth) so new
//  makes/models/colours can be added on the fly without an app update.
//
//  Design (mirrors the web reader):
//   • GAP-FILL ONLY. Bundled assets win. The catalog is consulted only when the
//     in-app resolver can't find a specific bundled miniature, so existing cars
//     are untouched and never hit Firestore.
//   • 1-READ INDEX. All matching metadata is embedded in vehicleCatalogMeta/current
//     (version + entries[] + makers[], no blobs). One getDocument() per launch.
//   • LAZY + CACHED. Index is cached to disk and loaded synchronously on init;
//     refreshed once per session. Image blobs download once per NEW car (bundled
//     image preferred first), then cached to disk + memory.
//   • KILL-SWITCH. enabled == false → store stays inactive, everything falls back.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
@preconcurrency import FirebaseFirestore

@MainActor
final class VehicleCatalogStore: ObservableObject {

    static let shared = VehicleCatalogStore()

    struct Entry: Codable, Hashable {
        let id: String
        let imageId: String
        let matchTokens: [String]
        let make: String?
        let model: String?
        let title: String?
        let searchDescription: String?
    }

    // Bumped whenever the index changes so catalog-backed views re-render.
    @Published private(set) var revision: Int = 0

    private(set) var enabled: Bool = true
    private(set) var version: Int = 0
    private var entries: [Entry] = []                 // tokens pre-normalized
    private var makers: [String: String] = [:]        // normalizedMake -> logoImageId
    private var makerDisplayNames: [String: String] = [:]
    private var modelsByMaker: [String: [String]] = [:]

    var isActive: Bool { enabled && (!entries.isEmpty || !makers.isEmpty) }

    private let db = Firestore.firestore()
    private var didRefresh = false
    private let memoryImages = NSCache<NSString, UIImage>()

    private let cacheDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("VehicleCatalog", isDirectory: true)
    }()
    private var indexFile: URL { cacheDir.appendingPathComponent("index.json") }
    private var imagesDir: URL { cacheDir.appendingPathComponent("images", isDirectory: true) }

    private init() {
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        loadCachedIndex()
    }

    // MARK: - Public API

    /// Fire-and-forget; refreshes the index at most once per session. Safe to call
    /// from any view's onAppear — the read only succeeds once the user is signed in.
    func ensureLoaded() {
        Task { await loadIfNeeded() }
    }

    /// Awaitable variant for deterministic render/export paths such as widgets.
    func loadIfNeeded() async {
        guard !didRefresh else { return }
        didRefresh = true
        await refresh()
    }

    /// Returns a catalog entry whose tokens best match the description, or nil.
    /// Caller should only use this as a fallback when no bundled asset resolved.
    func match(carType: String, description: String) -> Entry? {
        guard isActive else { return nil }
        let text = Self.normalize("\(carType) \(description)")
        guard !text.isEmpty else { return nil }
        var best: Entry?
        var bestLen = 0
        for e in entries {
            for tok in e.matchTokens where tok.count > bestLen && text.contains(tok) {
                best = e
                bestLen = tok.count
            }
        }
        return best
    }

    /// Loads the miniature for an entry: bundled asset first (no network), then
    /// memory, then disk, then a one-time Firestore fetch of the base64 blob.
    func image(for entry: Entry) async -> UIImage? {
        let bundledName = entry.imageId.hasPrefix("vehicle_mini_") ? entry.imageId : "vehicle_mini_\(entry.imageId)"
        return await loadImage(imageId: entry.imageId, bundledName: bundledName)
    }

    /// The hosted logo id for a make, if the catalog has one (gap-fill for makes
    /// not in the bundled set). Returns nil when inactive or unknown.
    func makerLogoId(for make: String) -> String? {
        guard isActive else { return nil }
        return makers[Self.normalize(make)]
    }

    /// Merges bundled makes with Firestore-hosted makes. Bundled names keep their
    /// existing order; hosted additions are appended alphabetically.
    func makes(merging bundledMakes: [String]) -> [String] {
        guard enabled else { return bundledMakes }
        var merged = bundledMakes
        var seen = Set(bundledMakes.map(Self.normalize))

        let hostedMakes = Set(makerDisplayNames.values)
            .union(modelsByMaker.keys.compactMap { makerDisplayNames[$0] })
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for make in hostedMakes {
            let key = Self.normalize(make)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            merged.append(make)
            seen.insert(key)
        }
        return merged.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Merges bundled models with Firestore-hosted models for the selected make.
    func models(for make: String, merging bundledModels: [String]) -> [String] {
        guard enabled else { return bundledModels }
        let key = Self.normalize(make)
        let hostedModels = modelsByMaker[key] ?? []
        var merged = bundledModels
        var seen = Set(bundledModels.map(Self.normalize))

        for model in hostedModels {
            let modelKey = Self.normalize(model)
            guard !modelKey.isEmpty, !seen.contains(modelKey) else { continue }
            merged.append(model)
            seen.insert(modelKey)
        }
        return merged.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Parses a saved vehicle description using hosted maker names. This is a
    /// fallback for cars that are not in the bundled CarData table yet.
    func splitMakeModel(_ full: String) -> (make: String, model: String) {
        guard enabled else { return ("", "") }
        let value = full.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedValue = Self.normalize(value)
        guard !normalizedValue.isEmpty else { return ("", "") }

        let hostedMakes = makerDisplayNames.values.sorted { $0.count > $1.count }
        for make in hostedMakes {
            let normalizedMake = Self.normalize(make)
            if normalizedValue == normalizedMake {
                return (make, "")
            }
            if normalizedValue.hasPrefix("\(normalizedMake) ") {
                let model = String(value.dropFirst(make.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (make, model)
            }
        }
        return ("", "")
    }

    /// Loads a maker logo by its image id (e.g. "maker_cupra"): bundled asset
    /// first, then memory/disk/blob — same path as vehicle miniatures.
    func makerLogoImage(logoImageId: String) async -> UIImage? {
        let slug = logoImageId.hasPrefix("maker_") ? String(logoImageId.dropFirst("maker_".count)) : logoImageId
        return await loadImage(imageId: logoImageId, bundledName: "car_maker_logo_\(slug)")
    }

    /// Shared image pipeline: bundled asset → memory → disk → one-time blob fetch.
    private func loadImage(imageId: String, bundledName: String) async -> UIImage? {
        if let bundled = UIImage(named: bundledName) { return bundled }

        let key = imageId as NSString
        if let cached = memoryImages.object(forKey: key) { return cached }

        let file = imagesDir.appendingPathComponent("\(imageId).png")
        if let data = try? Data(contentsOf: file), let img = UIImage(data: data) {
            memoryImages.setObject(img, forKey: key)
            return img
        }

        do {
            let snap = try await db.collection("vehicleImages").document(imageId).getDocument()
            guard let dataDict = snap.data(),
                  let b64 = dataDict["data"] as? String,
                  let bytes = Data(base64Encoded: b64),
                  let img = UIImage(data: bytes) else { return nil }
            try? bytes.write(to: file)
            memoryImages.setObject(img, forKey: key)
            return img
        } catch {
            return nil
        }
    }

    private func cachedImageExists(imageId: String, bundledName: String) -> Bool {
        if UIImage(named: bundledName) != nil { return true }
        if memoryImages.object(forKey: imageId as NSString) != nil { return true }
        return FileManager.default.fileExists(atPath: imagesDir.appendingPathComponent("\(imageId).png").path)
    }

    /// Warms local storage for hosted-only catalog assets. First install pulls all
    /// hosted additions; later launches/version changes fetch only missing image ids.
    private func prefetchHostedAssets() async {
        guard isActive else { return }

        var requests: [(imageId: String, bundledName: String)] = []
        var seen = Set<String>()

        for entry in entries {
            let bundledName = entry.imageId.hasPrefix("vehicle_mini_") ? entry.imageId : "vehicle_mini_\(entry.imageId)"
            if seen.insert(entry.imageId).inserted,
               !cachedImageExists(imageId: entry.imageId, bundledName: bundledName) {
                requests.append((entry.imageId, bundledName))
            }
        }

        for logoImageId in makers.values {
            let slug = logoImageId.hasPrefix("maker_") ? String(logoImageId.dropFirst("maker_".count)) : logoImageId
            let bundledName = "car_maker_logo_\(slug)"
            if seen.insert(logoImageId).inserted,
               !cachedImageExists(imageId: logoImageId, bundledName: bundledName) {
                requests.append((logoImageId, bundledName))
            }
        }

        for request in requests {
            _ = await loadImage(imageId: request.imageId, bundledName: request.bundledName)
        }
    }

    // MARK: - Index loading

    private func refresh() async {
        do {
            let snap = try await db.collection("vehicleCatalogMeta").document("current").getDocument()
            guard let data = snap.data() else { return }
            let enabledFlag = data["enabled"] as? Bool ?? true
            let newVersion = (data["version"] as? Int) ?? (data["version"] as? NSNumber)?.intValue ?? 0

            if !enabledFlag {
                enabled = false
                version = newVersion
                entries = []
                makers = [:]
                makerDisplayNames = [:]
                modelsByMaker = [:]
                persistIndex()
                revision &+= 1
                return
            }
            enabled = true

            let entriesRaw = data["entries"] as? [[String: Any]] ?? []
            let makersRaw = data["makers"] as? [[String: Any]] ?? []

            version = newVersion
            applyIndex(entriesRaw: entriesRaw, makersRaw: makersRaw)
            persistIndex()
            revision &+= 1
            await prefetchHostedAssets()
            revision &+= 1
        } catch {
            // Offline / not yet signed in → keep cached index (or bundled-only).
            didRefresh = false
        }
    }

    private func applyIndex(entriesRaw: [[String: Any]], makersRaw: [[String: Any]]) {
        var hostedMakers: [String: String] = [:]
        var hostedMakerDisplayNames: [String: String] = [:]
        var hostedModelsByMaker: [String: Set<String>] = [:]

        for raw in makersRaw {
            guard let make = Self.firstString(in: raw, keys: ["make", "maker", "name", "title", "key"]) else { continue }
            let key = Self.normalize(make)
            guard !key.isEmpty else { continue }

            hostedMakerDisplayNames[key] = make
            if let logo = Self.firstString(in: raw, keys: ["logoImageId", "logoId", "imageId"]) {
                hostedMakers[key] = logo
            }
            for model in Self.stringArray(in: raw, keys: ["models", "modelNames"]) {
                hostedModelsByMaker[key, default: []].insert(model)
            }
        }

        entries = entriesRaw.compactMap { raw in
            guard let id = raw["id"] as? String else { return nil }
            let imageId = Self.firstString(in: raw, keys: ["imageId", "image", "assetId"]) ?? id
            let title = Self.firstString(in: raw, keys: ["title", "name"])
            let searchDescription = Self.firstString(in: raw, keys: ["searchDescription", "description"])
            let explicitMake = Self.firstString(in: raw, keys: ["make", "maker", "brand"])
            let explicitModel = Self.firstString(in: raw, keys: ["model", "modelName"])
            let inferred = Self.inferMakeModel(
                explicitMake: explicitMake,
                explicitModel: explicitModel,
                text: searchDescription ?? title ?? id,
                knownMakes: hostedMakerDisplayNames.values
            )

            if let make = inferred.make {
                let key = Self.normalize(make)
                if !key.isEmpty {
                    hostedMakerDisplayNames[key] = make
                    if let model = inferred.model, !Self.normalize(model).isEmpty {
                        hostedModelsByMaker[key, default: []].insert(model)
                    }
                }
            }

            var rawTokens = Self.stringArray(in: raw, keys: ["matchTokens", "tokens"])
            if let title { rawTokens.append(title) }
            if let searchDescription { rawTokens.append(searchDescription) }
            if let make = inferred.make, let model = inferred.model {
                rawTokens.append("\(make) \(model)")
            }
            let tokens = rawTokens
                .map { Self.normalize($0) }
                .filter { !$0.isEmpty }
            return Entry(
                id: id,
                imageId: imageId,
                matchTokens: Array(Set(tokens)).sorted { $0.count > $1.count },
                make: inferred.make,
                model: inferred.model,
                title: title,
                searchDescription: searchDescription
            )
        }

        makers = hostedMakers
        makerDisplayNames = hostedMakerDisplayNames
        modelsByMaker = hostedModelsByMaker.mapValues {
            $0.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
    }

    // MARK: - Disk persistence

    private struct CachedIndex: Codable {
        let version: Int
        let enabled: Bool
        let entries: [Entry]
        let makers: [String: String]
        let makerDisplayNames: [String: String]?
        let modelsByMaker: [String: [String]]?
    }

    private func loadCachedIndex() {
        guard let data = try? Data(contentsOf: indexFile),
              let cached = try? JSONDecoder().decode(CachedIndex.self, from: data) else { return }
        version = cached.version
        enabled = cached.enabled
        entries = cached.entries
        makers = cached.makers
        makerDisplayNames = cached.makerDisplayNames ?? [:]
        modelsByMaker = cached.modelsByMaker ?? [:]
    }

    private func persistIndex() {
        let cached = CachedIndex(
            version: version,
            enabled: enabled,
            entries: entries,
            makers: makers,
            makerDisplayNames: makerDisplayNames,
            modelsByMaker: modelsByMaker
        )
        if let data = try? JSONEncoder().encode(cached) {
            try? data.write(to: indexFile)
        }
    }

    // MARK: - Matching helpers

    /// Mirrors the web reader's normalizeSearchText: fold diacritics, lowercase,
    /// collapse any run of non-alphanumerics to a single space.
    static func normalize(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                   locale: Locale(identifier: "cs_CZ")).lowercased()
        var out = ""
        out.reserveCapacity(folded.count)
        var lastWasSpace = false
        for ch in folded {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastWasSpace = false
            } else if !lastWasSpace {
                out.append(" ")
                lastWasSpace = true
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    private static func firstString(in raw: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = raw[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func stringArray(in raw: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = raw[key] as? [String] {
                return values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
            if let values = raw[key] as? [Any] {
                return values.compactMap { value in
                    (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
            }
        }
        return []
    }

    private static func inferMakeModel(
        explicitMake: String?,
        explicitModel: String?,
        text: String,
        knownMakes: Dictionary<String, String>.Values
    ) -> (make: String?, model: String?) {
        let make = explicitMake?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = explicitModel?.trimmingCharacters(in: .whitespacesAndNewlines)
        if make?.isEmpty == false || model?.isEmpty == false {
            return (make?.isEmpty == false ? make : nil, model?.isEmpty == false ? model : nil)
        }

        let normalizedText = normalize(text)
        guard !normalizedText.isEmpty else { return (nil, nil) }

        let candidates = knownMakes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        for candidate in candidates {
            let normalizedMake = normalize(candidate)
            if normalizedText == normalizedMake {
                return (candidate, nil)
            }
            if normalizedText.hasPrefix("\(normalizedMake) ") {
                let remaining = String(text.dropFirst(candidate.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (candidate, remaining.isEmpty ? nil : remaining)
            }
        }

        return (nil, nil)
    }
}
