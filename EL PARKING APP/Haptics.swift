//
//  Haptics.swift
//  EL PARKING APP
//
//  Centralized haptic feedback helpers for important interactions.
//

import Foundation

#if canImport(UIKit)
import UIKit
import QuartzCore
import CoreHaptics

enum Haptics {
    private static let lock = NSLock()
    private static var lastFiredAt: [String: CFTimeInterval] = [:]

    private static func shouldFire(key: String, debounce: CFTimeInterval) -> Bool {
        let now = CACurrentMediaTime()
        lock.lock()
        defer { lock.unlock() }
        let last = lastFiredAt[key] ?? 0
        guard now - last >= debounce else { return false }
        lastFiredAt[key] = now
        return true
    }

    static func selection() {
        guard shouldFire(key: "selection", debounce: 0.07) else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func action() {
        guard shouldFire(key: "action", debounce: 0.09) else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    /// Use for confirmed destructive actions (delete/cancel/remove).
    static func destructive() {
        guard shouldFire(key: "destructive", debounce: 0.12) else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard shouldFire(key: "impact.\(style.rawValue)", debounce: 0.08) else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard shouldFire(key: "notify.\(type.rawValue)", debounce: 0.18) else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Soft tick after a pull-to-refresh completes.
    static func refreshCompleted() {
        guard shouldFire(key: "refreshCompleted", debounce: 0.5) else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.6)
    }

    /// Two-beat "thunk … tick" for the booking-confirmed moment, timed so the
    /// thunk lands as the car settles into the spot. Falls back to the system
    /// success notification when the device lacks a haptic engine.
    static func parked() {
        guard shouldFire(key: "parked", debounce: 0.5) else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            let engine = try CHHapticEngine()
            try engine.start()

            let thunk = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                ],
                relativeTime: 0
            )
            let tick = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
                ],
                relativeTime: 0.14
            )

            let pattern = try CHHapticPattern(events: [thunk, tick], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            engine.notifyWhenPlayersFinished { _ in .stopEngine }
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

#else

enum Haptics {
    static func selection() {}
    static func destructive() {}
    static func impact(_ style: Int = 0) {}
    static func notify(_ type: Int) {}
    static func refreshCompleted() {}
    static func parked() {}
}

#endif
