//
//  Date+Helpers.swift
//  EL PARKING APP
//
//  Created on 2026-03-24.
//

import Foundation
import SwiftUI

extension Date {

    /// Returns the correct locale based on the current in-app language setting.
    private var appLocale: Locale {
        LanguageManager.shared.language == .czech
            ? Locale(identifier: "cs_CZ")
            : Locale(identifier: "en_GB")
    }

    /// Returns true if current time is after the auto-advance hour (17:00)
    static func shouldAutoAdvanceToTomorrow() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= AppConfig.autoAdvanceHour
    }

    /// Returns today's date or tomorrow's date if after 17:00
    static func smartDefaultDate() -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        if shouldAutoAdvanceToTomorrow() {
            return Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        }
        return today
    }

    /// Format date as "24 Mar" / "24 bře" (dd MMM)
    func formatShort() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = appLocale
        return formatter.string(from: self)
    }

    /// Format date as "Tuesday" / "úterý"
    func formatDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = appLocale
        return formatter.string(from: self)
    }

    /// Format as short day of week "Wed" / "Út"
    func formatShortDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = appLocale
        return formatter.string(from: self)
    }

    /// Natural language short format: "Wed 29th" / "St 29."
    func formatNaturalShort() -> String {
        let day = Calendar.current.component(.day, from: self)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = appLocale
        let dayName = formatter.string(from: self)
        if LanguageManager.shared.language == .czech {
            return "\(dayName) \(day)."
        }
        return "\(dayName) \(day)\(daySuffix(day))"
    }

    /// Format date as "dd.MM.yyyy" for email templates
    func formatEmail() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: self)
    }

    /// Returns the number of days between this date and another date
    func daysBetween(_ otherDate: Date) -> Int? {
        let calendar = Calendar.current
        let startOfSelf = calendar.startOfDay(for: self)
        let startOfOther = calendar.startOfDay(for: otherDate)
        let components = calendar.dateComponents([.day], from: startOfSelf, to: startOfOther)
        return components.day
    }

    /// Relative time: "Just now", "3h ago", "Yesterday", "3d ago", or short date fallback
    func relativeTime() -> String {
        let secs = Int(Date().timeIntervalSince(self))
        switch secs {
        case ..<60:     return "Just now"
        case ..<3600:   return "\(secs / 60)m ago"
        case ..<86400:  return "\(secs / 3600)h ago"
        case ..<172800: return "Yesterday"
        case ..<604800: return "\(secs / 86400)d ago"
        default:        return formatShort()
        }
    }

    /// Day number suffix (1st, 2nd, 3rd, 4th...)
    private func daySuffix(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}
