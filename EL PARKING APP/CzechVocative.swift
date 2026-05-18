//
//  CzechVocative.swift
//  EL PARKING APP
//
//  Lightweight Czech vocative helper for first-name greetings.
//

import Foundation

enum CzechVocative {
    private static let irregular: [String: String] = [
        "jan": "Jane",
        "ivan": "Ivane",
        "petr": "Petře",
        "jiri": "Jiří",
        "jirí": "Jiří",
        "jarda": "Jardo",
        "marek": "Marku",
        "radek": "Radku",
        "pavel": "Pavle",
        "karel": "Karle",
        "michal": "Michale",
        "tomas": "Tomáši",
        "tomaš": "Tomáši",
        "lukas": "Lukáši",
        "lukaš": "Lukáši",
        "ladislav": "Ladislave",
        "katka": "Katko",
        "katerina": "Kateřino",
        "kateřina": "Kateřino"
    ]

    static func inflect(firstName raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return raw }

        let key = normalizedKey(name)
        if let direct = irregular[key] {
            return applyCase(from: name, to: direct)
        }

        if hasSuffix(name, "ka") {
            return replaceSuffix(name, "ka", with: "ko")
        }
        if hasSuffix(name, "a") {
            return replaceSuffix(name, "a", with: "o")
        }
        if hasSuffix(name, "ek") {
            return replaceSuffix(name, "ek", with: "ku")
        }
        if hasSuffix(name, "el") {
            return replaceSuffix(name, "el", with: "le")
        }
        if hasSuffix(name, "e") || hasSuffix(name, "o") || hasSuffix(name, "i") {
            return name
        }
        if hasSuffix(name, "h") || hasSuffix(name, "ch") || hasSuffix(name, "k") ||
            hasSuffix(name, "g") || hasSuffix(name, "q") {
            return name + "u"
        }

        return name + "e"
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "cs_CZ"))
            .lowercased()
    }

    private static func hasSuffix(_ value: String, _ suffix: String) -> Bool {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "cs_CZ"))
            .lowercased()
            .hasSuffix(
                suffix.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "cs_CZ"))
                    .lowercased()
            )
    }

    private static func replaceSuffix(_ value: String, _ suffix: String, with replacement: String) -> String {
        guard value.count >= suffix.count else { return value }
        let split = value.index(value.endIndex, offsetBy: -suffix.count)
        return String(value[..<split]) + replacement
    }

    private static func applyCase(from template: String, to value: String) -> String {
        if template == template.uppercased() {
            return value.uppercased()
        }
        if template == template.lowercased() {
            return value.lowercased()
        }
        if let first = template.first, String(first) == String(first).uppercased() {
            let lower = value.lowercased()
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }
        return value
    }
}
