//
//  BookFavoriteSpotIntent.swift
//  EL PARKING APP
//
//  App Intent for booking a parking spot via Siri / Shortcuts.
//  Runs entirely in the background — no app launch required.
//
//  Priority order for which spot to try first:
//    1. Preferred Spot parameter (set in the Shortcuts action)
//    2. Favourite spot saved in Settings
//    3. Any remaining free spot
//

import AppIntents
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

// MARK: - Parking Spot Entity (lets Shortcuts show a real spot picker)

@available(iOS 16.0, *)
struct ParkingSpotEntity: AppEntity {
    let id: String
    let label: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Parking Spot"
    static var defaultQuery = ParkingSpotEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: label))
    }
}

@available(iOS 16.0, *)
struct ParkingSpotEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ParkingSpotEntity] {
        let spots = await MainActor.run { AppConfig.allParkingSpots }
        return spots.filter { identifiers.contains($0.id) }
                    .map { ParkingSpotEntity(id: $0.id, label: $0.label) }
    }

    func suggestedEntities() async throws -> [ParkingSpotEntity] {
        let spots = await MainActor.run { AppConfig.allParkingSpots }
        return spots.map { ParkingSpotEntity(id: $0.id, label: $0.label) }
    }
}

// MARK: - Day Picker Enum

@available(iOS 16.0, *)
enum BookingDay: String, AppEnum {
    case today    = "Today"
    case tomorrow = "Tomorrow"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Day")
    static var caseDisplayRepresentations: [BookingDay: DisplayRepresentation] = [
        .today:    "Today",
        .tomorrow: "Tomorrow"
    ]
}

// MARK: - Book a Spot Intent

@available(iOS 16.0, *)
struct BookParkingSpotIntent: AppIntent {
    static var title: LocalizedStringResource = "Book a Spot"
    static var description = IntentDescription("Books a free parking spot for the chosen day using EL Parking.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Day", default: .tomorrow)
    var day: BookingDay

    /// Optional — if set, this spot is tried first before falling back to the
    /// favourite set in Settings, and then to any other free spot.
    @Parameter(title: "Preferred Spot")
    var preferredSpot: ParkingSpotEntity?

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        do {
            return try await _perform()
        } catch let known as IntentError {
            throw known
        } catch {
            throw IntentError.bookingFailed(error.localizedDescription)
        }
    }

    // MARK: - Core Logic

    private func _perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }

        let (allSpots, defaultFrom, defaultTo, retentionDays,
             storedEmail, storedName, settingsFavouriteID, storedFrom, storedTo) = await MainActor.run {
            let d = UserDefaults.appGroup
            return (
                AppConfig.allParkingSpots,
                AppConfig.defaultTimeFrom,
                AppConfig.defaultTimeTo,
                AppConfig.bookingRetentionDays,
                d.string(forKey: "currentUserEmail") ?? "",
                d.string(forKey: "currentUserName")  ?? "",
                d.string(forKey: "favoriteSpotID")   ?? "",
                d.string(forKey: "favoriteFromTime"),
                d.string(forKey: "favoriteToTime")
            )
        }

        // 1. Auth
        guard let user = await waitForAuthUser() else { throw IntentError.notLoggedIn }
        let email = user.email ?? storedEmail
        guard !email.isEmpty else { throw IntentError.notLoggedIn }

        // 2. Force-refresh token so Firestore security rules accept it
        _ = try? await user.getIDToken(forcingRefresh: true)

        // 3. Display name
        let db = Firestore.firestore()
        let userDoc = try? await db.collection("users").document(user.uid).getDocument()
        let userName = userDoc?.data()?["name"] as? String
            ?? (storedName.isEmpty ? email : storedName)

        await MainActor.run {
            let d = UserDefaults.appGroup
            d.set(user.uid, forKey: "currentUserUID")
            d.set(email,    forKey: "currentUserEmail")
            d.set(userName, forKey: "currentUserName")
        }

        // 4. Target date
        let calendar = Calendar.current
        let baseDate  = day == .tomorrow
            ? calendar.date(byAdding: .day, value: 1, to: Date())!
            : Date()
        let targetDate = calendar.startOfDay(for: baseDate)
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let dateString = df.string(from: targetDate)
        let dayLabel   = day == .tomorrow ? "tomorrow" : "today"

        // 5. Time window
        let fromTime = storedFrom ?? defaultFrom
        let toTime   = storedTo   ?? defaultTo

        // 6. Build candidate list with priority:
        //    a) Shortcuts parameter spot (if set)
        //    b) Settings favourite spot (if set)
        //    c) All remaining spots in order
        var priorityIDs: [String] = []
        if let paramSpot = preferredSpot { priorityIDs.append(paramSpot.id) }
        if !settingsFavouriteID.isEmpty && !priorityIDs.contains(settingsFavouriteID) {
            priorityIDs.append(settingsFavouriteID)
        }
        var candidates = priorityIDs.compactMap { id in allSpots.first { $0.id == id } }
        for spot in allSpots where !priorityIDs.contains(spot.id) {
            candidates.append(spot)
        }

        // 7. Try each until one succeeds
        for spot in candidates {
            do {
                try await bookSpot(
                    spot: spot, fromTime: fromTime, toTime: toTime,
                    dateString: dateString, targetDate: targetDate,
                    userName: userName, email: email,
                    retentionDays: retentionDays, db: db
                )
                let isParam = spot.id == preferredSpot?.id
                let isFav   = spot.id == settingsFavouriteID
                let tag     = isParam ? " (preferred)" : isFav ? " (favourite)" : ""
                return .result(
                    value: "confirmed",
                    dialog: IntentDialog(stringLiteral:
                        "\(spot.label)\(tag) booked for \(dayLabel), \(fromTime)–\(toTime). Done!")
                )
            } catch let err as NSError where err.domain == "BookingConflict" {
                continue
            }
        }

        return .result(
            value: "conflict",
            dialog: IntentDialog(stringLiteral:
                "All spots are already taken for \(dayLabel), \(fromTime)–\(toTime).")
        )
    }

    // MARK: - Helpers

    private func waitForAuthUser() async -> FirebaseAuth.User? {
        for _ in 0..<30 {
            if let user = Auth.auth().currentUser { return user }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return Auth.auth().currentUser
    }

    private func bookSpot(
        spot: ParkingSpot, fromTime: String, toTime: String,
        dateString: String, targetDate: Date,
        userName: String, email: String,
        retentionDays: Int, db: Firestore
    ) async throws {
        let bookingID = UUID()
        let expiresAt = Calendar.current.date(byAdding: .day, value: retentionDays, to: targetDate) ?? targetDate
        let lockRef    = db.collection("spot_locks").document("\(spot.label)_\(dateString)")
        let bookingRef = db.collection("bookings").document(bookingID.uuidString)
        let bookingData: [String: Any] = [
            "id":          bookingID.uuidString,
            "title":       "Reservation for \(userName)",
            "spot":        spot.label,
            "user":        userName,
            "email":       email,
            "bookingDate": Timestamp(date: targetDate),
            "fromTime":    fromTime,
            "toTime":      toTime,
            "createdBy":   email,
            "createdAt":   Timestamp(date: Date()),
            "expiresAt":   Timestamp(date: expiresAt)
        ]
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let lockSnap: DocumentSnapshot
            do { lockSnap = try transaction.getDocument(lockRef) } catch {
                errorPointer?.pointee = error as NSError; return nil
            }
            let slots = lockSnap.data()?["slots"] as? [[String: String]] ?? []
            for slot in slots {
                if let sFrom = slot["from"], let sTo = slot["to"],
                   sFrom < toTime && sTo > fromTime {
                    errorPointer?.pointee = NSError(
                        domain: "BookingConflict", code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "\(spot.label) taken."]
                    )
                    return nil
                }
            }
            transaction.setData(bookingData, forDocument: bookingRef)
            var updated = slots
            updated.append(["from": fromTime, "to": toTime, "bookingId": bookingID.uuidString])
            transaction.setData(["slots": updated], forDocument: lockRef, merge: true)
            return nil
        }
    }

    // MARK: - Errors

    enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
        case notLoggedIn
        case bookingFailed(String)
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .notLoggedIn:            return "Not signed in. Open EL Parking first."
            case .bookingFailed(let msg): return "Booking failed: \(msg)"
            }
        }
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.4, *)
struct ELParkingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BookParkingSpotIntent(),
            phrases: [
                "Book a parking spot in \(.applicationName)",
                "Book a spot in \(.applicationName)",
                "Reserve parking in \(.applicationName)"
            ],
            shortTitle: "Book a Spot",
            systemImageName: "parkingsign.circle.fill"
        )
    }
}
