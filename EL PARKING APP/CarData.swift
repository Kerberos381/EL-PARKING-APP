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
    static let suggestions: [String] = [
        // Škoda — most common in CZ
        "Škoda Citigo", "Škoda Fabia", "Škoda Rapid", "Škoda Scala",
        "Škoda Octavia", "Škoda Superb", "Škoda Kamiq", "Škoda Karoq",
        "Škoda Kodiaq", "Škoda Enyaq", "Škoda Enyaq Coupé",

        // Volkswagen
        "VW Polo", "VW Golf", "VW Passat", "VW Arteon",
        "VW T-Roc", "VW Tiguan", "VW Touareg", "VW ID.3", "VW ID.4",

        // BMW
        "BMW 1 Series", "BMW 2 Series", "BMW 3 Series", "BMW 5 Series", "BMW 7 Series",
        "BMW X1", "BMW X3", "BMW X5", "BMW iX", "BMW i4",

        // Mercedes
        "Mercedes A-Class", "Mercedes C-Class", "Mercedes E-Class", "Mercedes S-Class",
        "Mercedes GLA", "Mercedes GLC", "Mercedes GLE", "Mercedes EQB", "Mercedes EQC",

        // Audi
        "Audi A1", "Audi A3", "Audi A4", "Audi A6",
        "Audi Q2", "Audi Q3", "Audi Q5", "Audi Q8",
        "Audi e-tron", "Audi Q4 e-tron",

        // Ford
        "Ford Fiesta", "Ford Focus", "Ford Mondeo", "Ford Puma", "Ford Kuga",
        "Ford Mustang Mach-E",

        // Toyota
        "Toyota Yaris", "Toyota Corolla", "Toyota Camry", "Toyota C-HR",
        "Toyota RAV4", "Toyota bZ4X",

        // Hyundai
        "Hyundai i20", "Hyundai i30", "Hyundai Tucson", "Hyundai Santa Fe",
        "Hyundai IONIQ 5", "Hyundai IONIQ 6",

        // Kia
        "Kia Picanto", "Kia Rio", "Kia Ceed", "Kia Sportage", "Kia Sorento", "Kia EV6",

        // Volvo
        "Volvo V40", "Volvo V60", "Volvo V90", "Volvo XC40", "Volvo XC60", "Volvo XC90",
        "Volvo EX30", "Volvo EX40",

        // Renault
        "Renault Clio", "Renault Megane", "Renault Captur", "Renault Kadjar",
        "Renault Zoe", "Renault Megane E-Tech",

        // Peugeot
        "Peugeot 208", "Peugeot 308", "Peugeot 508",
        "Peugeot 2008", "Peugeot 3008", "Peugeot e-208",

        // Dacia
        "Dacia Sandero", "Dacia Logan", "Dacia Duster", "Dacia Spring",

        // SEAT / Cupra
        "SEAT Ibiza", "SEAT Leon", "SEAT Arona", "SEAT Ateca",
        "Cupra Born", "Cupra Formentor", "Cupra Leon",

        // Opel
        "Opel Corsa", "Opel Astra", "Opel Insignia", "Opel Mokka", "Opel Crossland",

        // Citroën
        "Citroën C3", "Citroën C4", "Citroën C5 X", "Citroën Berlingo",

        // Nissan
        "Nissan Micra", "Nissan Juke", "Nissan Qashqai", "Nissan Leaf", "Nissan Ariya",

        // Mazda
        "Mazda2", "Mazda3", "Mazda6", "Mazda CX-3", "Mazda CX-5", "Mazda CX-60", "Mazda MX-30",

        // Honda
        "Honda Jazz", "Honda Civic", "Honda HR-V", "Honda CR-V", "Honda e",

        // Fiat
        "Fiat Panda", "Fiat 500", "Fiat Tipo", "Fiat 500e",

        // Porsche
        "Porsche 911", "Porsche Cayenne", "Porsche Macan", "Porsche Taycan",

        // Tesla
        "Tesla Model 3", "Tesla Model Y", "Tesla Model S", "Tesla Model X",
    ]

    /// Returns up to 6 suggestions matching the query (accent- and case-insensitive).
    static func filter(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let normalized = q.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return suggestions
            .filter {
                $0.folding(options: .diacriticInsensitive, locale: .current)
                  .lowercased()
                  .contains(normalized)
            }
            .prefix(6)
            .map { $0 }
    }
}
