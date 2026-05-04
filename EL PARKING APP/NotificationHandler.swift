//
//  NotificationHandler.swift
//  EL PARKING APP
//
//  Handles notification categories, actions, and responses.
//  Category: daily booking reminder with Keep / Edit / Cancel actions.
//

import Foundation
@preconcurrency import UserNotifications

class NotificationHandler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    nonisolated static let shared = NotificationHandler()

    // Category & action identifiers
    nonisolated static let bookingReminderCategory = "BOOKING_REMINDER"
    nonisolated static let actionKeep   = "ACTION_KEEP"
    nonisolated static let actionEdit   = "ACTION_EDIT"
    nonisolated static let actionCancel = "ACTION_CANCEL"

    // Posted when user taps Edit on notification — observed by views
    nonisolated static let editBookingNotification = Notification.Name("EditBookingFromNotification")
    // Posted when user taps Cancel on notification
    nonisolated static let cancelBookingNotification = Notification.Name("CancelBookingFromNotification")

    private override init() {
        super.init()
    }

    /// Register notification categories with actions. Call once at app launch.
    func registerCategories() {
        let keepAction = UNNotificationAction(
            identifier: Self.actionKeep,
            title: "Keep",
            options: []
        )

        let editAction = UNNotificationAction(
            identifier: Self.actionEdit,
            title: "Edit",
            options: [.foreground]  // opens the app
        )

        let cancelAction = UNNotificationAction(
            identifier: Self.actionCancel,
            title: "Cancel Booking",
            options: [.destructive, .foreground]
        )

        let reminderCategory = UNNotificationCategory(
            identifier: Self.bookingReminderCategory,
            actions: [keepAction, editAction, cancelAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notification even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let content = notification.request.content

        // Keep booking reminders quiet while app is already open.
        if content.categoryIdentifier == Self.bookingReminderCategory {
            return [.list]
        }

        // Proximity reminders should also be non-intrusive in foreground.
        if let source = content.userInfo["source"] as? String, source == "proximityReminder" {
            return [.list]
        }

        // For other notification types, keep banner + sound but avoid badge spam.
        return [.banner, .sound]
    }

    /// Handle notification action response
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let bookingIDString = response.notification.request.content.userInfo["bookingID"] as? String

        switch response.actionIdentifier {
        case Self.actionKeep, UNNotificationDismissActionIdentifier:
            // Do nothing — user wants to keep the booking
            break

        case Self.actionEdit:
            if let idString = bookingIDString {
                NotificationCenter.default.post(
                    name: Self.editBookingNotification,
                    object: nil,
                    userInfo: ["bookingID": idString]
                )
            }

        case Self.actionCancel:
            if let idString = bookingIDString {
                NotificationCenter.default.post(
                    name: Self.cancelBookingNotification,
                    object: nil,
                    userInfo: ["bookingID": idString]
                )
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself — open app normally
            break

        default:
            break
        }
    }
}
