//
//  EL_PARKING_APPTests.swift
//  EL PARKING APPTests
//
//  Created by Stiv Malakjan on 26.03.2026.
//

import Foundation
import Testing
@testable import EL_PARKING_APP

struct EL_PARKING_APPTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 0,
            minute: 0,
            second: 0
        )
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func makeBooking(
        email: String,
        createdBy: String,
        date: Date,
        fromTime: String = "07:00",
        toTime: String = "18:00"
    ) -> Booking {
        Booking(
            id: UUID(),
            title: "Reservation for Test User",
            spot: "Parking 75",
            user: "Test User",
            email: email,
            date: date,
            fromTime: fromTime,
            toTime: toTime,
            createdBy: createdBy
        )
    }

    @Test func intervalsOverlapWhenRangesIntersect() {
        #expect(BookingPolicy.intervalsOverlap(startA: "07:00", endA: "12:00", startB: "11:00", endB: "13:00"))
        #expect(!BookingPolicy.intervalsOverlap(startA: "07:00", endA: "09:00", startB: "09:00", endB: "10:00"))
    }

    @Test func bookingEndDateRespectsToTime() {
        let date = makeDate(2026, 5, 12)
        let endDate = BookingPolicy.bookingEndDate(date: date, toTime: "18:30", calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute], from: endDate)
        #expect(components.hour == 18)
        #expect(components.minute == 30)
    }

    @Test func shouldKeepLocallyUsesRetentionWindow() {
        let now = makeDate(2026, 5, 12)
        let bookingInsideWindow = makeBooking(
            email: "user@example.com",
            createdBy: "user@example.com",
            date: makeDate(2026, 5, 10),
            toTime: "23:59"
        )
        let bookingOutsideWindow = makeBooking(
            email: "user@example.com",
            createdBy: "user@example.com",
            date: makeDate(2026, 5, 8),
            toTime: "12:00"
        )

        #expect(BookingPolicy.shouldKeepLocally(bookingInsideWindow, now: now, retentionDays: 2, calendar: calendar))
        #expect(!BookingPolicy.shouldKeepLocally(bookingOutsideWindow, now: now, retentionDays: 2, calendar: calendar))
    }

    @Test func bookingCountsNormalizeEmailAndSeparateDelegated() {
        let date = makeDate(2026, 5, 12)
        let bookings = [
            makeBooking(email: "driver@example.com", createdBy: "driver@example.com", date: date),
            makeBooking(email: "Driver@Example.com", createdBy: "driver@example.com", date: date),
            makeBooking(email: "other@example.com", createdBy: "driver@example.com", date: date),
            makeBooking(email: "driver@example.com", createdBy: "driver@example.com", date: makeDate(2026, 5, 13))
        ]

        let ownCount = BookingPolicy.bookingsForUserCount(bookings, email: " DRIVER@example.com ", on: date, calendar: calendar)
        let delegatedCount = BookingPolicy.delegatedBookingCount(bookings, createdBy: "driver@example.com", on: date, calendar: calendar)

        #expect(ownCount == 2)
        #expect(delegatedCount == 1)
    }
}
