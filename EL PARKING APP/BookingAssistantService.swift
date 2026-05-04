//
//  BookingAssistantService.swift
//  EL PARKING APP
//
//  Optional natural-language booking assistant.
//  Uses FoundationModels when available and falls back to deterministic parsing.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct BookingAssistantInterpretation: Equatable {
    var date: Date
    var timeFrom: String
    var timeTo: String
    var preferredSpotID: String?
    var preferNearEntrance: Bool
    var explanation: String
}

struct BookingAssistantService {
    func interpret(
        prompt: String,
        spots: [ParkingSpot]
    ) async -> BookingAssistantInterpretation? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let fm = await foundationModelsInterpret(prompt: trimmed, spots: spots) {
            return fm
        }
        #endif

        return fallbackInterpret(prompt: trimmed, spots: spots)
    }

    private func fallbackInterpret(
        prompt: String,
        spots: [ParkingSpot]
    ) -> BookingAssistantInterpretation? {
        let lower = prompt.lowercased()

        let date = parsedDate(from: lower)
        guard let (from, to) = parsedTimeRange(from: lower) else { return nil }

        let preferredSpot = parsedSpotID(from: lower, spots: spots)
        let nearEntrance = containsAny(
            in: lower,
            keywords: ["near entrance", "entrance", "entry", "vchod", "u vchodu"]
        )

        return BookingAssistantInterpretation(
            date: date,
            timeFrom: from,
            timeTo: to,
            preferredSpotID: preferredSpot,
            preferNearEntrance: nearEntrance,
            explanation: "Parsed from your request."
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func foundationModelsInterpret(
        prompt: String,
        spots: [ParkingSpot]
    ) async -> BookingAssistantInterpretation? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            return nil
        }

        let supportedSpots = spots.map(\.id).sorted().joined(separator: ", ")
        let instructions = """
        You convert parking requests to a compact booking command.
        Return one line only in this exact format:
        date=today|tomorrow;from=HH:mm;to=HH:mm;nearEntrance=true|false;spot=<ID or empty>
        Use 24-hour time and keep output minimal.
        Allowed spot IDs: \(supportedSpots)
        """

        let session = LanguageModelSession(instructions: instructions)
        guard let response = try? await session.respond(to: prompt) else { return nil }
        let line = String(describing: response).lowercased()

        guard let (from, to) = parsedTimeRange(from: line) else { return nil }
        let date: Date = line.contains("date=tomorrow")
            ? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            : Date()
        let nearEntrance = line.contains("nearentrance=true") || line.contains("nearentrance: true")
        let preferredSpot = parsedSpotID(from: line, spots: spots)

        return BookingAssistantInterpretation(
            date: date,
            timeFrom: from,
            timeTo: to,
            preferredSpotID: preferredSpot,
            preferNearEntrance: nearEntrance,
            explanation: "Interpreted by on-device model."
        )
    }
    #endif

    private func parsedDate(from text: String) -> Date {
        if containsAny(in: text, keywords: ["tomorrow", "zítra", "zitra"]) {
            return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        return Date()
    }

    private func parsedSpotID(from text: String, spots: [ParkingSpot]) -> String? {
        for id in spots.map(\.id).sorted() {
            if text.contains("#\(id)") || text.contains("spot \(id)") || text.contains("parking \(id)") {
                return id
            }
        }
        return nil
    }

    private func parsedTimeRange(from text: String) -> (String, String)? {
        let pattern = "(\\d{1,2})(?::(\\d{2}))?\\s*(?:-|to|–|—)\\s*(\\d{1,2})(?::(\\d{2}))?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        let fromHour = intCapture(1, in: text, match: match) ?? 0
        let fromMinute = intCapture(2, in: text, match: match) ?? 0
        let toHour = intCapture(3, in: text, match: match) ?? 0
        let toMinute = intCapture(4, in: text, match: match) ?? 0

        let from = String(format: "%02d:%02d", max(0, min(23, fromHour)), max(0, min(59, fromMinute)))
        let to = String(format: "%02d:%02d", max(0, min(23, toHour)), max(0, min(59, toMinute)))
        return from < to ? (from, to) : nil
    }

    private func intCapture(_ idx: Int, in text: String, match: NSTextCheckingResult) -> Int? {
        guard idx < match.numberOfRanges else { return nil }
        let nsr = match.range(at: idx)
        guard nsr.location != NSNotFound, let range = Range(nsr, in: text) else { return nil }
        return Int(text[range])
    }

    private func containsAny(in text: String, keywords: [String]) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }
}
