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
}

#else

enum Haptics {
    static func selection() {}
    static func impact(_ style: Int = 0) {}
    static func notify(_ type: Int) {}
}

#endif
