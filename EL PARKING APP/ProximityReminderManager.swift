//
//  ProximityReminderManager.swift
//  EL PARKING APP
//
//  Minimal app-lifecycle hook for location-based reminders.
//

import Foundation

@MainActor
final class ProximityReminderManager {
    static let shared = ProximityReminderManager()

    private weak var bookingManager: BookingManager?

    private init() {}

    func configure(with bookingManager: BookingManager) {
        self.bookingManager = bookingManager
    }

    func clear() {
        bookingManager = nil
    }
}
