//
//  BookingManager.swift
//  EL PARKING APP
//
//  Central booking state manager.
//  Persists to Firestore (primary) + UserDefaults (widget cache).
//

import Foundation
import Combine
@preconcurrency import UserNotifications
import WidgetKit
import CoreGraphics
import CryptoKit
import FirebaseFirestore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight struct for encoding booking data to shared UserDefaults for widgets
struct WidgetBookingData: Codable {
    let id: String
    let spotNumber: String
    let spotLabel: String
    let userName: String
    let fromTime: String
    let toTime: String
    let bookingDate: Date
    let isToday: Bool
}

@MainActor
class BookingManager: ObservableObject {
    struct BookingSuggestion: Identifiable, Hashable {
        let id = UUID()
        let spot: ParkingSpot
        let fromTime: String
        let toTime: String
        let isExactTimeMatch: Bool
    }

    struct BookingTTLBackfillResult {
        let scanned: Int
        let updated: Int
        let skipped: Int
    }

    struct ExpiredBookingCleanupResult {
        let scanned: Int
        let deleted: Int
        let skipped: Int
    }

    @Published var bookings: [Booking] = []
    @Published var parkingSpots: [ParkingSpot] = AppConfig.allParkingSpots   // ← observable copy
    /// Frozen snapshot of the hardcoded AppConfig defaults — used as fallback when a spot
    /// has no Firestore document (so isAccessible from AppConfig is never lost).
    private let baseParkingSpots: [ParkingSpot] = AppConfig.allParkingSpots
    @Published var currentUserEmail: String = ""
    @Published var currentUserName:  String = ""
    @Published var currentUserUID:   String = ""
    @Published var currentUserRole:  UserRole = .user
    @Published var currentUserCompany: CompanyBadge = .none
    @Published var registrationPlate: String = ""
    @Published var carDescription:    String = ""
    @Published var carColor:           String = ""
    @Published var carType:            String = ""
    @Published var vehicleMiniaturePresetID: String = ""
    @Published var preferredVocative: String = ""

    private lazy var db = Firestore.firestore()
    private var bookingsListener: ListenerRegistration?
    private var spotsListener: ListenerRegistration?
    private var lastReminderHash: String = ""
    private var lastBookingsSignature: Int?
    private var lastSpotsSignature: Int?
    private var lastVehicleRenderHash: Int = 0

    init() {
        // Reminders default ON @ 30 min before. register(defaults:) seeds the raw
        // UserDefaults reads used by the scheduler (.bool/.integer) without persisting,
        // so anyone who explicitly turned reminders OFF keeps their choice.
        UserDefaults.standard.register(defaults: [
            "dailyReminderEnabled": true,
            "reminderMinutesBefore": 30,
        ])
        loadSpotsCache()      // Cached spot list for offline use
        loadLocalCache()      // Fast local load for widget + offline
        loadUserProfile()
        requestNotificationPermission()
        migrateOldNotificationKeys()
        // Skip widget update until a real user email is loaded (avoids clearing widget on fresh launch)
        if !currentUserEmail.isEmpty { updateWidgetData() }
    }

    // MARK: - Configure for Firebase User (called after login)

    func configureForUser(
        email:    String,
        name:     String,
        uid:      String,
        role:     UserRole,
        plate:    String = "",
        car:      String = "",
        color:    String = "",
        carType:  String = "",
        vehicleMiniaturePresetID: String = "",
        preferredVocative: String = "",
        companyBadge: CompanyBadge = .none
    ) {
        currentUserCompany = companyBadge
        currentUserEmail  = email
        currentUserName   = name.isEmpty ? email : name
        currentUserUID    = uid
        currentUserRole   = role
        registrationPlate = plate
        carDescription    = car
        carColor          = color
        self.carType      = carType
        self.vehicleMiniaturePresetID = vehicleMiniaturePresetID
        self.preferredVocative = preferredVocative.trimmingCharacters(in: .whitespacesAndNewlines)

        // Persist for offline / widget use
        UserDefaults.standard.set(email,   forKey: "userEmail")
        UserDefaults.standard.set(name,    forKey: "userName")
        UserDefaults.standard.set(plate,   forKey: "registrationPlate")
        UserDefaults.standard.set(car,     forKey: "carDescription")
        UserDefaults.standard.set(color,   forKey: "carColor")
        UserDefaults.standard.set(carType, forKey: "carType")
        UserDefaults.standard.set(vehicleMiniaturePresetID, forKey: "vehicleMiniaturePresetID")
        UserDefaults.standard.set(self.preferredVocative, forKey: "preferredVocative")

        // Share identity with App Intents (which run in a separate process)
        let ag = UserDefaults.appGroup
        ag.set(uid,                        forKey: "currentUserUID")
        ag.set(email,                      forKey: "currentUserEmail")
        ag.set(name.isEmpty ? email : name, forKey: "currentUserName")

        startFirestoreListener()
        startSpotsListener()
        updateWidgetData()
    }

    func clearUser() {
        bookingsListener?.remove()
        bookingsListener = nil
        spotsListener?.remove()
        spotsListener = nil
        bookings = []
        AppConfig.blockedSpotIDs = []
        parkingSpots      = AppConfig.allParkingSpots   // reset to base (no live accessibility)
        lastBookingsSignature = nil
        lastSpotsSignature = nil
        currentUserEmail  = ""
        currentUserName   = ""
        currentUserUID    = ""
        currentUserRole   = .user
        preferredVocative = ""
        let ag = UserDefaults.appGroup
        ag.removeObject(forKey: "currentUserUID")
        ag.removeObject(forKey: "currentUserEmail")
        ag.removeObject(forKey: "currentUserName")
        lastVehicleRenderHash = 0
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.StivMalakjan.EL-PARKING-APP"
        ) {
            try? FileManager.default.removeItem(
                at: containerURL.appendingPathComponent("vehicleMiniature.png")
            )
        }
        updateWidgetData()
    }

    // MARK: - Firestore Real-Time Listener

    private func startFirestoreListener() {
        bookingsListener?.remove()

        bookingsListener = recentBookingsQuery()
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                var droppedDocIDs: [String] = []
                var schemaWarnings: [String] = []
                let parsed = snapshot.documents.compactMap { doc -> Booking? in
                    let data = doc.data()
                    schemaWarnings.append(contentsOf: FirestoreSchemaValidator.bookingWarnings(data: data, docID: doc.documentID))
                    let booking = Booking.fromFirestore(data, documentID: doc.documentID)
                    if booking == nil { droppedDocIDs.append(doc.documentID) }
                    return booking
                }
                #if DEBUG
                if !schemaWarnings.isEmpty {
                    print("BookingManager listener schema warnings (\(schemaWarnings.count)):\n- \(schemaWarnings.prefix(8).joined(separator: "\n- "))")
                }
                if !droppedDocIDs.isEmpty {
                    print("BookingManager listener dropped \(droppedDocIDs.count) booking docs due to parse mismatch. IDs: \(droppedDocIDs.prefix(8))")
                }
                #endif
                Task { @MainActor in
                    let loaded = parsed.filter { self.shouldKeepBookingLocally($0) }
                    self.applyBookingsSnapshot(loaded)
                }
            }
    }

    // MARK: - Parking Spots Listener (Firestore-driven)
    //
    // The full spot inventory lives in Firestore `parkingSpots` collection.
    // On first run (empty collection), spots are auto-seeded from AppConfig.allParkingSpots.
    // After that, add/remove/edit spots via Firebase console or admin dashboard.

    private func startSpotsListener() {
        spotsListener?.remove()
        spotsListener = db.collection("parkingSpots")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }

                // If collection is empty, seed it from the hardcoded defaults (one-time)
                if snapshot.documents.isEmpty {
                    Task { @MainActor in self.seedSpotsToFirestore() }
                    return  // listener will fire again after seed completes
                }

                var spots: [ParkingSpot] = []
                var blocked = Set<String>()
                var sortOrders: [String: Int] = [:]

                for doc in snapshot.documents {
                    let data = doc.data()
                    let id           = (data["id"] as? String) ?? doc.documentID
                    let label        = (data["label"] as? String) ?? "Parking \(id)"
                    let isAccessible = (data["isAccessible"] as? Bool) ?? false
                    let isBlocked    = (data["isBlocked"]    as? Bool) ?? false
                    sortOrders[id]   = ((data["sortOrder"] as? Int)
                                        ?? (data["sortOrder"] as? NSNumber)?.intValue
                                        ?? 999)

                    spots.append(ParkingSpot(id: id, label: label, isAccessible: isAccessible))
                    if isBlocked { blocked.insert(id) }
                }

                // Sort by sortOrder, falling back to numeric spot ID
                spots.sort { a, b in
                    let orderA = sortOrders[a.id] ?? 999
                    let orderB = sortOrders[b.id] ?? 999
                    if orderA != orderB { return orderA < orderB }
                    return (Int(a.id) ?? 999) < (Int(b.id) ?? 999)
                }

                Task { @MainActor in
                    self.applySpotsSnapshot(spots: spots, blocked: blocked)
                }
            }
    }

    func refreshData() async {
        // The live listeners already keep bookings/spots current in real time, so an
        // explicit getDocuments() here — called from many views' .task/.onAppear and
        // pull-to-refresh — was re-reading the WHOLE collections on every screen
        // appear/navigation. During the 18:00 rush that multiplied into a major read
        // amplifier. Only fetch when a listener isn't actually running.
        if bookingsListener == nil { await refreshBookings() }
        if spotsListener == nil { await refreshSpots() }
    }

    private func refreshBookings() async {
        do {
            let snapshot = try await recentBookingsQuery().getDocuments()

            var droppedDocIDs: [String] = []
            var schemaWarnings: [String] = []
            let loaded = snapshot.documents
                .compactMap { doc -> Booking? in
                    let data = doc.data()
                    schemaWarnings.append(contentsOf: FirestoreSchemaValidator.bookingWarnings(data: data, docID: doc.documentID))
                    let booking = Booking.fromFirestore(data, documentID: doc.documentID)
                    if booking == nil { droppedDocIDs.append(doc.documentID) }
                    return booking
                }
                .filter { shouldKeepBookingLocally($0) }
            #if DEBUG
            if !schemaWarnings.isEmpty {
                print("BookingManager refresh schema warnings (\(schemaWarnings.count)):\n- \(schemaWarnings.prefix(8).joined(separator: "\n- "))")
            }
            if !droppedDocIDs.isEmpty {
                print("BookingManager refresh dropped \(droppedDocIDs.count) booking docs due to parse mismatch. IDs: \(droppedDocIDs.prefix(8))")
            }
            #endif
            applyBookingsSnapshot(loaded)
        } catch {
            print("BookingManager refreshBookings error: \(error.localizedDescription)")
        }
    }

    func purgeOrphanedBookings() async -> Int {
        do {
            let snapshot = try await db.collection("bookings").getDocuments()
            var deleted = 0
            for doc in snapshot.documents {
                let data = doc.data()
                let booking = Booking.fromFirestore(data, documentID: doc.documentID)
                if booking == nil {
                    try await db.collection("bookings").document(doc.documentID).delete()
                    deleted += 1
                }
            }
            if deleted > 0 { await refreshData() }
            return deleted
        } catch {
            print("purgeOrphanedBookings error: \(error.localizedDescription)")
            return 0
        }
    }

    /// Deletes bookings older than `olderThanDays` days. The in-memory list only holds
    /// the last couple of days (see `shouldKeepLocally`), so it can't see old docs —
    /// we query the server directly with an inequality on `bookingDate`, then batch-
    /// delete. **Admin-only**: only an admin may delete other users' bookings under the
    /// Firestore rules, so this keeps the WHOLE collection trimmed, which is what keeps
    /// whole-collection reads cheap as the app scales. (Legacy bookings stored with a
    /// string `bookingDate` instead of a Timestamp won't match — they're a small fixed
    /// set, not the growing tail.) Costs reads only for the old docs being deleted.
    func purgeOldBookings(olderThanDays: Int = 2) async -> Int {
        guard isAdmin else { return 0 }
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -max(0, olderThanDays),
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()

        let docs: [QueryDocumentSnapshot]
        do {
            docs = try await db.collection("bookings")
                .whereField("bookingDate", isLessThan: Timestamp(date: cutoff))
                .getDocuments()
                .documents
        } catch {
            print("purgeOldBookings query error: \(error.localizedDescription)")
            return 0
        }
        guard !docs.isEmpty else { return 0 }

        var deleted = 0
        var index = 0
        while index < docs.count {
            let slice = docs[index..<min(index + 400, docs.count)] // Firestore batch cap = 500
            let batch = db.batch()
            for doc in slice { batch.deleteDocument(doc.reference) }
            do {
                try await batch.commit()
                deleted += slice.count
            } catch {
                print("purgeOldBookings batch error: \(error.localizedDescription)")
            }
            index += 400
        }
        return deleted
    }

    private func refreshSpots() async {
        do {
            let snapshot = try await db.collection("parkingSpots").getDocuments()

            if snapshot.documents.isEmpty {
                seedSpotsToFirestore()
                return
            }

            var spots: [ParkingSpot] = []
            var blocked = Set<String>()
            var sortOrders: [String: Int] = [:]

            for doc in snapshot.documents {
                let data = doc.data()
                let id           = (data["id"] as? String) ?? doc.documentID
                let label        = (data["label"] as? String) ?? "Parking \(id)"
                let isAccessible = (data["isAccessible"] as? Bool) ?? false
                let isBlocked    = (data["isBlocked"]    as? Bool) ?? false
                sortOrders[id]   = ((data["sortOrder"] as? Int)
                                    ?? (data["sortOrder"] as? NSNumber)?.intValue
                                    ?? 999)

                spots.append(ParkingSpot(id: id, label: label, isAccessible: isAccessible))
                if isBlocked { blocked.insert(id) }
            }

            spots.sort { a, b in
                let orderA = sortOrders[a.id] ?? 999
                let orderB = sortOrders[b.id] ?? 999
                if orderA != orderB { return orderA < orderB }
                return (Int(a.id) ?? 999) < (Int(b.id) ?? 999)
            }

            applySpotsSnapshot(spots: spots, blocked: blocked)
        } catch {
            print("BookingManager refreshSpots error: \(error.localizedDescription)")
        }
    }

    /// One-time seed: writes the hardcoded spot list to Firestore so it becomes the source of truth.
    /// Intentionally uses `baseParkingSpots` (the frozen init-time snapshot) — even if
    /// `AppConfig.allParkingSpots` is updated at runtime by the spots listener, the seed
    /// always writes the original hardcoded defaults (correct behavior on first run).
    private func seedSpotsToFirestore() {
        let batch = db.batch()
        for (index, spot) in baseParkingSpots.enumerated() {
            let ref = db.collection("parkingSpots").document(spot.id)
            batch.setData([
                "id":           spot.id,
                "label":        spot.label,
                "isAccessible": spot.isAccessible,
                "isBlocked":    false,
                "sortOrder":    index
            ], forDocument: ref)
        }
        batch.commit { error in
            if let error {
                print("BookingManager seedSpots error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Spot Cache (UserDefaults) for Offline Use

    /// Persist the live Firestore spot list locally so the app works correctly when offline.
    private func saveSpotsCache() {
        if let encoded = try? JSONEncoder().encode(parkingSpots) {
            UserDefaults.standard.set(encoded, forKey: "cachedParkingSpots")
        }
        UserDefaults.standard.set(Array(AppConfig.blockedSpotIDs), forKey: "cachedBlockedSpotIDs")
    }

    /// Load the spot cache on launch so the grid shows correctly before Firestore responds.
    private func loadSpotsCache() {
        if let data    = UserDefaults.standard.data(forKey: "cachedParkingSpots"),
           let decoded = try? JSONDecoder().decode([ParkingSpot].self, from: data),
           !decoded.isEmpty {
            parkingSpots = decoded
            AppConfig.allParkingSpots = decoded
        }
        if let blocked = UserDefaults.standard.array(forKey: "cachedBlockedSpotIDs") as? [String] {
            AppConfig.blockedSpotIDs = Set(blocked)
        }
        lastSpotsSignature = spotsSignature(spots: parkingSpots, blocked: AppConfig.blockedSpotIDs)
    }

    // MARK: - Notification Permission

    func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error { print("Notification permission error: \(error.localizedDescription)") }
                guard granted else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
    }

    // MARK: - One-time migration from old notification/UserDefaults keys

    private func migrateOldNotificationKeys() {
        // Remove stale UserDefaults keys from the old time-of-day reminder system
        let staleKeys = ["dailyReminderHour", "dailyReminderMinute"]
        staleKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        // Cancel any pending notifications that used the old "daily_reminder_" prefix
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let oldIDs = requests
                .filter { $0.identifier.hasPrefix("daily_reminder_") }
                .map(\.identifier)
            if !oldIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: oldIDs)
            }
        }
    }

    // MARK: - Booking Reminder (fires X minutes before booking start)

    private func notificationStateHash() -> String {
        let enabled = UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        guard enabled else { return "disabled" }
        let minutes = UserDefaults.standard.integer(forKey: "reminderMinutesBefore")
        let today = Calendar.current.startOfDay(for: Date())
        let ids = bookings
            .filter { $0.email == currentUserEmail && $0.date >= today }
            .map { "\($0.id.uuidString):\($0.fromTime)" }
            .sorted()
            .joined(separator: "|")
        return "\(minutes)|\(ids)"
    }

    func scheduleDailyReminders() {
        // Skip if nothing has changed — avoids redundant reschedules on every Firestore snapshot
        let newHash = notificationStateHash()
        guard newHash != lastReminderHash else { return }
        lastReminderHash = newHash

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("booking_reminder_") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            Task { @MainActor in self.scheduleRemindersIfEnabled() }
        }
    }

    private func scheduleRemindersIfEnabled() {
        guard UserDefaults.standard.bool(forKey: "dailyReminderEnabled") else { return }

        let minutesBefore = UserDefaults.standard.integer(forKey: "reminderMinutesBefore")
        // minutesBefore == 0 means notify at booking start time

        let calendar = Calendar.current
        let now      = Date()
        let today    = calendar.startOfDay(for: now)
        let myBookings = bookings.filter { $0.email == currentUserEmail && $0.date >= today }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for booking in myBookings {
            // Parse booking start time (e.g. "09:00") into hour + minute
            guard let startTime = timeFormatter.date(from: booking.fromTime) else { continue }
            let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
            guard let startHour = startComponents.hour,
                  let startMinute = startComponents.minute else { continue }

            // Build the booking start Date (date + time)
            var bookingStartComps = calendar.dateComponents([.year, .month, .day], from: booking.date)
            bookingStartComps.hour   = startHour
            bookingStartComps.minute = startMinute
            bookingStartComps.second = 0
            guard let bookingStart = calendar.date(from: bookingStartComps) else { continue }

            // Fire notification `minutesBefore` minutes before booking starts (0 = at start time)
            let fireDate = bookingStart.addingTimeInterval(TimeInterval(-minutesBefore * 60))

            // Skip if the fire time is already in the past
            guard fireDate > now else { continue }

            let dayLabel = reminderDayLabel(for: bookingStart, relativeTo: fireDate)
            let isTodayReminder = Calendar.current.isDate(bookingStart, inSameDayAs: fireDate)

            let content = UNMutableNotificationContent()
            content.title    = "Spot \(booking.spotNumber)"
            content.subtitle = "\(dayLabel) · \(booking.fromTime) – \(booking.toTime)"
            content.body     = AppConfig.locationName
            content.sound    = .default
            content.categoryIdentifier = NotificationHandler.bookingReminderCategory
            content.userInfo = [
                "bookingID": booking.id.uuidString,
                "isToday": isTodayReminder
            ]

            if let imageURL = NotificationCardRenderer.renderCardToFile(for: booking),
               let attachment = try? UNNotificationAttachment(
                   identifier: "card_\(booking.id.uuidString)",
                   url: imageURL,
                   options: [UNNotificationAttachmentOptionsThumbnailClippingRectKey:
                                CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation]
               ) {
                content.attachments = [attachment]
            }

            let fireDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: fireDateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "booking_reminder_\(booking.id.uuidString)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Resolves TODAY / TOMORROW labels relative to the reminder fire time.
    /// This avoids incorrect wording caused by static date labels.
    private func reminderDayLabel(for bookingStart: Date, relativeTo fireDate: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(bookingStart, inSameDayAs: fireDate) {
            return L10n.today.uppercased()
        }
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: fireDate)),
           calendar.isDate(bookingStart, inSameDayAs: nextDay) {
            return L10n.tomorrow.uppercased()
        }
        return bookingStart.formatNaturalShort().uppercased()
    }

    // MARK: - Lookup

    func bookingByID(_ idString: String) -> Booking? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return bookings.first { $0.id == uuid }
    }

    // MARK: - User Role Checks (Firestore-driven)

    var isAdmin: Bool {
        currentUserRole == .admin
    }

    /// Returns whether `email` has privileged or admin access.
    /// **Only works for `currentUserEmail`** — other users' roles are not cached locally.
    /// For current-user checks prefer the `isPrivileged` var.
    func isPrivilegedUser(_ email: String) -> Bool {
        if email == currentUserEmail {
            return currentUserRole == .privileged || currentUserRole == .admin
        }
        // Other users' roles aren't available locally; assume not privileged.
        return false
    }

    var isPrivileged: Bool { isPrivilegedUser(currentUserEmail) }

    var currentFirstName: String {
        let parts = currentUserName.split(separator: " ")
        return String(parts.first ?? Substring(currentUserName))
    }

    // MARK: - Booking Operations

    func createBooking(
        spotID:    String,
        spotLabel: String,
        userEmail: String,
        userName:  String,
        dateFrom:  Date,
        dateTo:    Date,
        timeFrom:  String,
        timeTo:    String
    ) async throws {
        let userEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCurrentUserEmail = currentUserEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: dateFrom)
        let endDate   = calendar.startOfDay(for: dateTo)
        let daysDiff  = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        guard daysDiff >= 0 else { throw BookingError.invalidDateRange }
        guard timeFrom < timeTo else { throw BookingError.invalidDuration }
        guard !AppConfig.blockedSpotIDs.contains(spotID) else { throw BookingError.spotBlocked }
        guard AppConfig.companyMayBook(spotID: spotID,
                                       company: currentUserCompany,
                                       isAdmin: isAdmin,
                                       bookingDate: startDate) else {
            throw BookingError.spotReservedForCompany
        }

        // All bookings in a multi-day range share a groupID so the share card can display the full range
        let rangeGroupID: UUID? = daysDiff > 0 ? UUID() : nil

        let isBookingForSelf = (userEmail == normalizedCurrentUserEmail)
        // Role-based booking window (matches firestore.rules bookingDateAllowedForActor):
        // admin = unlimited, privileged = today..+3, standard user = today (tomorrow only after 18:00).
        let maxAdvanceDays: Int
        if isAdmin {
            maxAdvanceDays = AppConfig.adminBookingMaxAdvanceDays
        } else if isPrivileged {
            maxAdvanceDays = AppConfig.othersBookingMaxAdvanceDays
        } else {
            maxAdvanceDays = Calendar.current.component(.hour, from: Date()) >= 18 ? 1 : 0
        }

        if !isBookingForSelf && !isAdmin && daysDiff + 1 > AppConfig.othersBookingMaxDurationDays {
            throw BookingError.invalidDuration
        }

        for dayOffset in 0...daysDiff {
            guard let bookingDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let advanceDays = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: Date()),
                to: bookingDate
            ).day ?? 0
            if advanceDays > maxAdvanceDays {
                throw BookingError.tooFarInAdvance
            }

            if isBookingForSelf && !isAdmin {
                let ownCount = BookingPolicy.bookingsForUserCount(
                    bookings,
                    email: currentUserEmail,
                    on: bookingDate,
                    calendar: calendar
                )
                if ownCount >= AppConfig.selfBookingMaxPerDay {
                    throw BookingError.maxPerDayReached
                }
            } else if !isBookingForSelf && !isAdmin {
                // Non-admin delegated: max 2 bookings created for others per day
                let delegatedCount = BookingPolicy.delegatedBookingCount(
                    bookings,
                    createdBy: currentUserEmail,
                    on: bookingDate,
                    calendar: calendar
                )
                if delegatedCount >= AppConfig.delegatedBookingMaxPerDay {
                    throw BookingError.maxDelegatedPerDayReached
                }
            }

            // ── Atomic conflict check via Firestore Transaction ─────────────────
            // Uses a "lock document" per spot+date (/spot_locks/{spotLabel}_{date}).
            // The transaction reads the lock, checks for time overlap, and writes
            // both the booking and updated lock atomically — zero race window.
            let dateString = {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: bookingDate)
            }()
            let lockRef    = db.collection("spot_locks").document("\(spotLabel)_\(dateString)")
            let bookingID  = UUID()
            let booking    = Booking(
                id:        bookingID,
                title:     "Reservation for \(userName)",
                spot:      spotLabel,
                user:      userName,
                email:     userEmail,
                date:      bookingDate,
                fromTime:  timeFrom,
                toTime:    timeTo,
                createdBy: currentUserEmail,
                groupID:   rangeGroupID
            )

            do {
                _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                    // 1) Read lock document (creates it if missing)
                    let lockSnap: DocumentSnapshot
                    do {
                        lockSnap = try transaction.getDocument(lockRef)
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }

                    // 2) Check existing slots for time overlap
                    let slots = lockSnap.data()?["slots"] as? [[String: String]] ?? []
                    for slot in slots {
                        if let sFrom = slot["from"], let sTo = slot["to"] {
                            if BookingPolicy.intervalsOverlap(startA: sFrom, endA: sTo, startB: timeFrom, endB: timeTo) {
                                errorPointer?.pointee = NSError(
                                    domain: "BookingConflict", code: 409,
                                    userInfo: [NSLocalizedDescriptionKey: "This spot is already booked for the selected time."]
                                )
                                return nil
                            }
                        }
                    }

                    // 3) No conflict — write booking + update lock atomically
                    let bookingRef = self.db.collection("bookings").document(bookingID.uuidString)
                    transaction.setData(booking.toFirestore(), forDocument: bookingRef)

                    var updatedSlots = slots
                    updatedSlots.append(["from": timeFrom, "to": timeTo, "bookingId": bookingID.uuidString])
                    transaction.setData(["slots": updatedSlots], forDocument: lockRef, merge: true)

                    return nil
                }
            } catch {
                throw mapFirestoreError(error)
            }

            bookings.append(booking)
        }

        afterBookingChange()
    }

    func updateBooking(
        bookingID:    UUID,
        newSpotLabel: String,
        newDate:      Date,
        newTimeFrom:  String,
        newTimeTo:    String
    ) async throws {
        guard let index = bookings.firstIndex(where: { $0.id == bookingID }) else {
            throw BookingError.bookingNotFound
        }

        let existing = bookings[index]
        // Guard: confirm the document still exists in Firestore before writing.
        // Prevents resurrecting a booking that was deleted externally (e.g. from console
        // or another device) during the window before the local listener caught up.
        let docRef = db.collection("bookings").document(bookingID.uuidString)
        let snap: DocumentSnapshot
        do {
            snap = try await docRef.getDocument()
        } catch {
            throw mapFirestoreError(error)
        }
        guard snap.exists else { throw BookingError.bookingNotFound }

        let updated = Booking(
            id:        bookingID,
            title:     existing.title,
            spot:      newSpotLabel,
            user:      existing.user,
            email:     existing.email,
            date:      newDate,
            fromTime:  newTimeFrom,
            toTime:    newTimeTo,
            createdBy: existing.createdBy,
            createdAt: existing.createdAt,
            groupID:   existing.groupID
        )

        // Update spot_lock: remove old slot from old lock, add new slot to new lock
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let oldLockRef = db.collection("spot_locks").document("\(existing.spot)_\(f.string(from: existing.date))")
        let newLockRef = db.collection("spot_locks").document("\(newSpotLabel)_\(f.string(from: newDate))")
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                let oldLockSnap: DocumentSnapshot
                let newLockSnap: DocumentSnapshot
                do {
                    oldLockSnap = try transaction.getDocument(oldLockRef)
                    newLockSnap = try transaction.getDocument(newLockRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                var oldSlots = oldLockSnap.data()?["slots"] as? [[String: String]] ?? []
                oldSlots.removeAll { $0["bookingId"] == bookingID.uuidString }

                if oldLockRef.path == newLockRef.path {
                    for slot in oldSlots {
                        guard let sFrom = slot["from"], let sTo = slot["to"] else { continue }
                        if BookingPolicy.intervalsOverlap(startA: sFrom, endA: sTo, startB: newTimeFrom, endB: newTimeTo) {
                            errorPointer?.pointee = NSError(
                                domain: "BookingConflict",
                                code: 409,
                                userInfo: [NSLocalizedDescriptionKey: "This spot is already booked for the selected time."]
                            )
                            return nil
                        }
                    }

                    oldSlots.append(["from": newTimeFrom, "to": newTimeTo, "bookingId": bookingID.uuidString])
                    transaction.setData(["slots": oldSlots], forDocument: oldLockRef, merge: true)
                } else {
                    let newSlots = newLockSnap.data()?["slots"] as? [[String: String]] ?? []
                    for slot in newSlots {
                        guard let sFrom = slot["from"], let sTo = slot["to"] else { continue }
                        if BookingPolicy.intervalsOverlap(startA: sFrom, endA: sTo, startB: newTimeFrom, endB: newTimeTo) {
                            errorPointer?.pointee = NSError(
                                domain: "BookingConflict",
                                code: 409,
                                userInfo: [NSLocalizedDescriptionKey: "This spot is already booked for the selected time."]
                            )
                            return nil
                        }
                    }

                    var targetSlots = newSlots
                    targetSlots.append(["from": newTimeFrom, "to": newTimeTo, "bookingId": bookingID.uuidString])
                    transaction.setData(["slots": oldSlots], forDocument: oldLockRef, merge: true)
                    transaction.setData(["slots": targetSlots], forDocument: newLockRef, merge: true)
                }

                transaction.setData(updated.toFirestore(), forDocument: docRef)
                return nil
            }
        } catch {
            throw mapFirestoreError(error)
        }

        bookings[index] = updated
        afterBookingChange()
    }

    /// Cancels a booking: removes from Firestore and local array.
    /// Returns an error string if the Firestore delete was rejected (e.g. rules), and
    /// restores the booking to the local array so the UI doesn't lie to the user.
    @discardableResult
    func cancelBooking(_ booking: Booking) async -> String? {
        // Optimistic removal
        bookings.removeAll { $0.id == booking.id }
        afterBookingChange()

        do {
            let bookingRefs = try await bookingDocumentReferences(for: booking)
            guard !bookingRefs.isEmpty else { throw BookingError.bookingNotFound }

            for ref in bookingRefs {
                try await ref.delete()
            }
            // Clean up spot lock only after confirmed delete
            await removeSlotLock(booking)
            return nil
        } catch {
            // Firestore rejected the delete — restore booking and report error
            bookings.append(booking)
            bookings.sort { $0.date < $1.date }
            afterBookingChange()
            return mapFirestoreError(error).localizedDescription
        }
    }

    /// Resolve the Firestore document(s) backing a booking.
    /// Primary path uses the modern document ID scheme; fallbacks cover legacy data.
    private func bookingDocumentReferences(for booking: Booking) async throws -> [DocumentReference] {
        let directRef = db.collection("bookings").document(booking.id.uuidString)
        if try await directRef.getDocument().exists {
            return [directRef]
        }

        let idMatches = try await db.collection("bookings")
            .whereField("id", isEqualTo: booking.id.uuidString)
            .getDocuments()
            .documents
            .map(\.reference)

        if !idMatches.isEmpty {
            return idMatches
        }

        let legacyMatches = try await db.collection("bookings")
            .whereField("email", isEqualTo: booking.email)
            .whereField("spot", isEqualTo: booking.spot)
            .whereField("bookingDate", isEqualTo: Timestamp(date: booking.date))
            .whereField("fromTime", isEqualTo: booking.fromTime)
            .whereField("toTime", isEqualTo: booking.toTime)
            .getDocuments()
            .documents
            .map(\.reference)

        return legacyMatches
    }

    /// Remove a booking's time slot from the spot lock document.
    private func removeSlotLock(_ booking: Booking) async {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let lockRef = db.collection("spot_locks").document("\(booking.spot)_\(f.string(from: booking.date))")
        guard let snap = try? await lockRef.getDocument(),
              var slots = snap.data()?["slots"] as? [[String: String]] else { return }
        slots.removeAll { $0["bookingId"] == booking.id.uuidString }
        try? await lockRef.setData(["slots": slots], merge: true)
    }

    func adminCancelBooking(_ booking: Booking, reason: String = "") async -> String? {
        var body = "Your booking for spot \(booking.spotNumber) on \(booking.naturalDate) was cancelled by an administrator."
        if !reason.isEmpty { body += " Reason: \(reason)" }
        PushNotificationManager.sendToUser(email: booking.email, title: "Booking Cancelled", body: body)

        AuditLogger.log(
            action: "admin_cancel_booking",
            detail: "Cancelled booking for \(booking.email) — spot \(booking.spotNumber) on \(booking.naturalDate)\(reason.isEmpty ? "" : " — reason: \(reason)")",
            performedBy: currentUserUID,
            targetUID: nil
        )

        return await cancelBooking(booking)
    }

    func canCancelBooking(_ booking: Booking) -> Bool {
        booking.email == currentUserEmail || booking.createdBy == currentUserEmail || isAdmin
    }

    func canEditBooking(_ booking: Booking) -> Bool {
        booking.email == currentUserEmail || booking.createdBy == currentUserEmail || isAdmin
    }

    // MARK: - Spot Management (admin)

    /// Write one or both spot flags to Firestore. The spotsListener picks up the change automatically.
    func updateSpot(id: String, isBlocked: Bool? = nil, isAccessible: Bool? = nil) {
        var data: [String: Any] = ["id": id]
        if let v = isBlocked    { data["isBlocked"]    = v }
        if let v = isAccessible { data["isAccessible"] = v }
        db.collection("parkingSpots").document(id).setData(data, merge: true)

        var changes: [String] = []
        if let v = isBlocked    { changes.append("isBlocked=\(v)") }
        if let v = isAccessible { changes.append("isAccessible=\(v)") }
        AuditLogger.log(
            action: "update_spot",
            detail: "Spot \(id): \(changes.joined(separator: ", "))",
            performedBy: currentUserUID
        )
    }

    // MARK: - Query Helpers

    func isSpotAvailable(
        spotLabel: String,
        on date: Date,
        timeFrom: String? = nil,
        timeTo: String? = nil,
        excludingBookingID: UUID? = nil
    ) -> Bool {
        let calendar = Calendar.current
        let targetSpotKey = normalizedSpotKey(spotLabel)
        return !bookings.contains {
            guard
                normalizedSpotKey($0.spot) == targetSpotKey,
                calendar.isDate($0.date, inSameDayAs: date),
                $0.id != excludingBookingID
            else { return false }

            guard let timeFrom, let timeTo else {
                return true
            }
            return BookingPolicy.intervalsOverlap(startA: $0.fromTime, endA: $0.toTime, startB: timeFrom, endB: timeTo)
        }
    }

    func getBookingsForUser(_ email: String) -> [Booking] {
        bookings.filter { $0.email == email }.sorted { $0.date < $1.date }
    }

    func getTodayBooking(for email: String) -> Booking? {
        let today = Calendar.current.startOfDay(for: Date())
        return bookings.first { $0.email == email && Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    func getNextUpcomingBooking(for email: String) -> Booking? {
        let today = Calendar.current.startOfDay(for: Date())
        return bookings
            .filter { $0.email == email && $0.date >= today }
            .sorted { $0.date < $1.date }
            .first
    }

    func getBookingForSpotOnDate(spotLabel: String, date: Date) -> Booking? {
        getBookingsForSpotOnDate(spotLabel: spotLabel, date: date).first
    }

    func getBookingsForSpotOnDate(spotLabel: String, date: Date) -> [Booking] {
        let calendar = Calendar.current
        let targetSpotKey = normalizedSpotKey(spotLabel)
        return bookings.filter {
            normalizedSpotKey($0.spot) == targetSpotKey &&
            calendar.isDate($0.date, inSameDayAs: date)
        }
        .sorted {
            if $0.fromTime == $1.fromTime { return $0.toTime < $1.toTime }
            return $0.fromTime < $1.fromTime
        }
    }

    func isSpotFullyOccupied(spotLabel: String, on date: Date, excludingBookingID: UUID? = nil) -> Bool {
        let dayBookings = getBookingsForSpotOnDate(spotLabel: spotLabel, date: date)
            .filter { $0.id != excludingBookingID }
        guard !dayBookings.isEmpty else { return false }

        let merged = mergedIntervals(from: dayBookings.map { (from: $0.fromTime, to: $0.toTime) })
        guard let first = merged.first else { return false }
        return first.from <= AppConfig.defaultTimeFrom
            && first.to >= AppConfig.fullDayOccupiedCutoffTime
            && merged.count == 1
    }

    func occupiedTimeRangesText(spotLabel: String, on date: Date, excludingBookingID: UUID? = nil) -> String? {
        let dayBookings = getBookingsForSpotOnDate(spotLabel: spotLabel, date: date)
            .filter { $0.id != excludingBookingID }
        guard !dayBookings.isEmpty else { return nil }
        let merged = mergedIntervals(from: dayBookings.map { (from: $0.fromTime, to: $0.toTime) })
        return merged.map { "\($0.from)-\($0.to)" }.joined(separator: ", ")
    }

    /// Free windows within the configured booking day for a given spot/date.
    func freeTimeRanges(
        spotLabel: String,
        on date: Date,
        excludingBookingID: UUID? = nil
    ) -> [(from: String, to: String)] {
        let dayStart = AppConfig.defaultTimeFrom
        let dayEnd = AppConfig.defaultTimeTo
        let dayBookings = getBookingsForSpotOnDate(spotLabel: spotLabel, date: date)
            .filter { $0.id != excludingBookingID }
        let merged = mergedIntervals(from: dayBookings.map { (from: $0.fromTime, to: $0.toTime) })

        guard !merged.isEmpty else { return [(from: dayStart, to: dayEnd)] }

        var ranges: [(from: String, to: String)] = []
        var cursor = dayStart

        for interval in merged {
            let start = max(interval.from, dayStart)
            let end = min(interval.to, dayEnd)
            if start >= end { continue }

            if cursor < start {
                ranges.append((from: cursor, to: start))
            }
            if end > cursor {
                cursor = end
            }
        }

        if cursor < dayEnd {
            ranges.append((from: cursor, to: dayEnd))
        }

        return ranges.filter { $0.from < $0.to }
    }

    /// Suggest best alternatives for current desired date/time.
    /// Priority:
    /// 1) Exact time match on another spot.
    /// 2) Longest free range that overlaps desired window.
    /// 3) Earliest free range for that day.
    func bookingSuggestions(
        on date: Date,
        desiredFrom: String,
        desiredTo: String,
        candidateSpots: [ParkingSpot],
        excludingBookingID: UUID? = nil,
        limit: Int = 5
    ) -> [BookingSuggestion] {
        guard desiredFrom < desiredTo else { return [] }

        let suggestions = candidateSpots.compactMap { spot -> (priority: Int, suggestion: BookingSuggestion)? in
            let ranges = freeTimeRanges(
                spotLabel: spot.label,
                on: date,
                excludingBookingID: excludingBookingID
            )
            guard !ranges.isEmpty else { return nil }

            if ranges.contains(where: { $0.from <= desiredFrom && $0.to >= desiredTo }) {
                return (
                    0,
                    BookingSuggestion(
                        spot: spot,
                        fromTime: desiredFrom,
                        toTime: desiredTo,
                        isExactTimeMatch: true
                    )
                )
            }

            if let overlap = ranges
                .map({ range in
                    let from = max(range.from, desiredFrom)
                    let to = min(range.to, desiredTo)
                    return (range: range, from: from, to: to)
                })
                .filter({ $0.from < $0.to })
                .max(by: { ($0.to, $0.from) < ($1.to, $1.from) }) {
                return (
                    1,
                    BookingSuggestion(
                        spot: spot,
                        fromTime: overlap.from,
                        toTime: overlap.to,
                        isExactTimeMatch: false
                    )
                )
            }

            guard let first = ranges.first else { return nil }
            return (
                2,
                BookingSuggestion(
                    spot: spot,
                    fromTime: first.from,
                    toTime: first.to,
                    isExactTimeMatch: false
                )
            )
        }

        return suggestions
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                if lhs.suggestion.spot.id != rhs.suggestion.spot.id {
                    return lhs.suggestion.spot.id < rhs.suggestion.spot.id
                }
                if lhs.suggestion.fromTime != rhs.suggestion.fromTime {
                    return lhs.suggestion.fromTime < rhs.suggestion.fromTime
                }
                return lhs.suggestion.toTime < rhs.suggestion.toTime
            }
            .map(\.suggestion)
            .prefix(limit)
            .map { $0 }
    }

    func bookingConflictExplanation(
        spot: ParkingSpot,
        on date: Date,
        timeFrom: String,
        timeTo: String,
        candidateSpots: [ParkingSpot],
        excludingBookingID: UUID? = nil
    ) -> String {
        let conflicts = getBookingsForSpotOnDate(spotLabel: spot.label, date: date)
            .filter { $0.id != excludingBookingID }
            .filter {
                BookingPolicy.intervalsOverlap(
                    startA: $0.fromTime,
                    endA: $0.toTime,
                    startB: timeFrom,
                    endB: timeTo
                )
            }

        var parts: [String] = []
        if conflicts.isEmpty {
            parts.append("Spot \(spot.id) is not available for \(timeFrom)-\(timeTo).")
        } else {
            let conflictText = conflicts.map {
                "\($0.firstName) has it \($0.fromTime)-\($0.toTime)"
            }
            .joined(separator: ", ")
            parts.append("Spot \(spot.id) conflicts: \(conflictText).")
        }

        let alternatives = bookingSuggestions(
            on: date,
            desiredFrom: timeFrom,
            desiredTo: timeTo,
            candidateSpots: candidateSpots.filter { $0.id != spot.id },
            excludingBookingID: excludingBookingID,
            limit: 3
        )

        if alternatives.isEmpty {
            parts.append("No close alternatives are free for this time window.")
        } else {
            let exact = alternatives.filter(\.isExactTimeMatch)
            let fallback = exact.isEmpty ? alternatives : exact
            let text = fallback.map { suggestion in
                "P\(suggestion.spot.id) \(suggestion.fromTime)-\(suggestion.toTime)"
            }
            .joined(separator: ", ")
            parts.append("Try \(text).")
        }

        return parts.joined(separator: " ")
    }

    func getBookingsForDate(_ date: Date) -> [Booking] {
        let calendar = Calendar.current
        return bookings.filter { calendar.isDate($0.date, inSameDayAs: date) }.sorted { $0.spot < $1.spot }
    }

    func getUserBookingsOnDate(_ date: Date, email: String) -> [Booking] {
        let calendar = Calendar.current
        return bookings.filter {
            $0.email == email && calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    func allBookingsGroupedBySpot(on date: Date) -> [(spot: ParkingSpot, booking: Booking?)] {
        parkingSpots.map { spot in
            (spot: spot, booking: getBookingForSpotOnDate(spotLabel: spot.label, date: date))
        }
    }

    /// Returns (startDate, endDate) for a grouped multi-day booking, or nil if single-day.
    func rangeFor(_ booking: Booking) -> (start: Date, end: Date)? {
        guard let gid = booking.groupID else { return nil }
        let siblings = bookings.filter { $0.groupID == gid }.sorted { $0.date < $1.date }
        guard siblings.count > 1,
              let first = siblings.first?.date,
              let last  = siblings.last?.date else { return nil }
        return (first, last)
    }

    func availableSpotsCount(on date: Date) -> Int {
        let visible = parkingSpots.filter {
            !AppConfig.blockedSpotIDs.contains($0.id)
                && AppConfig.spotVisible(spotID: $0.id,
                                         company: currentUserCompany,
                                         isAdmin: isAdmin,
                                         bookingDate: date)
        }
        let bookedKeys = Set(getBookingsForDate(date).map { normalizedSpotKey($0.spot) })
        return visible.filter { !bookedKeys.contains(normalizedSpotKey($0.label)) }.count
    }

    // MARK: - Post-Change Helpers

    private func afterBookingChange() {
        lastBookingsSignature = bookingsSignature(bookings)
        saveLocalCache()
        scheduleDailyReminders()
        updateWidgetData()
    }

    // MARK: - Widget Data

    func updateWidgetData() {
        let defaults = UserDefaults.appGroup

        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let now      = Date()
        let widgetEmail = currentUserEmail.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : currentUserEmail

        let candidateBookings = bookings
            .filter { $0.email == widgetEmail && $0.date >= today }
            .sorted { $0.date < $1.date }

        let selectedForWidget: Booking? = {
            guard !candidateBookings.isEmpty else { return nil }

            // 1) If any booking is active right now, show it.
            let activeToday = candidateBookings.first {
                calendar.isDateInToday($0.date) &&
                isTimeNowBetween(now: now, from: $0.fromTime, to: $0.toTime, on: $0.date)
            }
            if let activeToday { return activeToday }

            // 2) Otherwise, show next booking later today.
            let upcomingToday = candidateBookings
                .filter { calendar.isDateInToday($0.date) }
                .sorted {
                    bookingDateTime(for: $0.fromTime, on: $0.date) < bookingDateTime(for: $1.fromTime, on: $1.date)
                }
                .first {
                    bookingDateTime(for: $0.fromTime, on: $0.date) > now
                }
            if let upcomingToday { return upcomingToday }

            // 3) Fallback to earliest upcoming booking.
            return candidateBookings.first
        }()

        // Sync current user vehicle identity for dedicated vehicle widget.
        defaults.set(currentUserName, forKey: "widgetUserName")
        defaults.set(registrationPlate, forKey: "widgetVehiclePlate")
        defaults.set(carDescription, forKey: "widgetVehicleDescription")
        defaults.set(carColor, forKey: "widgetVehicleColor")
        defaults.set(carType, forKey: "widgetCarType")

        if let next = selectedForWidget {
            let widgetBooking = WidgetBookingData(
                id:          next.id.uuidString,
                spotNumber:  next.spotNumber,
                spotLabel:   next.spot,
                userName:    next.firstName,
                fromTime:    next.fromTime,
                toTime:      next.toTime,
                bookingDate: next.date,
                isToday:     calendar.isDateInToday(next.date)
            )
            if let encoded = try? JSONEncoder().encode(widgetBooking) {
                defaults.set(encoded, forKey: "widgetNextBooking")
            }
        } else {
            defaults.removeObject(forKey: "widgetNextBooking")
        }

        let todayBookedCount = Set(bookings.filter { calendar.isDate($0.date, inSameDayAs: today) }.map(\.spot)).count
        let totalSpots  = parkingSpots.count
        let blockedCount = AppConfig.blockedSpotIDs.count
        defaults.set(max(0, totalSpots - blockedCount - todayBookedCount), forKey: "widgetAvailableCount")
        defaults.set(totalSpots - blockedCount,                             forKey: "widgetTotalCount")

        WidgetCenter.shared.reloadAllTimelines()

        let vehicleCarType = carType
        let vehicleDescription = carDescription
        let vehicleColor = carColor
        let vehiclePresetID = vehicleMiniaturePresetID
        Task {
            let didUpdateMiniature = await renderAndSaveVehicleMiniature(
                carType: vehicleCarType,
                carDescription: vehicleDescription,
                carColor: vehicleColor,
                vehicleMiniaturePresetID: vehiclePresetID
            )
            if didUpdateMiniature {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private func renderAndSaveVehicleMiniature(
        carType: String,
        carDescription: String,
        carColor: String,
        vehicleMiniaturePresetID: String
    ) async -> Bool {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.StivMalakjan.EL-PARKING-APP"
        ) else { return false }

        let fileURL = containerURL.appendingPathComponent("vehicleMiniature.png")

        guard !carType.isEmpty || !carDescription.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            lastVehicleRenderHash = 0
            return true
        }

        await VehicleCatalogStore.shared.loadIfNeeded()

        var hasher = Hasher()
        hasher.combine(carType)
        hasher.combine(carDescription)
        hasher.combine(carColor)
        hasher.combine(vehicleMiniaturePresetID)
        hasher.combine(VehicleCatalogStore.shared.revision)
        let hash = hasher.finalize()
        guard hash != lastVehicleRenderHash else { return false }

        #if canImport(UIKit)
        guard let image = await VehicleMiniatureView.resolvedUIImageForRendering(
            carType: carType,
            description: carDescription,
            presetID: vehicleMiniaturePresetID.isEmpty ? nil : vehicleMiniaturePresetID
        ), let data = image.pngData() else {
            return false
        }

        try? data.write(to: fileURL)
        lastVehicleRenderHash = hash
        return true
        #else
        return false
        #endif
    }

    private func bookingDateTime(for time: String, on date: Date) -> Date {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return date
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }

    private func isTimeNowBetween(now: Date, from: String, to: String, on date: Date) -> Bool {
        let start = bookingDateTime(for: from, on: date)
        let end = bookingDateTime(for: to, on: date)
        return now >= start && now <= end
    }

    // MARK: - Local Cache (UserDefaults) for Offline / Widget

    private func saveLocalCache() {
        if let encoded = try? JSONEncoder().encode(bookings) {
            UserDefaults.standard.set(encoded, forKey: "bookings")
        }
    }

    private func loadLocalCache() {
        if let data    = UserDefaults.standard.data(forKey: "bookings"),
           let decoded = try? JSONDecoder().decode([Booking].self, from: data) {
            bookings = decoded
            lastBookingsSignature = bookingsSignature(decoded)
        }
    }

    // MARK: - User Profile

    func saveUserProfile() {
        UserDefaults.standard.set(registrationPlate, forKey: "registrationPlate")
        UserDefaults.standard.set(carDescription,    forKey: "carDescription")
        UserDefaults.standard.set(carColor,          forKey: "carColor")
        UserDefaults.standard.set(carType,           forKey: "carType")
        UserDefaults.standard.set(vehicleMiniaturePresetID, forKey: "vehicleMiniaturePresetID")
        UserDefaults.standard.set(preferredVocative, forKey: "preferredVocative")
        UserDefaults.standard.set(currentUserName,   forKey: "userName")
        UserDefaults.standard.set(currentUserEmail,  forKey: "userEmail")

        // Also sync to Firestore if we have a UID
        guard !currentUserUID.isEmpty else { return }
        db.collection("users").document(currentUserUID).updateData([
            "displayName":       currentUserName,
            "registrationPlate": registrationPlate,
            "carDescription":    carDescription,
            "carColor":          carColor,
            "carType":           carType,
            "vehicleMiniaturePresetID": vehicleMiniaturePresetID,
            "preferredVocative": preferredVocative
        ])
    }

    private func loadUserProfile() {
        registrationPlate = UserDefaults.standard.string(forKey: "registrationPlate") ?? ""
        carDescription    = UserDefaults.standard.string(forKey: "carDescription")    ?? ""
        carColor          = UserDefaults.standard.string(forKey: "carColor")          ?? ""
        carType           = UserDefaults.standard.string(forKey: "carType")           ?? ""
        vehicleMiniaturePresetID = UserDefaults.standard.string(forKey: "vehicleMiniaturePresetID") ?? ""
        preferredVocative = UserDefaults.standard.string(forKey: "preferredVocative") ?? ""
        let savedName     = UserDefaults.standard.string(forKey: "userName") ?? ""
        let savedEmail    = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        if !savedName.isEmpty  { currentUserName  = savedName }
        if !savedEmail.isEmpty { currentUserEmail = savedEmail }
    }

    private func mapFirestoreError(_ error: Error) -> Error {
        if let bookingError = error as? BookingError {
            return bookingError
        }

        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        if message.contains("insufficient permissions") || message.contains("missing or insufficient permissions") {
            return BookingError.unauthorized
        }

        return error
    }

    private func mergedIntervals(from intervals: [(from: String, to: String)]) -> [(from: String, to: String)] {
        let sorted = intervals.sorted { lhs, rhs in
            if lhs.from == rhs.from { return lhs.to < rhs.to }
            return lhs.from < rhs.from
        }
        guard var current = sorted.first else { return [] }

        var merged: [(from: String, to: String)] = []
        for next in sorted.dropFirst() {
            if next.from <= current.to {
                if next.to > current.to { current.to = next.to }
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        return merged
    }

    /// One-time Spark-safe backfill for legacy booking documents that don't have `expiresAt`.
    /// Intended to be triggered manually by an admin from the app UI.
    func backfillMissingBookingTTL() async -> BookingTTLBackfillResult {
        do {
            let snapshot = try await db.collection("bookings").getDocuments()
            let docs = snapshot.documents

            var updated = 0
            var skipped = 0
            var pendingWrites = 0
            var batch = db.batch()

            for doc in docs {
                let data = doc.data()

                // Already valid: keep as-is.
                if data["expiresAt"] is Timestamp { continue }

                guard
                    let bookingDate = parseBookingDateValue(data["bookingDate"]),
                    let toTime = data["toTime"] as? String
                else {
                    skipped += 1
                    continue
                }

                let end = bookingEndDate(for: bookingDate, toTime: toTime)
                let expiresAt = Calendar.current.date(
                    byAdding: .day,
                    value: AppConfig.bookingRetentionDays,
                    to: end
                ) ?? end

                batch.updateData(["expiresAt": Timestamp(date: expiresAt)], forDocument: doc.reference)
                updated += 1
                pendingWrites += 1

                // Firestore batch limit is 500 operations.
                if pendingWrites >= 400 {
                    try await batch.commit()
                    batch = db.batch()
                    pendingWrites = 0
                }
            }

            if pendingWrites > 0 {
                try await batch.commit()
            }

            return BookingTTLBackfillResult(scanned: docs.count, updated: updated, skipped: skipped)
        } catch {
            print("BookingManager backfillMissingBookingTTL error: \(error.localizedDescription)")
            return BookingTTLBackfillResult(scanned: 0, updated: 0, skipped: 0)
        }
    }

    /// Manual admin cleanup for Spark plan: hard-delete bookings older than retention window.
    func hardDeleteExpiredBookings() async -> ExpiredBookingCleanupResult {
        do {
            let snapshot = try await db.collection("bookings").getDocuments()
            let docs = snapshot.documents

            var deleted = 0
            var skipped = 0
            var pendingWrites = 0
            let cutoff = retentionCutDate()
            var batch = db.batch()

            for doc in docs {
                guard let booking = Booking.fromFirestore(doc.data(), documentID: doc.documentID) else {
                    skipped += 1
                    continue
                }

                let endDate = bookingEndDate(booking)
                guard endDate < cutoff else { continue }

                batch.deleteDocument(doc.reference)
                deleted += 1
                pendingWrites += 1

                if pendingWrites >= 400 {
                    try await batch.commit()
                    batch = db.batch()
                    pendingWrites = 0
                }
            }

            if pendingWrites > 0 {
                try await batch.commit()
            }

            await refreshBookings()
            return ExpiredBookingCleanupResult(scanned: docs.count, deleted: deleted, skipped: skipped)
        } catch {
            print("BookingManager hardDeleteExpiredBookings error: \(error.localizedDescription)")
            return ExpiredBookingCleanupResult(scanned: 0, deleted: 0, skipped: 0)
        }
    }

    private func parseBookingDateValue(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }

        guard let string = value as? String else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private func bookingEndDate(for date: Date, toTime: String) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let parts = toTime.split(separator: ":")
        let hour = Int(parts.first ?? "") ?? 23
        let minute = Int(parts.dropFirst().first ?? "") ?? 59
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0
        return calendar.date(from: dateComponents) ?? date
    }

    private func shouldKeepBookingLocally(_ booking: Booking) -> Bool {
        BookingPolicy.shouldKeepLocally(booking)
    }

    private func retentionCutDate() -> Date {
        BookingPolicy.retentionCutDate()
    }

    private func bookingEndDate(_ booking: Booking) -> Date {
        BookingPolicy.bookingEndDate(date: booking.date, toTime: booking.toTime)
    }

    private func recentBookingsQuery() -> Query {
        // Intentionally no server-side bookingDate filter:
        // Firestore comparisons are type-strict and can exclude legacy/imported
        // docs where bookingDate is a "yyyy-MM-dd" string instead of Timestamp.
        // We parse both shapes in Booking.fromFirestore and filter locally via
        // shouldKeepBookingLocally(_:) to keep iOS/Android occupancy in sync.
        db.collection("bookings")
    }

    private func applyBookingsSnapshot(_ loaded: [Booking]) {
        let sorted = loaded.sorted { $0.date < $1.date }
        let signature = bookingsSignature(sorted)
        guard signature != lastBookingsSignature else { return }
        lastBookingsSignature = signature
        bookings = sorted
        saveLocalCache()
        updateWidgetData()
        scheduleDailyReminders()
        runSessionPurgeIfNeeded()
    }

    /// Per-session housekeeping: once per app launch, after bookings have loaded,
    /// delete old bookings this user is allowed to remove (their own for a regular/
    /// privileged user; everything for an admin). Runs off the already-loaded list —
    /// no extra reads. This keeps the shared `bookings` collection small as users
    /// open the app, so whole-collection reads stay cheap at scale (no TTL needed).
    private var didRunSessionPurge = false
    private func runSessionPurgeIfNeeded() {
        guard !didRunSessionPurge, isAdmin else { return }
        didRunSessionPurge = true
        Task { [weak self] in _ = await self?.purgeOldBookings() }
    }

    private func applySpotsSnapshot(spots: [ParkingSpot], blocked: Set<String>) {
        let signature = spotsSignature(spots: spots, blocked: blocked)
        guard signature != lastSpotsSignature else { return }
        lastSpotsSignature = signature
        AppConfig.blockedSpotIDs = blocked
        AppConfig.allParkingSpots = spots
        parkingSpots = spots
        saveSpotsCache()
        updateWidgetData()
    }

    private func bookingsSignature(_ items: [Booking]) -> Int {
        var hasher = Hasher()
        hasher.combine(items.count)
        for booking in items {
            hasher.combine(booking.id)
            hasher.combine(booking.spot)
            hasher.combine(booking.email)
            hasher.combine(booking.date.timeIntervalSinceReferenceDate)
            hasher.combine(booking.fromTime)
            hasher.combine(booking.toTime)
            hasher.combine(booking.createdBy)
            hasher.combine(booking.groupID)
        }
        return hasher.finalize()
    }

    /// Canonical spot key shared across UI/data paths so `75`, `P75`, and
    /// `Parking 75` are treated as the same logical spot.
    func normalizedSpotKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = trimmed.range(of: #"\d+"#, options: .regularExpression) {
            return String(trimmed[match])
        }
        return trimmed.lowercased()
    }

    private func spotsSignature(spots: [ParkingSpot], blocked: Set<String>) -> Int {
        var hasher = Hasher()
        hasher.combine(spots.count)
        for spot in spots {
            hasher.combine(spot.id)
            hasher.combine(spot.label)
            hasher.combine(spot.isAccessible)
        }
        for id in blocked.sorted() {
            hasher.combine(id)
        }
        return hasher.finalize()
    }
}

// MARK: - Booking Errors

enum BookingError: LocalizedError {
    case conflict
    case invalidDateRange
    case invalidDuration
    case tooFarInAdvance
    case spotBlocked
    case bookingNotFound
    case spotNotAvailable
    case unauthorized
    case maxPerDayReached
    case maxDelegatedPerDayReached
    case spotReservedForCompany

    var errorDescription: String? {
        switch self {
        case .conflict:          return "This spot is already booked for the selected time."
        case .invalidDateRange:  return "Invalid date range."
        case .invalidDuration:   return "The booking duration exceeds the maximum allowed."
        case .tooFarInAdvance:   return "You cannot book this far in advance."
        case .spotBlocked:       return "This spot is temporarily blocked and cannot be booked."
        case .bookingNotFound:   return "Booking not found."
        case .spotNotAvailable:  return "Parking spot is not available for the selected time."
        case .unauthorized:      return "You don't have permission to perform this action."
        case .maxPerDayReached:
            return "You can only book 1 spot per day. Contact \(AppConfig.adminContactEmail) for additional spots."
        case .maxDelegatedPerDayReached:
            return L10n.maxDelegatedPerDayError
        case .spotReservedForCompany:
            return L10n.spotReservedForCompanyError
        }
    }
}

// MARK: - Booking Firestore Extension

extension Booking {
    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "id":          id.uuidString,
            "title":       title,
            "spot":        spot,
            "user":        user,
            "email":       email,
            "bookingDate": Timestamp(date: date),
            "fromTime":    fromTime,
            "toTime":      toTime,
            "createdBy":   createdBy,
            "createdAt":   Timestamp(date: createdAt),
            "expiresAt":   Timestamp(date: ttlExpirationDate())
        ]
        if let gid = groupID { dict["groupID"] = gid.uuidString }
        return dict
    }

    nonisolated static func fromFirestore(_ data: [String: Any], documentID: String? = nil) -> Booking? {
        guard
            let rawID = (data["id"] as? String) ?? documentID,
            let bookingDate = bookingDate(from: data["bookingDate"])
        else { return nil }

        guard
            let spotRaw = (data["spot"] as? String) ?? (data["spotLabel"] as? String),
            let emailRaw = (data["email"] as? String) ?? (data["userEmail"] as? String)
        else { return nil }

        let spot = spotRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = emailRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !spot.isEmpty, !email.isEmpty else { return nil }

        let fromTime = (data["fromTime"] as? String)
            ?? (data["from"] as? String)
            ?? (data["timeFrom"] as? String)
            ?? "07:00"
        let toTime = (data["toTime"] as? String)
            ?? (data["to"] as? String)
            ?? (data["timeTo"] as? String)
            ?? "18:00"
        let rawUser = ((data["user"] as? String) ?? (data["displayName"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let user = rawUser.isEmpty ? inferredUserName(from: data["title"] as? String, email: email) : rawUser
        let rawCreator = (data["createdBy"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            ?? ((data["adminEmail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")
        let createdBy = rawCreator.isEmpty ? email : rawCreator
        let rawTitle = ((data["title"] as? String) ?? (data["bookingTitle"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.isEmpty ? "Reservation for \(user)" : rawTitle

        let id = UUID(uuidString: rawID) ?? stableUUID(from: rawID)
        let groupID = (data["groupID"] as? String).flatMap { UUID(uuidString: $0) }
        return Booking(
            id:        id,
            title:     title,
            spot:      spot,
            user:      user,
            email:     email,
            date:      bookingDate,
            fromTime:  fromTime,
            toTime:    toTime,
            createdBy: createdBy,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            groupID:   groupID
        )
    }

    nonisolated private static func inferredUserName(from title: String?, email: String) -> String {
        if let title {
            let cleaned = title
                .replacingOccurrences(of: "Reservation for ", with: "")
                .replacingOccurrences(of: "Rezervace pro ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { return cleaned }
        }
        return email.components(separatedBy: "@").first ?? email
    }

    nonisolated private static func bookingDate(from value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }

        if let date = value as? Date {
            return date
        }

        if let numeric = value as? NSNumber {
            let raw = numeric.doubleValue
            // Heuristic: millisecond epoch values are > 1e12 in modern dates.
            return raw > 1_000_000_000_000 ? Date(timeIntervalSince1970: raw / 1000.0) : Date(timeIntervalSince1970: raw)
        }

        guard let string = value as? String else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    nonisolated private static func stableUUID(from source: String) -> UUID {
        let digest = SHA256.hash(data: Data(source.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func ttlExpirationDate() -> Date {
        let end = bookingEndDate
        return Calendar.current.date(byAdding: .day, value: AppConfig.bookingRetentionDays, to: end) ?? end
    }

    private var bookingEndDate: Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        let parts = toTime.split(separator: ":")
        let hour = Int(parts.first ?? "") ?? 23
        let minute = Int(parts.dropFirst().first ?? "") ?? 59
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        return calendar.date(from: dateComponents) ?? date
    }
}
