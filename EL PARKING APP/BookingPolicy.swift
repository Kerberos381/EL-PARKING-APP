//
//  BookingPolicy.swift
//  EL PARKING APP
//
//  Pure booking rules shared by BookingManager and unit tests.
//

import Foundation

enum BookingPolicy {
    static func intervalsOverlap(startA: String, endA: String, startB: String, endB: String) -> Bool {
        timeMinutes(startA) < timeMinutes(endB) && timeMinutes(endA) > timeMinutes(startB)
    }

    static func bookingEndDate(
        date: Date,
        toTime: String,
        calendar: Calendar = .current
    ) -> Date {
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let parts = toTime.split(separator: ":")
        dateComponents.hour = Int(parts.first ?? "") ?? 23
        dateComponents.minute = Int(parts.dropFirst().first ?? "") ?? 59
        dateComponents.second = 0
        return calendar.date(from: dateComponents) ?? date
    }

    static func retentionCutDate(
        now: Date = Date(),
        retentionDays: Int = AppConfig.bookingRetentionDays,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? now
    }

    /// Firestore queries use date-only `bookingDate`, so the query starts at the
    /// beginning of the local retention day. The in-memory retention filter then
    /// trims by actual booking end time.
    static func listenerQueryStartDate(
        now: Date = Date(),
        retentionDays: Int = AppConfig.bookingRetentionDays,
        calendar: Calendar = .current
    ) -> Date {
        calendar.startOfDay(for: retentionCutDate(now: now, retentionDays: retentionDays, calendar: calendar))
    }

    static func shouldKeepLocally(
        _ booking: Booking,
        now: Date = Date(),
        retentionDays: Int = AppConfig.bookingRetentionDays,
        calendar: Calendar = .current
    ) -> Bool {
        bookingEndDate(date: booking.date, toTime: booking.toTime, calendar: calendar) >=
            retentionCutDate(now: now, retentionDays: retentionDays, calendar: calendar)
    }

    static func bookingsForUserCount(
        _ bookings: [Booking],
        email: String,
        on date: Date,
        calendar: Calendar = .current
    ) -> Int {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return bookings.filter {
            $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedEmail &&
            calendar.isDate($0.date, inSameDayAs: date)
        }.count
    }

    static func delegatedBookingCount(
        _ bookings: [Booking],
        createdBy creatorEmail: String,
        on date: Date,
        calendar: Calendar = .current
    ) -> Int {
        let normalizedCreator = creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return bookings.filter {
            $0.createdBy.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedCreator &&
            $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != normalizedCreator &&
            calendar.isDate($0.date, inSameDayAs: date)
        }.count
    }

    private static func timeMinutes(_ time: String) -> Int {
        let parts = time.split(separator: ":")
        let hour = Int(parts.first ?? "") ?? 0
        let minute = Int(parts.dropFirst().first ?? "") ?? 0
        return hour * 60 + minute
    }
}
