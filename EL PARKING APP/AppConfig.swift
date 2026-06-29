//
//  AppConfig.swift
//  EL PARKING APP
//
//  Created on 2026-03-24.
//
//  SINGLE SOURCE OF TRUTH - All configurable values live here.
//

import Foundation
import SwiftUI
import CryptoKit

// MARK: - Shared App Group UserDefaults
extension UserDefaults {
    /// Shared suite used by the main app, widget, and App Intents extension.
    /// Falls back to .standard if the container isn't accessible (e.g. missing provisioning).
    static let appGroup: UserDefaults = {
        let suiteName = "group.com.StivMalakjan.EL-PARKING-APP"
        guard let suite = UserDefaults(suiteName: suiteName) else { return .standard }
        let testKey = "__appGroupAccessTest"
        suite.set(true, forKey: testKey)
        let ok = suite.bool(forKey: testKey)
        suite.removeObject(forKey: testKey)
        return ok ? suite : .standard
    }()
}

struct AppConfig {

    // MARK: - Parking Spots

    /// Master list of all parking spots. Seeded from AppConfig; isAccessible + isBlocked
    /// are updated at runtime from Firestore via BookingManager.startSpotsListener().
    static var allParkingSpots: [ParkingSpot] = [
        ParkingSpot(id: "63", label: "Parking 63"),
        ParkingSpot(id: "64", label: "Parking 64"),
        ParkingSpot(id: "65", label: "Parking 65"),
        ParkingSpot(id: "66", label: "Parking 66"),
        ParkingSpot(id: "67", label: "Parking 67"),
        ParkingSpot(id: "68", label: "Parking 68"),
        ParkingSpot(id: "71", label: "Parking 71"),
        ParkingSpot(id: "72", label: "Parking 72"),
        ParkingSpot(id: "73", label: "Parking 73"),
        ParkingSpot(id: "74", label: "Parking 74"),
        ParkingSpot(id: "75", label: "Parking 75"),
        ParkingSpot(id: "76", label: "Parking 76"),
        ParkingSpot(id: "80", label: "Parking 80", isAccessible: true),
        ParkingSpot(id: "81", label: "Parking 81"),
        ParkingSpot(id: "82", label: "Parking 82"),
    ]

    /// Temporarily blocked spot IDs — populated from Firestore at runtime.
    /// Empty by default; BookingManager loads this from the parkingSpots collection.
    static var blockedSpotIDs: Set<String> = []

    // MARK: - Admin / Privileged Seed Lists
    //
    // These are ONLY used for one-time auto-promotion on first login.
    // After that, roles are managed entirely from Firestore (Admin dashboard).
    // You can safely remove these once all users have been promoted in Firestore.

    /// Seed emails removed from binary for security.
    /// Promote admins directly in Firestore: set role="admin", status="active" on the user document.
    static let seedAdminEmails:      Set<String> = []
    static let seedPrivilegedEmails: Set<String> = []

    // MARK: - Time Configuration

    /// Available time slots for bookings
    static let availableTimeSlots: [String] = [
        "07:00", "08:00", "09:00", "10:00", "11:00",
        "12:00", "13:00", "14:00", "15:00", "16:00", "17:00", "18:00"
    ]

    /// Default start time
    static let defaultTimeFrom: String = "07:00"

    /// Default end time
    static let defaultTimeTo: String = "18:00"

    /// A spot is considered effectively "full-day occupied" once coverage reaches this time.
    /// Example: 07:00–17:00 is treated as full-day (not partial).
    static let fullDayOccupiedCutoffTime: String = "17:00"

    /// After this hour (24h format), date pickers default to tomorrow
    static let autoAdvanceHour: Int = 17

    /// Number of days after booking end time to retain booking documents.
    /// Firestore TTL should be configured on `bookings.expiresAt`.
    static let bookingRetentionDays: Int = 2

    // MARK: - Booking Constraints (Regular Users)

    /// Maximum days in advance a regular user can book FOR THEMSELVES
    static let selfBookingMaxAdvanceDays: Int = 3

    /// Maximum bookings per day for regular users (1 spot per day)
    static let selfBookingMaxPerDay: Int = 1

    // MARK: - Booking Constraints (Privileged Users booking for OTHERS)

    /// Maximum days in advance for booking for others (privileged window = today..+3, per server rules)
    static let othersBookingMaxAdvanceDays: Int = 3

    /// Maximum booking duration for privileged users (in days)
    static let othersBookingMaxDurationDays: Int = 5

    /// Maximum delegated bookings per day for non-admin privileged users
    static let delegatedBookingMaxPerDay: Int = 2

    /// Admins have no server-side date restriction; keep a high client cap (effectively unlimited)
    static let adminBookingMaxAdvanceDays: Int = 365

    // MARK: - Company Spot Policy (GrandVision reservation, from 22 June 2026)

    /// Spots reserved for GrandVision users.
    static let grandVisionSpotIDs: Set<String> = ["74", "75", "76"]

    /// Date the policy takes effect.
    static let companySpotPolicyStart: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 22
        return Calendar.current.date(from: c) ?? .distantFuture
    }()

    /// Same-day bookings open to everyone from this local hour.
    static let sameDayReleaseHour = 8

    static func companySpotPolicyActive(now: Date = Date()) -> Bool {
        now >= companySpotPolicyStart
    }

    /// Same-day release: bookings FOR today are open to all groups after 08:00.
    static func sameDayReleaseApplies(bookingDate: Date, now: Date = Date()) -> Bool {
        Calendar.current.isDate(bookingDate, inSameDayAs: now)
            && Calendar.current.component(.hour, from: now) >= sameDayReleaseHour
    }

    /// Whether `company` may book `spotID` on `bookingDate`. Admins are exempt.
    static func companyMayBook(
        spotID: String,
        company: CompanyBadge,
        isAdmin: Bool,
        bookingDate: Date,
        now: Date = Date()
    ) -> Bool {
        guard companySpotPolicyActive(now: now), !isAdmin else { return true }
        if sameDayReleaseApplies(bookingDate: bookingDate, now: now) { return true }
        let isGVSpot = grandVisionSpotIDs.contains(spotID)
        return isGVSpot ? company == .grandVision : company != .grandVision
    }

    /// Non-admins don't see spots they can't book (no teasing); admins see all.
    static func spotVisible(
        spotID: String,
        company: CompanyBadge,
        isAdmin: Bool,
        bookingDate: Date,
        now: Date = Date()
    ) -> Bool {
        isAdmin || companyMayBook(spotID: spotID, company: company, isAdmin: isAdmin,
                                  bookingDate: bookingDate, now: now)
    }

    /// Ownership badges shown on a spot cell for the given viewer.
    /// GV spots are tagged for everyone outside GrandVision (incl. admins);
    /// shared spots are tagged EL+Omega for GrandVision viewers.
    static func spotGroupBadges(
        spotID: String,
        viewerCompany: CompanyBadge,
        isAdmin: Bool
    ) -> [CompanyBadge] {
        if grandVisionSpotIDs.contains(spotID) {
            return viewerCompany == .grandVision && !isAdmin ? [] : [.grandVision]
        }
        return viewerCompany == .grandVision ? [.essilorLuxottica, .omega] : []
    }

    // MARK: - Location Information

    static let locationName = "Rohanske nabrezi 721/39, Praha"
    static let locationLatitude = 50.097098416842265
    static let locationLongitude = 14.459462896988791
    static let googleMapsURL = "maps://?daddr=50.097098416842265,14.459462896988791&dirflg=d"
    static let privacyPolicyURL = URL(string: "https://elpark.cz/privacy-policy.html")!
    static let supportURL = URL(string: "https://elpark.cz/support.html")!
    static let proximityReminderRadiusMeters: Double = 500
    static let proximityReminderHoursAfterStart: Int = 2
    static let appTitle = "EL Parking"
    /// Production release date shown in Settings. Update on each store release.
    static let releaseDate = "10. 6. 2026"
    static let companyName = "EssilorLuxottica"

    // MARK: - Car Colors
    static let carColors: [(name: String, hex: String)] = [
        ("White",     "#FFFFFF"),
        ("Silver",    "#C0C0C0"),
        ("Gray",      "#808080"),
        ("Black",     "#111111"),
        ("Red",       "#CC3333"),
        ("Bordeaux",  "#7D1128"),
        ("Blue",      "#1A73E8"),
        ("Navy",      "#003087"),
        ("Green",     "#188038"),
        ("Dragon Green", "#2D7D46"),
        ("Yellow",    "#F9A825"),
        ("Orange",    "#E8710A"),
        ("Brown",     "#795548"),
    ]

    // MARK: - Allowed Email Domains
    // Stored as SHA-256 hashes — domain strings are NOT in the binary.
    // To add a domain: echo -n "yourdomain.com" | shasum -a 256
    private static let allowedEmailDomainHashes: Set<String> = [
        "6dcd882bfad5a739cdcc1833e9a8f340233b4db777afb302f615fe30d87ae45c", // essilor.com
        "24ca550ae0c87d8eb8f8d784ec8deb57312af4de6823c1635a509bf69a2b25f4", // essilor.cz
        "3b25ad563a5aa9aa91a73c606016fe635e2c26470da3fa789af7f4d853e244a0", // ext.essilor.com
        "a2fbd416f3c3a7e71506bc88890fe1bb2853afa0e7348395d1ad0da75732e1f8", // luxottica.com
        "57f9855ddf062787288df0dd3428118baedd2a843ff6c38a981be77b5fa9a540", // hu.luxottica.com
        "1c0d91e0243bd27642ba27cdf1e15f0596e1daefe498a193e5c5ce14e293c476", // essilorluxottica.id
        "e3eadea231b5f76178f350deb37c8b6a1af02fb9786887ad15b9a8d60a18ea07", // omega-optix.cz
    ]

    // MARK: - Registration Secret Phrase
    // SHA-256 hash of the phrase — the actual phrase is NOT in the binary.
    // To change: echo -n "yourphrase" | shasum -a 256
    private static let registrationPhraseHash =
        "28629eb4bd850c5056c199fa0f766e718f6dc5d6750f936be40bfdb08c7188e4"

    static func isRegistrationPhraseValid(_ phrase: String) -> Bool {
        let trimmed = phrase.trimmingCharacters(in: .whitespaces).lowercased()
        let hash = SHA256.hash(data: Data(trimmed.utf8)).map { String(format: "%02x", $0) }.joined()
        return hash == registrationPhraseHash
    }

    static func isAllowedEmailDomain(_ email: String) -> Bool {
        guard let domain = email.components(separatedBy: "@").last?.lowercased() else { return false }
        guard !allowedEmailDomainHashes.isEmpty else { return true } // empty = allow all
        let hash = SHA256.hash(data: Data(domain.utf8)).map { String(format: "%02x", $0) }.joined()
        return allowedEmailDomainHashes.contains(hash)
    }

    // MARK: - Palette Style (user-selectable: Default / Calm)

    /// "Calm" swaps signal colors for a muted Nordic palette — pine, clay,
    /// ochre, warm paper — while Default keeps the original signal colors.
    enum AppPalette: Int, CaseIterable {
        case standard = 0
        case calm = 1

        var label: String { self == .calm ? L10n.paletteCalm : L10n.paletteDefault }
        var icon: String { self == .calm ? "leaf" : "paintpalette" }
    }

    static var isCalmPalette: Bool {
        UserDefaults.standard.integer(forKey: "appPalette") == AppPalette.calm.rawValue
    }

    // MARK: - Design System Colors (Kinetic Sanctuary — Adaptive Light/Dark)

    /// Helper to create adaptive colors
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // Calm palette anchors
    private static let calmPine    = UIColor(red: 74/255,  green: 107/255, blue: 93/255,  alpha: 1)   // #4A6B5D
    private static let calmSage    = UIColor(red: 127/255, green: 160/255, blue: 140/255, alpha: 1)   // #7FA08C
    private static let calmClay    = UIColor(red: 192/255, green: 112/255, blue: 79/255,  alpha: 1)   // #C0704F
    private static let calmOchre   = UIColor(red: 201/255, green: 155/255, blue: 79/255,  alpha: 1)   // #C99B4F

    // Accent — Default: native iOS toggle green. Calm: pine/sage.
    static var accent: Color {
        isCalmPalette
            ? adaptive(
                light: UIColor(red: 94/255, green: 142/255, blue: 116/255, alpha: 1),  // #5E8E74 soft sage-pine
                dark: calmSage
              )
            : Color(uiColor: .systemGreen)
    }
    static var accentDim: Color { accent.opacity(0.85) }

    // Accent used as a FOREGROUND (icon / text) color.
    static var accentFg: Color {
        isCalmPalette
            ? adaptive(
                light: UIColor(red: 68/255, green: 115/255, blue: 94/255, alpha: 1),    // #44735E
                dark: UIColor(red: 159/255, green: 188/255, blue: 168/255, alpha: 1)    // #9FBCA8
              )
            : adaptive(light: UIColor.systemGreen, dark: UIColor.systemGreen)
    }

    // Primary text: near-black in light, near-white in dark
    static let darkText = adaptive(
        light: UIColor(red: 0/255, green: 1/255, blue: 0/255, alpha: 1),           // #000100
        dark: UIColor(red: 240/255, green: 241/255, blue: 242/255, alpha: 1)        // #f0f1f2
    )

    // Cards: white in light, dark elevated surface in dark
    static var cardBg: Color {
        isCalmPalette
            ? adaptive(
                light: .white,
                dark: UIColor(red: 35/255, green: 34/255, blue: 32/255, alpha: 1)    // #232220 warm
              )
            : adaptive(
                light: .white,
                dark: UIColor(red: 28/255, green: 30/255, blue: 32/255, alpha: 1)    // #1c1e20
              )
    }

    // Page background — Calm: warm "paper" instead of cool gray
    static var pageBg: Color {
        isCalmPalette
            ? adaptive(
                light: UIColor(red: 244/255, green: 244/255, blue: 241/255, alpha: 1), // #f4f4f1 neutral off-white
                dark: UIColor(red: 29/255, green: 28/255, blue: 26/255, alpha: 1)      // #1d1c1a warm charcoal
              )
            : adaptive(
                light: UIColor(red: 242/255, green: 243/255, blue: 245/255, alpha: 1), // #f2f3f5 subtle gray
                dark: UIColor(red: 14/255, green: 15/255, blue: 16/255, alpha: 1)      // #0e0f10
              )
    }

    // Surface hierarchy
    static var surfaceLow: Color {
        isCalmPalette
            ? adaptive(
                light: UIColor(red: 239/255, green: 239/255, blue: 234/255, alpha: 1), // #efefea
                dark: UIColor(red: 27/255, green: 26/255, blue: 24/255, alpha: 1)      // #1b1a18
              )
            : adaptive(
                light: UIColor(red: 243/255, green: 244/255, blue: 245/255, alpha: 1), // #f3f4f5
                dark: UIColor(red: 22/255, green: 24/255, blue: 26/255, alpha: 1)      // #16181a
              )
    }

    static var surfaceHigh: Color {
        isCalmPalette
            ? adaptive(
                light: UIColor(red: 229/255, green: 229/255, blue: 224/255, alpha: 1), // #e5e5e0
                dark: UIColor(red: 42/255, green: 40/255, blue: 38/255, alpha: 1)      // #2a2826
              )
            : adaptive(
                light: UIColor(red: 231/255, green: 232/255, blue: 233/255, alpha: 1), // #e7e8e9
                dark: UIColor(red: 38/255, green: 40/255, blue: 42/255, alpha: 1)      // #26282a
              )
    }

    // Secondary text
    static let subtleGray = adaptive(
        light: UIColor(red: 93/255, green: 94/255, blue: 97/255, alpha: 1),         // #5d5e61
        dark: UIColor(red: 158/255, green: 160/255, blue: 165/255, alpha: 1)         // #9ea0a5
    )

    static let outlineVariant = adaptive(
        light: UIColor(red: 197/255, green: 198/255, blue: 202/255, alpha: 1),      // #c5c6ca
        dark: UIColor(red: 60/255, green: 62/255, blue: 66/255, alpha: 1)            // #3c3e42
    )

    // Status colors — Default: signal. Calm: earth (sage / clay / ochre).
    static var spotAvailable: Color {
        isCalmPalette
            ? Color(red: 110/255, green: 144/255, blue: 128/255)                    // #6E9080 sage
            : Color(red: 76/255, green: 175/255, blue: 80/255)
    }
    static var spotOccupied: Color {
        isCalmPalette
            ? Color(uiColor: calmClay)                                              // #C0704F clay
            : Color(red: 186/255, green: 26/255, blue: 26/255)                      // #ba1a1a
    }
    static var spotMine: Color {
        isCalmPalette
            ? Color(uiColor: calmOchre)                                             // #C99B4F ochre
            : Color(red: 255/255, green: 179/255, blue: 0/255)
    }
    static let spotBlocked = adaptive(
        light: UIColor(red: 189/255, green: 189/255, blue: 189/255, alpha: 1),
        dark: UIColor(red: 80/255, green: 80/255, blue: 80/255, alpha: 1)
    )
    static var activeGreen: Color {
        isCalmPalette
            ? Color(red: 94/255, green: 132/255, blue: 104/255)                     // #5E8468 pine-bright
            : Color(red: 56/255, green: 176/255, blue: 0/255)
    }

    // Grouped-screen backgrounds — Settings, admin, detail screens. Default
    // matches system grouped colors exactly; Calm gets the warm neutrals.
    static var groupedPageBg: Color {
        isCalmPalette
            ? adaptive(
                light: UIColor(red: 244/255, green: 244/255, blue: 241/255, alpha: 1), // #f4f4f1
                dark: UIColor(red: 29/255, green: 28/255, blue: 26/255, alpha: 1)      // #1d1c1a
              )
            : Color(uiColor: .systemGroupedBackground)
    }
    static var groupedCardBg: Color {
        isCalmPalette
            ? adaptive(
                light: .white,
                dark: UIColor(red: 35/255, green: 34/255, blue: 32/255, alpha: 1)      // #232220
              )
            : Color(uiColor: .secondarySystemGroupedBackground)
    }
    static var tertiaryFillBg: Color {
        isCalmPalette
            ? adaptive(
                light: UIColor(red: 234/255, green: 234/255, blue: 229/255, alpha: 1), // #eaeae5
                dark: UIColor(red: 44/255, green: 42/255, blue: 39/255, alpha: 1)      // #2c2a27
              )
            : Color(uiColor: .tertiarySystemFill)
    }

    // Semantic signal tints — route ALL ad-hoc .orange / .red / .blue UI
    // colors through these so the Calm palette reaches every surface.
    static var warning: Color {
        isCalmPalette ? Color(uiColor: calmOchre) : .orange
    }
    static var danger: Color {
        isCalmPalette ? Color(uiColor: calmClay) : Color(uiColor: .systemRed)
    }
    static var infoTint: Color {
        isCalmPalette
            ? Color(red: 102/255, green: 128/255, blue: 148/255)                    // #668094 fog blue
            : Color(uiColor: .systemBlue)
    }

    // On-accent text (for text ON green buttons)
    static let onAccent = adaptive(
        light: UIColor.white,
        dark: UIColor.white
    )

    // Obsidian card background (used for hero cards — same in both modes)
    // Calm: "forest at dusk" — barely-green charcoal that ties hero to brand.
    static var obsidian: Color {
        isCalmPalette
            ? Color(red: 34/255, green: 40/255, blue: 31/255)                       // #22281F forest
            : Color(red: 26/255, green: 28/255, blue: 30/255)                       // #1A1C1E
    }

    // Selected pill bg (date pills, filter pills)
    static let pillSelected = adaptive(
        light: UIColor.black,
        dark: UIColor(red: 55/255, green: 58/255, blue: 62/255, alpha: 1)           // #373a3e
    )

    /// Admin contact email
    static let adminContactEmail = "stiv.malakjan@ext.essilor.com"

    // MARK: - UI Tokens
    static let radius12: CGFloat = 12
    static let radius16: CGFloat = 16
    static let radius24: CGFloat = 24
    static let toolbarIconWeight: Font.Weight = .semibold
    static let separatorStrong = outlineVariant.opacity(0.5)
    static let separatorSoft = outlineVariant.opacity(0.3)

    // MARK: - Home Feature Flags (easy revert)
    static let enableHomeSmartChips = true
    static let enableHomeAnnouncementPriorityStack = true
    static let enableHomeAnnouncementDetailSheet = true
    static let enableHomeMotionConsistency = true
    static let enableHomeInfoDetailSheet = true
    static let enableHomeAppleAnnouncementsStyle = true
    static let enableAdminAnnouncementsUnifiedStyle = true
    static let enableSettingsGroupedTone = true
    static let enableBookingPremiumGlass = true
    /// Native ContentUnavailableView empty states; set false to revert to the legacy card style.
    static let enableNativeEmptyStates = true
}

// MARK: - Animation Tokens

extension Animation {
    // Apple's named springs (.snappy / .smooth / .spring(duration:bounce:))
    // are the system-tuned curves used across iOS 17+; preferring them keeps
    // the app's motion identical in feel to native controls.

    /// Selection feedback — taps, toggles, pressed states.
    static let motionSelection = Animation.snappy(duration: 0.26, extraBounce: 0.0)
    /// Standard transition — cards, list state changes, in-screen transitions.
    static let motionStandard = Animation.smooth(duration: 0.34, extraBounce: 0.0)
    /// Confirm transition — success/important outcome animations.
    static let motionConfirm = Animation.spring(duration: 0.45, bounce: 0.22)
    /// Sheet-like movement — larger modal/sheet choreography.
    static let motionSheet = Animation.smooth(duration: 0.55, extraBounce: 0.0)
    /// Fade helper for staged opacity transitions.
    static let motionFade = Animation.easeOut(duration: 0.30)

    /// Backward-compatible aliases used across the app.
    static let quick = motionSelection
    static let standard = motionStandard
    static let emphasis = motionConfirm
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&rgb) else {
            self.init(red: 0.5, green: 0.5, blue: 0.5)
            return
        }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >>  8) & 0xFF) / 255.0,
            blue:  Double( rgb        & 0xFF) / 255.0
        )
    }

    /// Converts this Color to a hex string like "#FF3A2D".
    var hexString: String {
        hexString(fallback: "#808080")
    }

    func hexString(fallback: String) -> String {
        let ui = UIColor(self).resolvedColor(with: UITraitCollection.current)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            var white: CGFloat = 0
            if ui.getWhite(&white, alpha: &a) {
                let value = max(0, min(255, Int((white * 255).rounded())))
                return String(format: "#%02X%02X%02X", value, value, value)
            }
            return fallback.normalizedHexColor ?? "#808080"
        }

        func component(_ value: CGFloat) -> Int {
            max(0, min(255, Int((value * 255).rounded())))
        }

        return String(format: "#%02X%02X%02X",
                      component(r),
                      component(g),
                      component(b))
    }
}

extension String {
    var normalizedHexColor: String? {
        let raw = trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard raw.count == 6, raw.allSatisfy(\.isHexDigit) else { return nil }
        return "#\(raw.uppercased())"
    }
}
