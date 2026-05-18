//
//  ParkKingApp.swift
//  EL PARKING APP
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UIKit
import UserNotifications

private enum FirebaseBootstrap {
    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}

// MARK: - AppDelegate (configures Firebase before any StateObjects are created)

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    private(set) var pendingQuickActionType: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()
        application.shortcutItems = AppQuickAction.shortcutItems
        Messaging.messaging().delegate = self
        registerForRemoteNotificationsIfAuthorized(application)

        // iOS 26 deprecates LaunchOptionsKey.shortcutItem in favor of scene connection options.
        // Keep backward-compatible cold-launch support by reading the raw launch option key.
        let shortcutLaunchKey = UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsShortcutItemKey")
        if let shortcutItem = launchOptions?[shortcutLaunchKey] as? UIApplicationShortcutItem {
            pendingQuickActionType = shortcutItem.type
            // Returning false prevents a duplicate callback to performAction.
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        NotificationCenter.default.post(
            name: .appQuickActionTriggered,
            object: shortcutItem.type
        )
        completionHandler(true)
    }

    func consumePendingQuickActionType() -> String? {
        defer { pendingQuickActionType = nil }
        return pendingQuickActionType
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
        upsertFCMToken(token)
    }

    func syncMessagingTokenToCurrentUser() {
        Messaging.messaging().token { [weak self] token, error in
            guard error == nil,
                  let token = token?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty else { return }
            self?.upsertFCMToken(token)
        }
    }

    private func registerForRemoteNotificationsIfAuthorized(_ application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            default:
                break
            }
        }
    }

    private func upsertFCMToken(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let payload: [String: Any] = [
            "fcmTokens": FieldValue.arrayUnion([token]),
            "lastFCMToken": token,
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
        ]
        Firestore.firestore().collection("users").document(uid).setData(payload, merge: true) { error in
            if let error {
                print("FCM token sync failed: \(error.localizedDescription)")
            }
        }
    }
}

private enum AppQuickAction {
    static let bookType = "com.elparking.quickaction.book"
    static let myBookingsType = "com.elparking.quickaction.mybookings"
    static let cancelType = "com.elparking.quickaction.cancel"
    static let navigateType = "com.elparking.quickaction.navigate"
    static let adminType = "com.elparking.quickaction.admin"
    static let bookNextType = "com.elparking.quickaction.booknext"

    enum ContextualAction {
        case adminDashboard
        case navigate
        case bookNextAvailable
    }

    static var shortcutItems: [UIApplicationShortcutItem] {
        shortcutItems(includeCancel: false, contextualAction: .bookNextAvailable)
    }

    static func shortcutItems(includeCancel: Bool, contextualAction: ContextualAction) -> [UIApplicationShortcutItem] {
        var items: [UIApplicationShortcutItem] = [
            UIApplicationShortcutItem(
                type: bookType,
                localizedTitle: "Book a Spot",
                localizedSubtitle: "Open booking sheet",
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: myBookingsType,
                localizedTitle: "My Bookings",
                localizedSubtitle: "See upcoming bookings",
                icon: UIApplicationShortcutIcon(systemImageName: "bookmark"),
                userInfo: nil
            )
        ]

        if includeCancel {
            items.append(
                UIApplicationShortcutItem(
                    type: cancelType,
                    localizedTitle: "Cancel Booking",
                    localizedSubtitle: "Open bookings to cancel",
                    icon: UIApplicationShortcutIcon(systemImageName: "xmark.circle"),
                    userInfo: nil
                )
            )
        }

        switch contextualAction {
        case .adminDashboard:
            items.append(
                UIApplicationShortcutItem(
                    type: adminType,
                    localizedTitle: "Admin Dashboard",
                    localizedSubtitle: "Open admin controls",
                    icon: UIApplicationShortcutIcon(systemImageName: "shield.lefthalf.filled"),
                    userInfo: nil
                )
            )
        case .navigate:
            items.append(
                UIApplicationShortcutItem(
                    type: navigateType,
                    localizedTitle: "Navigate to Parking",
                    localizedSubtitle: "Open directions",
                    icon: UIApplicationShortcutIcon(systemImageName: "location.fill.viewfinder"),
                    userInfo: nil
                )
            )
        case .bookNextAvailable:
            items.append(
                UIApplicationShortcutItem(
                    type: bookNextType,
                    localizedTitle: "Book Next Available",
                    localizedSubtitle: "Start quick booking",
                    icon: UIApplicationShortcutIcon(systemImageName: "calendar.badge.plus"),
                    userInfo: nil
                )
            )
        }

        return items
    }

    static func route(for type: String) -> DeepLinkRoute? {
        switch type {
        case bookType:
            return .book
        case myBookingsType:
            return .myBookings
        case cancelType:
            // Quick action has no booking ID; route users to the cancellation surface.
            return .myBookings
        case navigateType:
            return .navigate
        case adminType:
            return .adminDashboard
        case bookNextType:
            return .book
        default:
            return nil
        }
    }
}

// MARK: - Shake Detection

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

// MARK: - App Entry Point

@main
struct ParkKingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var bookingManager: BookingManager
    @StateObject private var authManager: AuthManager
    @StateObject private var announcementsManager: AnnouncementsManager
    @StateObject private var infoManager: InfoManager
    @StateObject private var pushManager: PushNotificationManager
    @StateObject private var deepLinkManager: DeepLinkManager
    @AppStorage("appTheme") private var themeRaw: Int = 0
    private let proximityReminderManager = ProximityReminderManager.shared

    /// Booking to open in edit sheet via notification/deep link
    @State private var notificationEditBooking:     Booking?
    @State private var showNotificationEditSheet   = false
    @State private var notificationCancelBooking:   Booking?
    @State private var showNotificationCancelAlert = false

    private var colorScheme: ColorScheme? {
        (AppTheme(rawValue: themeRaw) ?? .system).colorScheme
    }

    init() {
        FirebaseBootstrap.configureIfNeeded()
        _bookingManager = StateObject(wrappedValue: BookingManager())
        _authManager = StateObject(wrappedValue: AuthManager())
        _announcementsManager = StateObject(wrappedValue: AnnouncementsManager())
        _infoManager = StateObject(wrappedValue: InfoManager())
        _pushManager = StateObject(wrappedValue: PushNotificationManager())
        _deepLinkManager = StateObject(wrappedValue: DeepLinkManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookingManager)
                .environmentObject(authManager)
                .environmentObject(announcementsManager)
                .environmentObject(infoManager)
                .environmentObject(deepLinkManager)
                .environmentObject(LanguageManager.shared)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    NotificationHandler.shared.registerCategories()
                    bookingManager.scheduleDailyReminders()
                    if authManager.currentUser?.isActive == true {
                        proximityReminderManager.configure(with: bookingManager)
                    }
                    // bookingManager.scheduleLiveActivities()  // Live Activity disabled
                    updateQuickActions()

                    if let type = appDelegate.consumePendingQuickActionType(),
                       let route = AppQuickAction.route(for: type) {
                        deepLinkManager.navigate(to: route)
                    }
                }
                // Bridge: when auth changes, configure BookingManager + push notifications for the user
                .onChange(of: authManager.currentUser) { _, user in
                    if let user, user.isActive {
                        bookingManager.configureForUser(
                            email:   user.email,
                            name:    user.displayName,
                            uid:     user.uid,
                            role:    user.role,
                            plate:   user.registrationPlate,
                            car:     user.carDescription,
                            color:   user.carColor,
                            carType: user.carType,
                            vehicleMiniaturePresetID: user.vehicleMiniaturePresetID,
                            preferredVocative: user.preferredVocative
                        )
                        pushManager.startListening(for: user.uid)
                        appDelegate.syncMessagingTokenToCurrentUser()
                        proximityReminderManager.configure(with: bookingManager)
                    } else if user == nil {
                        bookingManager.clearUser()
                        pushManager.stopListening()
                        proximityReminderManager.clear()
                    }
                    updateQuickActions()
                }
                .onChange(of: bookingManager.bookings.count) { _, _ in
                    updateQuickActions()
                }
                // Handle notification actions
                .onReceive(
                    NotificationCenter.default.publisher(for: NotificationHandler.editBookingNotification)
                ) { notification in
                    if let idString = notification.userInfo?["bookingID"] as? String,
                       let booking  = bookingManager.bookingByID(idString) {
                        notificationEditBooking   = booking
                        showNotificationEditSheet = true
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: NotificationHandler.cancelBookingNotification)
                ) { notification in
                    if let idString = notification.userInfo?["bookingID"] as? String,
                       let booking  = bookingManager.bookingByID(idString) {
                        notificationCancelBooking   = booking
                        showNotificationCancelAlert = true
                    }
                }
                // Handle deep links from widgets (elparking://edit/UUID, elparking://cancel/UUID)
                .onOpenURL { url in
                    deepLinkManager.handle(url)
                    Task { await bookingManager.refreshData() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .appQuickActionTriggered)) { notification in
                    guard let type = notification.object as? String,
                          let route = AppQuickAction.route(for: type) else { return }
                    deepLinkManager.navigate(to: route)
                }
                .sheet(isPresented: $showNotificationEditSheet) {
                    if let booking = notificationEditBooking {
                        BookingSheet(
                            preselectedSpot: AppConfig.allParkingSpots.first(where: { $0.label == booking.spot }),
                            isForOthers:     booking.email != bookingManager.currentUserEmail,
                            editingBooking:  booking
                        )
                        .environmentObject(bookingManager)
                    }
                }
                .alert(L10n.cancelBooking, isPresented: $showNotificationCancelAlert) {
                    Button(L10n.cancelBooking, role: .destructive) {
                        if let booking = notificationCancelBooking {
                            Haptics.destructive()
                            Task { await bookingManager.cancelBooking(booking) }
                        }
                    }
                    Button(L10n.keep, role: .cancel) {}
                } message: {
                    if let booking = notificationCancelBooking {
                        Text(L10n.cancelSpotOnDate(spot: booking.spotNumber, date: booking.naturalDate))
                    }
                }
        }
    }
}

extension Notification.Name {
    static let appQuickActionTriggered = Notification.Name("appQuickActionTriggered")
}

private extension ParkKingApp {
    func updateQuickActions() {
        guard authManager.currentUser?.isActive == true else {
            UIApplication.shared.shortcutItems = AppQuickAction.shortcutItems(
                includeCancel: false,
                contextualAction: .bookNextAvailable
            )
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let currentEmail = bookingManager.currentUserEmail.lowercased()
        let hasCancelableBooking = bookingManager.bookings.contains { booking in
            booking.date >= today &&
            (booking.email.lowercased() == currentEmail ||
             booking.createdBy.lowercased() == currentEmail)
        }

        let hasOwnUpcomingBooking = bookingManager.bookings.contains { booking in
            booking.email.lowercased() == currentEmail && booking.date >= today
        }

        let contextualAction: AppQuickAction.ContextualAction
        if authManager.currentUser?.isAdmin == true {
            contextualAction = .adminDashboard
        } else if hasOwnUpcomingBooking {
            contextualAction = .navigate
        } else {
            contextualAction = .bookNextAvailable
        }

        UIApplication.shared.shortcutItems = AppQuickAction.shortcutItems(
            includeCancel: hasCancelableBooking,
            contextualAction: contextualAction
        )
    }
}
