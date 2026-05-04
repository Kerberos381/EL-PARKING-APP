//
//  Booking.swift
//  EL PARKING APP
//
//  Created on 2026-03-24.
//

import Foundation

/// Represents a single parking reservation for one day.
struct Booking: Identifiable, Codable {
    let id: UUID
    var title: String       // "Reservation for {displayName}"
    var spot: String        // "Parking 63" (matches ParkingSpot.label)
    var user: String        // display name of the person the booking is for
    var email: String       // email of the person the booking is for
    var date: Date          // booking date (date-only, no time component)
    var fromTime: String    // "07:00"
    var toTime: String      // "17:00"
    var createdBy: String   // email of who created the booking
    var createdAt: Date     = Date()  // when the booking was made (default keeps old cached data valid)
    /// Shared UUID across all daily bookings created in a single multi-day range operation.
    /// nil for single-day bookings.
    var groupID: UUID?      = nil

    /// Extracts person name from title (removes "Reservation for " prefix)
    var personName: String {
        title
            .replacingOccurrences(of: "Reservation for ", with: "")
            .replacingOccurrences(of: "Rezervace pro ", with: "")
    }

    /// Short spot code like "P63"
    var spotShortCode: String {
        spot.replacingOccurrences(of: "Parking ", with: "P")
    }

    /// Just the spot number like "63"
    var spotNumber: String {
        spot.replacingOccurrences(of: "Parking ", with: "")
    }

    /// Returns true if this booking is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Returns true if this booking is for tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }

    /// Returns true if this booking is in the past
    var isPast: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return date < today
    }

    /// Natural language date: "DNES"/"TODAY", "ZÍTRA"/"TOMORROW", or "St 29."/"Wed 29th"
    var naturalDate: String {
        if isToday { return L10n.today.uppercased() }
        if isTomorrow { return L10n.tomorrow.uppercased() }
        return date.formatNaturalShort()
    }

    /// Full date with context label: "Dnes · Čt, 27 bře" / "Today · Thu, 27 Mar"
    var richDate: String {
        let isCzech = LanguageManager.shared.language == .czech
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, d MMM"
        fmt.locale = isCzech ? Locale(identifier: "cs_CZ") : Locale(identifier: "en_GB")
        let dateStr = fmt.string(from: date)
        if isToday    { return "\(L10n.today) · \(dateStr)" }
        if isTomorrow { return "\(L10n.tomorrow) · \(dateStr)" }
        return dateStr
    }

    /// Was this booking created by someone else (booked for you)?
    var isBookedByOther: Bool {
        email != createdBy
    }

    /// First name of the user
    var firstName: String {
        let parts = user.split(separator: " ")
        return String(parts.first ?? Substring(user))
    }
}
