//
//  CarData.swift
//  EL PARKING APP
//
//  Car body types and Czech-focused make/model suggestions.
//

import Foundation

// MARK: - Car Body Type

enum CarBodyType: String, CaseIterable, Identifiable {
    case hatchback = "hatchback"
    case sedan     = "sedan"
    case combi     = "combi"
    case suv       = "suv"
    case cabriolet = "cabriolet"
    case van       = "van"
    case electric  = "electric"
    case other     = "other"

    var id: String { rawValue }

    var label: String {
        let cz = LanguageManager.shared.language == .czech
        switch self {
        case .hatchback: return "Hatchback"
        case .sedan:     return "Sedan"
        case .combi:     return cz ? "Combi"   : "Estate"
        case .suv:       return "SUV"
        case .cabriolet: return cz ? "Cabrio"  : "Cabriolet"
        case .van:       return "Van"
        case .electric:  return cz ? "Elektro" : "Electric"
        case .other:     return cz ? "Jiné"    : "Other"
        }
    }

    var icon: String {
        switch self {
        case .hatchback:  return "car.fill"
        case .sedan:      return "car.fill"
        case .combi:      return "car.fill"
        case .suv:        return "car.fill"
        case .cabriolet:  return "car.fill"
        case .van:        return "bus.fill"
        case .electric:   return "bolt.car.fill"
        case .other:      return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Car Suggestions

struct CarData {
    // CZ-focused set based on recent SDA registration trends.
    static let makes: [String] = [
        "Škoda", "Hyundai", "Toyota", "Volkswagen", "Kia", "Dacia",
        "Ford", "Mercedes-Benz", "Renault", "BMW", "Audi", "Volvo",
        "Tesla", "MG", "Nissan", "Peugeot", "MINI", "Subaru", "Porsche", "Honda",
        "Alfa Romeo",
        "Opel", "Mazda", "Citroën", "Seat"
    ]

    static let modelsByMake: [String: [String]] = [
        "Škoda": ["Octavia", "Octavia RS", "Octavia Combi Style", "Kamiq", "Karoq", "Karoq Style", "Kodiaq", "Fabia", "Scala", "Superb", "Superb Combi L&K", "Enyaq", "Elroq"],
        "Hyundai": ["i20", "i30", "Tucson", "Kona", "Bayon", "Santa Fe", "IONIQ 5", "IONIQ 6"],
        "Toyota": ["Corolla", "Yaris", "Yaris Cross", "RAV4", "C-HR", "Camry"],
        "Volkswagen": ["Golf", "Golf Variant", "Tiguan", "Tiguan 2.0 TSI Elegance", "Passat", "T-Roc", "Polo", "Touareg", "ID.3", "ID.4"],
        "Kia": ["Ceed", "Sportage", "Sorento", "Niro", "EV6", "EV9", "Picanto"],
        "Dacia": ["Duster", "Jogger", "Sandero", "Spring"],
        "Ford": ["Focus", "Kuga", "Puma", "Mustang Mach-E"],
        "Mercedes-Benz": ["A-Class", "C-Class", "C 220 d 4MATIC", "E-Class", "GLA", "GLC", "GLE", "EQA", "EQA 250", "EQB"],
        "Renault": ["Clio", "Captur", "Megane", "Austral", "Arkana", "Kangoo"],
        "BMW": ["3 Series", "5 Series", "X1", "X3", "X5", "i4", "iX"],
        "Audi": ["A3", "A4", "A4 Avant B9", "A4 Avant 35 TDI S-Line", "A6", "Q3", "Q5", "Q7", "Q8", "Q4", "Q4 e-tron"],
        "Volvo": ["EX30", "XC40", "XC60", "XC90", "V60", "V90"],
        "Tesla": ["Model 3", "Model Y", "Model S", "Model X"],
        "MG": ["ZS", "MG4", "HS", "Marvel R"],
        "Nissan": ["Qashqai", "Juke", "X-Trail", "Leaf", "Ariya"],
        "Peugeot": ["208", "308", "2008", "3008", "5008", "Rifter"],
        "MINI": ["Countryman", "Countryman Electric", "Cooper", "Cooper Electric"],
        "Subaru": ["Outback", "Forester", "Crosstrek"],
        "Porsche": ["Cayenne", "Macan", "911", "Taycan"],
        "Honda": ["Civic", "CR-V", "HR-V", "Jazz"],
        "Alfa Romeo": ["Stelvio", "Giulia", "Tonale"],
        "Opel": ["Corsa", "Astra", "Mokka", "Crossland", "Grandland"],
        "Mazda": ["Mazda3", "Mazda6", "CX-30", "CX-5", "CX-60"],
        "Citroën": ["C3", "C4", "C5 Aircross", "Berlingo"],
        "Seat": ["Ibiza", "Leon", "Arona", "Ateca", "Tarraco"]
    ]

    static var suggestions: [String] {
        makes.flatMap { make in
            (modelsByMake[make] ?? []).map { "\(make) \($0)" }
        }
    }

    static func models(for make: String) -> [String] {
        guard let canonical = canonicalMake(from: make) else { return [] }
        return modelsByMake[canonical] ?? []
    }

    static func compose(make: String, model: String) -> String {
        let mk = canonicalMake(from: make) ?? make.trimmingCharacters(in: .whitespacesAndNewlines)
        let md = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mk.isEmpty else { return md }
        guard !md.isEmpty else { return mk }
        return "\(mk) \(md)"
    }

    static func splitMakeModel(_ full: String) -> (make: String, model: String) {
        let value = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return ("", "") }
        let normalizedFull = normalize(value)

        // Prefer exact make+model matches first.
        for make in makes {
            for model in modelsByMake[make] ?? [] {
                if normalize(compose(make: make, model: model)) == normalizedFull {
                    return (make, model)
                }
            }
        }

        // Then exact make-only values.
        if let makeOnly = makes.first(where: { normalize($0) == normalizedFull }) {
            return (makeOnly, "")
        }

        // Fallback for manually-entered unknown models.
        if let matchedMake = makes.first(where: { normalizedFull.hasPrefix(normalize($0) + " ") }) {
            let foldedValue = value.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let foldedMake = matchedMake.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            if foldedValue.hasPrefix(foldedMake) {
                let modelStart = value.index(value.startIndex, offsetBy: min(value.count, matchedMake.count))
                let model = String(value[modelStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (matchedMake, model)
            }
            return (matchedMake, "")
        }

        return ("", value)
    }

    static func canonicalMake(from raw: String) -> String? {
        let normalized = normalize(raw)
        return makes.first { normalize($0) == normalized }
    }

    /// Returns up to 6 suggestions matching the query (accent- and case-insensitive).
    static func filter(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let normalized = normalize(q)
        return suggestions
            .filter {
                normalize($0).contains(normalized)
            }
            .prefix(6)
            .map { $0 }
    }

    private static func normalize(_ value: String) -> String {
        let folded = value.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let mapped = folded.map { ch -> Character in
            if ch.isLetter || ch.isNumber {
                return ch
            }
            return " "
        }
        return String(mapped)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
