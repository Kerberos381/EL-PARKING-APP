//
//  L10n.swift
//  EL PARKING APP
//
//  Complete Czech / English localisation.
//
//  Usage in any view:
//    @ObservedObject private var lang = LanguageManager.shared
//    Text(L10n.myBookings)
//
//  Change language (already wired in SettingsView):
//    LanguageManager.shared.language = .czech
//    (stored in UserDefaults under key "appLanguage")
//
//  To add a new key:
//    1. Add a static var / static func below with both English and Czech values
//    2. Use it in the view: Text(L10n.yourKey)
//

import Foundation
import Combine

// MARK: - Language enum

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case czech   = "cs"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .czech:   return "Čeština"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .czech:   return "🇨🇿"
        }
    }
}

// MARK: - Language Manager

/// Singleton ObservableObject — inject once via .environmentObject, observe
/// individually with @ObservedObject var lang = LanguageManager.shared.
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        self.language = AppLanguage(rawValue: saved) ?? .english
    }
}

// MARK: - L10n

struct L10n {

    static var lang: AppLanguage { LanguageManager.shared.language }
    static var isCzech: Bool { lang == .czech }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Navigation / Tab Bar
    // ─────────────────────────────────────────────────────────────────────────

    static var home:       String { isCzech ? "Domů"       : "Home" }
    static var parking:    String { isCzech ? "Parkování"   : "Parking" }
    static var admin:      String { isCzech ? "Správce"    : "Admin" }
    static var settings:   String { isCzech ? "Nastavení"  : "Settings" }
    static var search:     String { isCzech ? "Hledat"     : "Search" }
    static var dashboard:  String { isCzech ? "Přehled"    : "Dashboard" }

    // Home Screen quick action subtitles
    static var qaOpenBookingSheet:  String { isCzech ? "Otevřít rezervaci"        : "Open booking sheet" }
    static var qaSeeUpcoming:       String { isCzech ? "Nadcházející rezervace"   : "See upcoming bookings" }
    static var qaOpenToCancel:      String { isCzech ? "Zrušit v Moje rezervace"  : "Open bookings to cancel" }
    static var qaAdminControls:     String { isCzech ? "Otevřít správu"           : "Open admin controls" }
    static var qaOpenDirections:    String { isCzech ? "Otevřít navigaci"         : "Open directions" }
    static var qaQuickBooking:      String { isCzech ? "Rychlá rezervace"         : "Start quick booking" }
    static var qaNavigateToParking: String { isCzech ? "Navigovat na parkoviště"  : "Navigate to Parking" }
    static var qaBookNext:          String { isCzech ? "Rezervovat nejbližší"     : "Book Next Available" }
    static var qaAdminDashboard:    String { isCzech ? "Správa"                   : "Admin Dashboard" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Common Actions
    // ─────────────────────────────────────────────────────────────────────────

    static var done:        String { isCzech ? "Hotovo"    : "Done" }
    static var cancel:      String { isCzech ? "Zrušit"    : "Cancel" }
    static var save:        String { isCzech ? "Uložit"    : "Save" }
    static var edit:        String { isCzech ? "Upravit"   : "Edit" }
    static var keep:        String { isCzech ? "Ponechat"  : "Keep" }
    static var close:       String { isCzech ? "Zavřít"    : "Close" }
    static var back:        String { isCzech ? "Zpět"      : "Back" }
    static var select:      String { isCzech ? "Vybrat"    : "Select" }
    static var next:        String { isCzech ? "Další"     : "Next" }
    static var skip:        String { isCzech ? "Přeskočit" : "Skip" }
    static var getStarted:  String { isCzech ? "Začít"     : "Get Started" }
    static var continueBtn: String { isCzech ? "Pokračovat": "Continue" }
    static var ok:          String { isCzech ? "OK"        : "OK" }
    static var signOut:     String { isCzech ? "Odhlásit se" : "Sign Out" }
    static var saving:      String { isCzech ? "Ukládám…"  : "Saving…" }
    static var saved:       String { isCzech ? "Uloženo!"  : "Saved!" }
    static var tryAgain:    String { isCzech ? "Zkusit znovu" : "Try again" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Home Screen
    // ─────────────────────────────────────────────────────────────────────────

    static var myBookings:     String { isCzech ? "Moje rezervace"      : "My Bookings" }
    static var bookASpot:      String { isCzech ? "Rezervovat místo"    : "Book a Spot" }
    static var noBooking:      String { isCzech ? "Žádná rezervace"     : "No Parking Booked" }
    static var bookFromBelow:  String { isCzech ? "Zarezervujte místo níže" : "Book a spot from below" }
    static var announcements:  String { isCzech ? "Oznámení"            : "Announcements" }
    static var info:           String { isCzech ? "Informace"           : "Info" }
    static var activeNow:      String { isCzech ? "Aktivní"             : "Active now" }
    static var upcoming:       String { isCzech ? "Nadcházející"        : "Upcoming" }
    static var navigate:       String { isCzech ? "Navigovat"           : "Navigate" }
    static var bookedBy:       String { isCzech ? "Rezervováno:"        : "Booked by" }

    static func helloGreeting(_ name: String, preferredVocative: String = "") -> String {
        if isCzech {
            let manual = preferredVocative.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = manual.isEmpty ? CzechVocative.inflect(firstName: name) : manual
            return "Ahoj, \(finalName)"
        }
        return "Hello, \(name)"
    }

    /// Primary book CTA with live availability — "Book (12)".
    static func bookWithCount(_ n: Int) -> String {
        isCzech ? "Rezervovat (\(n))" : "Book (\(n))"
    }

    static var emptyHeroTitle: String {
        isCzech ? "Zarezervujte si místo na dnešek" : "Reserve your spot for today"
    }

    static func spotsAvailable(_ count: Int) -> String {
        if isCzech {
            switch count {
            case 1:  return "1 místo k dispozici"
            case 2, 3, 4: return "\(count) místa k dispozici"
            default: return "\(count) míst k dispozici"
            }
        }
        return "\(count) Spots Available"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Parking Overview
    // ─────────────────────────────────────────────────────────────────────────

    static var executiveMobility: String { isCzech ? "Firemní mobilita"  : "Executive mobility" }
    static var parkingDot:        String { isCzech ? "Parkování."        : "Parking." }
    static var today:             String { isCzech ? "Dnes"              : "Today" }
    static var free:              String { isCzech ? "Volné"             : "Free" }
    static var booked:            String { isCzech ? "Rezervováno"       : "Booked" }
    static var blocked:           String { isCzech ? "Blokováno"         : "Blocked" }
    static var allBookings:       String { isCzech ? "Všechny rezervace" : "All Bookings" }
    static var bookings:          String { isCzech ? "Rezervace"         : "Bookings" }
    static var noBookingsDay:     String { isCzech ? "Žádné rezervace pro tento den" : "No bookings for this day" }
    static var taken:             String { isCzech ? "Obsazeno"          : "Taken" }
    static var yours:             String { isCzech ? "Vaše"              : "Yours" }
    static var accessible:        String { isCzech ? "Bezbariérové"      : "Accessible" }
    static var you:               String { isCzech ? "VY"                : "YOU" }
    static var forLabel:          String { isCzech ? "Pro"               : "For" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Booking Sheet
    // ─────────────────────────────────────────────────────────────────────────

    static var newBooking:      String { isCzech ? "Nová rezervace"        : "New Booking" }
    static var editBooking:     String { isCzech ? "Upravit rezervaci"     : "Edit Booking" }
    static var bookForOthers:   String { isCzech ? "Rezervovat pro jiného" : "Book for Others" }
    static var confirmBooking:  String { isCzech ? "Potvrdit rezervaci"    : "Confirm Booking" }
    static var cancelBooking:   String { isCzech ? "Zrušit rezervaci"      : "Cancel Booking" }
    static var bookingUpdated:  String { isCzech ? "Rezervace aktualizována!" : "Booking Updated!" }
    static var bookingConfirmed:String { isCzech ? "Rezervace potvrzena!"  : "Booking Confirmed!" }
    static var selectASpotAbove:String { isCzech ? "Nejdříve vyberte místo" : "Select a Spot Above" }

    static var date:       String { isCzech ? "Datum"          : "Date" }
    static var dateRange:  String { isCzech ? "Rozsah dat"     : "Date Range" }
    static var from:       String { isCzech ? "Od"             : "From" }
    static var to:         String { isCzech ? "Do"             : "To" }
    static var time:       String { isCzech ? "Čas"            : "Time" }
    static var spot:       String { isCzech ? "Místo"          : "Spot" }
    static var selectSpot: String { isCzech ? "Vyberte místo"  : "Select Spot" }
    static var bookingFor: String { isCzech ? "Rezervace pro"  : "Booking For" }
    static var tomorrow:   String { isCzech ? "Zítra"          : "Tomorrow" }
    static var fullName:   String { isCzech ? "Celé jméno"     : "Full Name" }
    static var email:      String { isCzech ? "E-mail"         : "Email" }
    static var change:     String { isCzech ? "Změnit"         : "Change" }
    static var available:  String { isCzech ? "Dostupné"       : "Available" }
    static var availableOnSelectedDate: String { isCzech ? "Dostupné ve vybraný den" : "Available on selected date" }
    static var unavailableOnSelectedDate: String {
        isCzech ? "Pro vybrané datum není dostupné – změňte datum nebo místo" : "Not available on this date — change the date or spot"
    }
    static var delegateBooking: String { isCzech ? "Delegovat rezervaci" : "Delegate Booking" }
    static var suggestedAlternatives: String { isCzech ? "Doporučené alternativy" : "Suggested alternatives" }
    static var sameTime: String { isCzech ? "Stejný čas" : "Same time" }
    static var closestMatch: String { isCzech ? "Nejbližší shoda" : "Closest match" }
    static var smartBookingTipTitle: String { isCzech ? "Chytré doporučení" : "Smart suggestion" }
    static var smartBookingTipBody: String {
        isCzech
            ? "Některá částečně obsazená místa jsou pro tento čas stále volná. Jejich využitím necháte plně volná místa ostatním."
            : "Some partially booked spots are still free for this exact slot. Using them helps keep fully free spots available for others."
    }
    static func useSpot(_ spotID: String) -> String {
        isCzech ? "Použít #\(spotID)" : "Use #\(spotID)"
    }

    static func bookForOthersSublabel(_ days: Int) -> String {
        isCzech
            ? "Rezervovat pro jinou osobu (až \(days) dní)"
            : "Book for someone else (up to \(days) days)"
    }

    static func spotsAvailableOf(_ available: Int, total: Int) -> String {
        isCzech
            ? "\(available) z \(total) míst k dispozici"
            : "\(available) of \(total) spots available"
    }

    static func daysSummary(_ days: Int, from: String, to: String) -> String {
        isCzech
            ? "\(days) dnů: \(from) → \(to)"
            : "\(days) days: \(from) → \(to)"
    }

    // Booking errors
    static var pleaseSelectSpot: String { isCzech ? "Prosím vyberte místo." : "Please select a spot." }
    static var endTimeAfterStart:String { isCzech ? "Čas konce musí být po začátku." : "End time must be after start time." }
    static func tooFarInAdvance(_ days: Int) -> String {
        isCzech
            ? "Nelze rezervovat více než \(days) dní dopředu."
            : "Cannot book more than \(days) days in advance."
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: My Bookings
    // ─────────────────────────────────────────────────────────────────────────

    static var past:                String { isCzech ? "Minulé"               : "Past" }
    static var delegatedBookings:   String { isCzech ? "Delegované rezervace" : "Delegated Bookings" }
    static var spotsBookedForOthers:String { isCzech ? "Místa rezervovaná pro ostatní" : "Spots you booked for others" }
    static var cancelAll:           String { isCzech ? "Zrušit vše"           : "Cancel All" }
    static var cancelEntireRange:   String { isCzech ? "Zrušit celý rozsah"   : "Cancel Entire Range" }
    static var cancelAllDays:       String { isCzech ? "Zrušit všechny dny"   : "Cancel All Days" }
    static var rangeUpdated:        String { isCzech ? "Rozsah aktualizován!" : "Range Updated!" }
    static var editRange:           String { isCzech ? "Upravit rozsah"       : "Edit Range" }
    static var noUpcomingBookings:  String { isCzech ? "Žádné nadcházející rezervace" : "No Upcoming Bookings" }
    static var futureBookingsHere:  String { isCzech ? "Vaše budoucí rezervace se zobrazí zde" : "Your future bookings will appear here" }
    static var bookedForYou:        String { isCzech ? "Rezervováno pro vás"  : "Booked for you" }
    static var delegatedPast:       String { isCzech ? "Delegované · Minulé"  : "Delegated · Past" }

    static func rangeNDays(_ n: Int) -> String {
        isCzech ? "ROZSAH · \(n) DNÍ" : "RANGE · \(n) DAYS"
    }

    static func upcomingCount(_ n: Int) -> String {
        isCzech ? "\(n) nadcházejících" : "\(n) upcoming"
    }

    static func daysRebooked(_ n: Int) -> String {
        isCzech ? "\(n) dní přerezervováno" : "\(n) days rebooked"
    }

    static func saveAllDays(_ n: Int) -> String {
        isCzech ? "Uložit všech \(n) dní" : "Save All \(n) Days"
    }

    static func cancelRangeMessage(count: Int, name: String, spot: String, from: String, to: String) -> String {
        isCzech
            ? "Zrušit \(count) dní pro \(name) — místo \(spot), \(from) až \(to)?"
            : "Cancel \(count) days for \(name) — \(spot), \(from) to \(to)?"
    }

    static func cancelSingleMessage(spot: String, date: String) -> String {
        isCzech
            ? "Zrušit místo \(spot) dne \(date)?"
            : "Cancel spot \(spot) on \(date)?"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Spot Detail Sheet
    // ─────────────────────────────────────────────────────────────────────────

    static var bookingDetails:      String { isCzech ? "Detaily rezervace"    : "Booking Details" }
    static var bookedOn:            String { isCzech ? "Zarezervováno dne"    : "Booked On" }
    static var bookedByLabel:       String { isCzech ? "Zarezervoval/a"       : "Booked By" }
    static var name:                String { isCzech ? "Jméno"                : "Name" }
    static var share:               String { isCzech ? "Sdílet"               : "Share" }
    static var shareBooking:        String { isCzech ? "Sdílet rezervaci"     : "Share Booking" }
    static var shareAsText:         String { isCzech ? "Sdílet jako text"     : "Share as Text" }
    static var adminActions:        String { isCzech ? "Akce správce"         : "Admin Actions" }
    static var manageBooking:       String { isCzech ? "Správa rezervace"     : "Manage Booking" }

    static var youBookedForYourself: String { isCzech ? "Zarezervoval/a jsi sám/sama" : "You booked this for yourself" }

    static func youBookedFor(_ name: String) -> String {
        isCzech ? "Zarezervoval/a jsi pro \(name)" : "You booked this for \(name)"
    }

    static func bookedForYouBy(_ name: String) -> String {
        isCzech ? "Zarezervováno pro vás od \(name)" : "Booked for you by \(name)"
    }

    static func personBookedFor(creator: String, bookedFor: String) -> String {
        isCzech ? "\(creator) rezervoval/a pro \(bookedFor)" : "\(creator) booked this for \(bookedFor)"
    }

    static func cancelBookingAlert(name: String, spot: String, date: String) -> String {
        isCzech
            ? "Zrušit rezervaci \(name) pro místo \(spot) ze dne \(date)?"
            : "Cancel \(name)'s booking for spot \(spot) on \(date)?"
    }

    static func cancelBookingAdminAlert(name: String, spot: String) -> String {
        isCzech
            ? "Zrušit rezervaci \(name) pro místo \(spot)? Bude odesláno oznámení."
            : "Cancel \(name)'s booking for spot \(spot)? A notification will be sent."
    }

    static func cancelOwnBookingAlert(user: String, spot: String, date: String) -> String {
        isCzech
            ? "Zrušit rezervaci uživatele \(user) na místě \(spot) ze dne \(date)?"
            : "Cancel \(user)'s booking of spot \(spot) on \(date)?"
    }

    static func cancelSpotOnDate(spot: String, date: String) -> String {
        isCzech
            ? "Zrušit místo \(spot) dne \(date)?"
            : "Cancel spot \(spot) on \(date)?"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Share Sheet
    // ─────────────────────────────────────────────────────────────────────────

    static var shareTitle: String { isCzech ? "Sdílet rezervaci" : "Share Booking" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Settings
    // ─────────────────────────────────────────────────────────────────────────

    static var profile:          String { isCzech ? "Profil"            : "Profile" }
    static var language:         String { isCzech ? "Jazyk"             : "Language" }
    static var appearance:       String { isCzech ? "Vzhled"            : "Appearance" }
    static var colorPalette:     String { isCzech ? "Barevná paleta"    : "Color palette" }
    static var paletteDefault:   String { isCzech ? "Výchozí"           : "Default" }
    static var paletteCalm:      String { isCzech ? "Klidná"            : "Calm" }
    static var homeLayout:       String { isCzech ? "Domovská obrazovka" : "Home layout" }
    static var homeRoomy:        String { isCzech ? "Výchozí"           : "Default" }
    static var homeCompact:      String { isCzech ? "Kompaktní"         : "Compact" }
    static var yourVehicle:      String { isCzech ? "Vaše vozidlo"      : "Your vehicle" }
    static var addYourVehicle:   String { isCzech ? "Přidat vozidlo"    : "Add your vehicle" }
    static var favoriteShort:    String { isCzech ? "Oblíbené"          : "Favorite" }
    static var lastShort:        String { isCzech ? "Naposledy"         : "Last" }
    static func freeCount(_ n: Int) -> String { isCzech ? "\(n) volných" : "\(n) free" }
    static func spotTakenToday(_ id: String) -> String {
        isCzech ? "Místo \(id) je dnes obsazené – vyberte jiné." : "Spot \(id) is already taken today — pick another."
    }
    static var notifications:    String { isCzech ? "Oznámení"          : "Notifications" }
    static var vehicle:          String { isCzech ? "Vozidlo"           : "My Vehicle" }
    static var account:          String { isCzech ? "Účet"              : "Account" }
    static var greetingName:     String { isCzech ? "Oslovení"          : "Greeting name" }
    static var greetingNameHint: String { isCzech ? "např. Katko, Jane" : "e.g. Kate, John" }
    static var greetingNameHelp: String {
        isCzech
            ? "Automaticky se zkusí použít 5. pád. Tady můžeš oslovení ručně upravit."
            : "Used in the home greeting. You can set a custom form."
    }
    static var bookingRules:     String { isCzech ? "Pravidla rezervací": "Booking Rules" }
    static var statistics:       String { isCzech ? "Statistiky"        : "Statistics" }
    static var data:             String { isCzech ? "Data"              : "Data" }
    static var administrator:    String { isCzech ? "Správce"           : "Administrator" }
    static var privilegedUser:   String { isCzech ? "Privilegovaný uživatel" : "Privileged User" }
    static var deleteAccount:    String { isCzech ? "Smazat účet"       : "Delete Account" }
    static var lightMode:        String { isCzech ? "Světlý"            : "Light" }
    static var darkMode:         String { isCzech ? "Tmavý"             : "Dark" }
    static var systemMode:       String { isCzech ? "Systémový"         : "System" }

    static func biometricEnabled(_ name: String) -> String {
        isCzech ? "\(name) aktivní"   : "\(name) enabled"
    }
    static func enableBiometric(_ name: String) -> String {
        isCzech ? "Aktivovat \(name)" : "Enable \(name)"
    }
    static var tapToTurnOff:    String { isCzech ? "Klepnutím deaktivujte"    : "Tap to turn off" }
    static var signInWithoutPwd:String { isCzech ? "Přihlásit bez hesla"      : "Sign in without a password" }
    static var forgetDevice:    String { isCzech ? "Zapomenout toto zařízení" : "Forget this device" }
    static var faceIDAppLock: String {
        isCzech ? "Face ID zámek aplikace" : "Face ID App Lock"
    }
    static var forgetSavedSignInDevice: String {
        isCzech ? "Zapomenout uložené přihlášení na tomto zařízení" : "Forget saved sign-in on this device"
    }

    static var bookingReminders:    String { isCzech ? "Připomenutí rezervací"              : "Booking Reminders" }
    static var notifyBeforeBooking: String { isCzech ? "Upozornit před zahájením rezervace" : "Notify me before my booking starts" }
    static var notifyMe:            String { isCzech ? "UPOZORNIT MĚ"                       : "NOTIFY ME" }
    static var custom:              String { isCzech ? "Vlastní"                             : "Custom" }
    static var setCustomTime:       String { isCzech ? "Nastavit vlastní čas…"              : "Set custom time…" }
    static var howFarInAdvance:     String { isCzech ? "Jak daleko dopředu?"                : "How far in advance?" }
    static var customReminder:      String { isCzech ? "Vlastní připomenutí"                : "Custom Reminder" }
    static var atStart:             String { isCzech ? "Při zahájení"                       : "At start" }
    static var before:              String { isCzech ? "před"                               : "before" }

    // Reminder duration words
    static func reminderDays(_ d: Int) -> String {
        if isCzech {
            return d == 1 ? "1 den" : "\(d) dny"
        }
        return d == 1 ? "1 day" : "\(d) days"
    }
    static func reminderHours(_ h: Int) -> String {
        if isCzech {
            return h == 1 ? "1 hodina" : "\(h) hodiny"
        }
        return h == 1 ? "1 hour" : "\(h) hours"
    }
    static func reminderMinutes(_ m: Int) -> String {
        "\(m) min"
    }

    // Reminder pill labels (label, sublabel)
    static var reminderOptions: [(label: String, sublabel: String, minutes: Int)] {
        let b = isCzech ? "před" : "before"
        return [
            ("30 min",    b, 30),
            (isCzech ? "1 hod"   : "1 hour",   b, 60),
            (isCzech ? "2 hod"   : "2 hours",  b, 120),
            (isCzech ? "3 hod"   : "3 hours",  b, 180),
            (isCzech ? "6 hod"   : "6 hours",  b, 360),
            (isCzech ? "12 hod"  : "12 hours", b, 720),
            (isCzech ? "1 den"   : "1 day",    b, 1440),
            (isCzech ? "2 dny"   : "2 days",   b, 2880),
        ]
    }

    static var carDescription:   String { isCzech ? "Popis vozu"         : "Car Description" }
    static var carPlaceholder:   String { isCzech ? "např. Černé BMW 3"  : "e.g. Black BMW 3 Series" }
    static var regPlate:         String { isCzech ? "SPZ"                : "Registration Plate" }
    static var regPlatePlaceholder:String{isCzech ? "např. 1AB 2345"     : "e.g. 1AB 2345" }
    static var unsavedChanges:   String { isCzech ? "Neuložené změny"    : "Unsaved changes" }
    static var namePlaceholder:  String { isCzech ? "Celé jméno"         : "Full Name" }
    static var emailPlaceholder: String { isCzech ? "E-mail"             : "Email" }

    // Rules labels
    static var personalAdvance:    String { isCzech ? "Osobní předstih"          : "Personal advance" }
    static var forOthersAdvance:   String { isCzech ? "Předstih pro ostatní"     : "For others advance" }
    static var maxPerDay:          String { isCzech ? "Max. za den (osobní)"     : "Max per day (personal)" }
    static var defaultTime:        String { isCzech ? "Výchozí čas"              : "Default time" }
    static var autoAdvanceAfter:   String { isCzech ? "Automatický posun po"     : "Auto-advance after" }

    // Stats labels
    static var myBookingsCount:    String { isCzech ? "Moje rezervace"    : "My bookings" }
    static var totalBookings:      String { isCzech ? "Celkem rezervací"  : "Total bookings" }

    // Data / destructive
    static var clearAllBookings:   String { isCzech ? "Vymazat všechny rezervace" : "Clear All Bookings" }
    static var clearConfirmMsg:    String {
        isCzech
            ? "Tímto trvale odstraníte všechny rezervace. Tuto akci nelze vrátit."
            : "This will permanently delete all bookings. This action cannot be undone."
    }
    static var clear:              String { isCzech ? "Vymazat"         : "Clear" }
    static var deleteConfirmPlaceholder: String { isCzech ? "Zadejte DELETE k potvrzení" : "Type DELETE to confirm" }
    static var deletePermanently:        String { isCzech ? "Trvale smazat"              : "Delete Permanently" }
    static var deleteAccountMsg:         String {
        isCzech
            ? "Tímto trvale smažete svůj účet, všechny vaše rezervace a odhlásíte se. Tuto akci nelze vrátit.\n\nZadejte DELETE k potvrzení."
            : "This will permanently delete your account, all your bookings, and sign you out. This cannot be undone.\n\nType DELETE to confirm."
    }

    static func biometricReason(_ name: String) -> String {
        isCzech ? "Aktivovat \(name) pro EL Parking" : "Enable \(name) for EL Parking"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Auth / Login
    // ─────────────────────────────────────────────────────────────────────────

    static var signIn:           String { isCzech ? "Přihlásit se"        : "Sign In" }
    static var register:         String { isCzech ? "Registrovat se"      : "Register" }
    static var createAccount:    String { isCzech ? "Vytvořit účet"       : "Create Account" }
    static var welcomeBack:      String { isCzech ? "Vítejte zpět"        : "Welcome Back" }
    static var password:         String { isCzech ? "Heslo"               : "Password" }
    static var confirmPassword:  String { isCzech ? "Potvrdit heslo"      : "Confirm Password" }
    static var forgotPassword:   String { isCzech ? "Zapomenuté heslo?"   : "Forgot password?" }
    static var privacyPolicy:    String { isCzech ? "Zásady ochrany soukromí" : "Privacy Policy" }
    static var reauthToDeleteReason: String {
        isCzech ? "Potvrďte svou totožnost pro smazání účtu" : "Confirm your identity to delete your account"
    }
    static var reauthFailedMsg: String {
        isCzech
            ? "Totožnost se nepodařilo ověřit. Účet nebyl smazán."
            : "Couldn't confirm your identity. Your account was not deleted."
    }
    static var passwordsMismatch:String { isCzech ? "Hesla se neshodují"  : "Passwords do not match" }
    static var alreadyHaveAccount:String{ isCzech ? "Již máte účet?"      : "Already have an account?" }
    static var noAccountYet:     String { isCzech ? "Nemáte účet?"        : "Don't have an account?" }
    static var secretPhrase:       String { isCzech ? "Tajná fráze"                        : "Secret Phrase" }
    static var secretPhraseHint:   String { isCzech ? "Zadejte interní přístupovou frázi"  : "Enter internal access phrase" }
    static var invalidSecretPhrase:String { isCzech ? "Nesprávná přístupová fráze."        : "Incorrect access phrase." }
    static var vehicleOptional:  String { isCzech ? "VOZIDLO  (nepovinné)" : "VEHICLE  (optional)" }
    static var platePlaceholder: String { isCzech ? "SPZ  např. 1AB 2345" : "Plate  e.g. 1AB 2345" }
    static var carInputPlaceholder:String{isCzech ? "Vůz  např. Černé BMW" : "Car  e.g. Black BMW 3 Series" }
    static var orLabel:          String { isCzech ? "NEBO"                : "OR" }
    static var signInWithPwd:    String { isCzech ? "Přihlásit heslem"    : "Sign in with password" }
    static var resetPassword:    String { isCzech ? "Obnovit heslo"       : "Reset Password" }
    static var sendResetLink:    String { isCzech ? "Odeslat odkaz"       : "Send Reset Link" }
    static var checkYourEmail:       String { isCzech ? "Zkontrolujte e-mail"         : "Check Your Email" }
    static var enterEmailForReset:   String { isCzech ? "Zadejte svůj e-mail a pošleme vám odkaz pro obnovení hesla." : "Enter your email and we'll send you a link to reset your password." }
    static var changePassword:       String { isCzech ? "Změnit heslo"                : "Change Password" }
    static var currentPassword:      String { isCzech ? "Aktuální heslo"              : "Current Password" }
    static var newPassword:          String { isCzech ? "Nové heslo"                  : "New Password" }
    static var confirmNewPassword:   String { isCzech ? "Potvrdit nové heslo"         : "Confirm New Password" }
    static var passwordChanged:      String { isCzech ? "Heslo bylo úspěšně změněno"  : "Password changed successfully" }
    static var forgotCurrentPassword:String { isCzech ? "Zapomněli jste aktuální heslo?" : "Forgot current password?" }
    static var wrongCurrentPassword: String { isCzech ? "Aktuální heslo je nesprávné." : "Current password is incorrect." }
    static var emailAddress:     String { isCzech ? "E-mailová adresa"    : "Email address" }

    static func resetEmailSent(_ email: String) -> String {
        isCzech
            ? "Pokud existuje účet na adrese \(email), byl odeslán odkaz pro obnovení hesla."
            : "If an account exists for \(email), a password reset link has been sent."
    }

    static func biometricWelcome(_ name: String) -> String {
        isCzech ? "Vítejte zpět" : "Welcome back"
    }
    static func tapToSignIn(_ name: String) -> String {
        isCzech ? "Klepnutím se přihlaste pomocí \(name)" : "Tap to sign in with \(name)"
    }
    static func biometricSetupInfo(_ name: String) -> String {
        isCzech
            ? "\(name) bude nastaveno po prvním přihlášení"
            : "\(name) will be set up after your first sign in"
    }
    static func useBiometricPrompt(_ name: String) -> String {
        isCzech ? "Použít \(name)?" : "Use \(name)?"
    }
    static func enableBiometricBtn(_ name: String) -> String {
        isCzech ? "Aktivovat \(name)" : "Enable \(name)"
    }
    static var notNow: String { isCzech ? "Teď ne" : "Not Now" }
    static func signInInstantly(_ name: String) -> String {
        isCzech
            ? "Přihlaste se okamžitě pomocí \(name) místo zadávání hesla pokaždé."
            : "Sign in instantly with \(name) instead of typing your password every time."
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Biometric Lock
    // ─────────────────────────────────────────────────────────────────────────

    static var authFailed:   String { isCzech ? "Ověření selhalo. Zkuste to znovu." : "Authentication failed. Try again." }
    static var usePasscode:  String { isCzech ? "Použít kód"   : "Use Passcode" }
    static var unlockReason: String { isCzech ? "Odemknout EL Parking" : "Unlock EL Parking" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Pending Approval
    // ─────────────────────────────────────────────────────────────────────────

    static var accountPending:      String { isCzech ? "Čekáme na schválení"  : "Account Pending" }
    static var accountPendingMsg:   String {
        isCzech
            ? "Váš účet byl vytvořen a čeká na schválení správce."
            : "Your account has been created and is\nwaiting for administrator approval."
    }
    static var contactITAdmin:      String {
        isCzech
            ? "Kontaktujte svého IT správce pro aktivaci účtu."
            : "Contact your IT administrator to activate your account."
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: What's New
    // ─────────────────────────────────────────────────────────────────────────

    static var whatsNew: String { isCzech ? "Co je nového" : "What's New" }
    static var versionLabel: String { isCzech ? "Verze" : "Version" }
    static var releasedLabel: String { isCzech ? "Vydáno" : "Released" }

    // Onboarding page titles (3-page Apple-style walkthrough)
    static var onboardingPage2Title: String { isCzech ? "Zůstaňte v obraze" : "Stay in the Loop" }
    static var onboardingPage3Title: String { isCzech ? "Dobré vědět" : "Good to Know" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Onboarding
    // ─────────────────────────────────────────────────────────────────────────

    static var onboardingWelcomeTitle:    String { isCzech ? "Vítejte v\nEL Parking"   : "Welcome to\nEL Parking" }
    static var onboardingWelcomeSub:      String { isCzech ? "Váš chytrý průvodce parkováním" : "Your smart parking companion" }
    static var onboardingWelcomeDesc:     String {
        isCzech
            ? "Rezervujte místo za vteřiny, nechte si připomenout zahájení a spravujte své rezervace – vše z vašeho telefonu."
            : "Book spots in seconds, get reminded before your session starts, and manage your reservations — all from your phone."
    }
    static var onboardingHomeTitle:       String { isCzech ? "Domů"              : "Home" }
    static var onboardingHomeSub:         String { isCzech ? "Váš denní přehled" : "Your daily dashboard" }
    static var onboardingHomeDesc:        String {
        isCzech
            ? "Podívejte se na svou aktivní rezervaci, nadcházející relace a dnešní stav parkování na první pohled."
            : "See your active booking, upcoming sessions and today's parking status at a glance."
    }
    static var onboardingGridTitle:       String { isCzech ? "Přehled parkování"          : "Parking Grid" }
    static var onboardingGridSub:         String { isCzech ? "Dostupnost míst v reálném čase" : "Live spot availability" }
    static var onboardingGridDesc:        String {
        isCzech
            ? "Každé místo v reálném čase. Volná místa jsou zelená – klepnutím okamžitě zarezervujte. Obsazená místa ukazují, kdo je tam."
            : "Every spot in real time. Free spots are green — tap one to book instantly. Taken spots show who has them."
    }
    static var onboardingGridTip:         String {
        isCzech
            ? "Bezbariérová místa jsou jemně označena v rohu."
            : "Accessible spots are subtly marked in the corner."
    }
    static var onboardingBookTitle:       String { isCzech ? "Vytvořit rezervaci" : "Make a Booking" }
    static var onboardingBookSub:         String { isCzech ? "Vyberte, nastavte, potvrďte" : "Pick, set, confirm" }
    static var onboardingBookDesc:        String {
        isCzech
            ? "Zvolte místo, nastavte datum a čas a potvrďte. Můžete také rezervovat pro kolegu."
            : "Choose a spot, set your date and time, and confirm. You can also book for a colleague by name."
    }
    static var onboardingBookTip:         String {
        isCzech
            ? "Privilegovaní uživatelé mohou rezervovat s větším předstihem."
            : "Privileged users can book further in advance."
    }
    static var onboardingRemTitle:        String { isCzech ? "Chytrá připomenutí" : "Smart Reminders" }
    static var onboardingRemSub:          String { isCzech ? "Nikdy nezmeškejte svůj čas" : "Never miss your slot" }
    static var onboardingRemDesc:         String {
        isCzech
            ? "Aktivujte oznámení a zvolte, jak brzy vás upozorníme – od 30 minut do 2 dnů předem."
            : "Enable notifications and choose exactly how far ahead you're reminded — from 30 minutes to 2 days before."
    }
    static var onboardingWidgetsTitle:    String { isCzech ? "Widgety" : "Widgets" }
    static var onboardingWidgetsSub:      String { isCzech ? "Domovská i zamykací obrazovka" : "Home + Lock Screen" }
    static var onboardingWidgetsDesc:     String {
        isCzech
            ? "Přidejte si EL Parking widget na Domovskou nebo Zamykací obrazovku a mějte své místo, čas a dostupnost vždy na očích."
            : "Add EL Parking widgets to Home Screen or Lock Screen to keep your spot, time and availability visible at a glance."
    }
    static var onboardingWidgetsTip:      String {
        isCzech
            ? "Podržte prst na obrazovce, klepněte na + a vyhledejte \"EL Parking\"."
            : "Press and hold your screen, tap +, then search for \"EL Parking\"."
    }
    static var onboardingWindowsTitle:    String { isCzech ? "Kdy rezervovat"      : "When to Book" }
    static var onboardingWindowsSub:      String { isCzech ? "Okna dle vaší role"  : "Booking windows by role" }
    static var onboardingWindowsDesc:     String {
        isCzech
            ? "Standardní uživatelé rezervují na dnes nebo zítřek (po 18:00). Privilegovaní mohou rezervovat až 3 dny dopředu. Admini bez omezení."
            : "Standard users book for today or tomorrow (after 18:00). Privileged users book up to 3 days ahead. Admins have no date restrictions."
    }
    static var onboardingWindowsTip:      String {
        isCzech
            ? "Zítřejší slot se odemkne dnes ve 18:00."
            : "Tomorrow's slot unlocks at 18:00 today."
    }
    static var onboardingWarningsTitle:   String { isCzech ? "Férové hraní"        : "Fair Play" }
    static var onboardingWarningsSub:     String { isCzech ? "Systém varování"     : "The warning system" }
    static var onboardingWarningsDesc:    String {
        isCzech
            ? "Nevhodné chování může vést k varování od správce. Tři varování spustí dvoutýdenní pozastavení, které se po uplynutí doby automaticky zruší."
            : "Misbehaviour can earn you a warning from an admin. Three warnings trigger a 2-week suspension that lifts automatically when the time is up."
    }
    static var onboardingWarningsTip:     String {
        isCzech
            ? "O každém varování i obnovení budete okamžitě upozorněni."
            : "You'll be notified immediately for each warning and when your account is restored."
    }
    static var spotReservedForCompanyError: String {
        isCzech
            ? "Toto místo je vyhrazeno pro jinou skupinu. Všechna volná místa se otevírají pro všechny dnes od 8:00."
            : "This spot is reserved for another group. All free spots open to everyone from 8:00 today."
    }
    static var grandVisionTag: String { "GV" }
    static var onboardingSpotGroupsTitle: String { isCzech ? "Skupiny míst" : "Spot Groups" }
    static var onboardingSpotGroupsDesc: String {
        isCzech
            ? "Místa 74–76 jsou vyhrazena pro GrandVision; GrandVision parkuje pouze tam. Ostatní místa patří Essilor a Omega. Každý den od 8:00 jsou všechna volná místa otevřena pro všechny — pouze pro daný den."
            : "Spots 74–76 are reserved for GrandVision; GrandVision parks only there. All other spots belong to Essilor and Omega. Every day from 8:00, any free spot opens to everyone — for that day only."
    }
    static var onboardingPersonalizeTitle: String { isCzech ? "Přizpůsobte si\naplikaci" : "Make It\nYours" }
    static var changeAnytimeHint: String {
        isCzech ? "Kdykoli změníte v Nastavení → Vzhled." : "You can change this anytime in Settings → Appearance."
    }
    static var onboardingCalmTitle: String { isCzech ? "Klidná paleta" : "Calm Color Theme" }
    static var onboardingCalmDesc: String {
        isCzech
            ? "Preferujete jemnější vzhled? Přepněte na tlumenou severskou paletu v Nastavení → Vzhled."
            : "Prefer a softer look? Switch to the muted Nordic palette in Settings → Appearance."
    }
    static var onboardingDoneTitle:       String { isCzech ? "Vše připraveno!"     : "You're All Set!" }
    static var onboardingDoneSub:         String { isCzech ? "Pojďme parkovat"     : "Let's get parking" }
    static var onboardingDoneDesc:        String {
        isCzech
            ? "Přejděte na záložku Parkování a klepnutím na libovolné zelené místo vytvořte svou první rezervaci."
            : "Head to the Parking tab and tap any green spot to make your first booking."
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Admin — Users
    // ─────────────────────────────────────────────────────────────────────────

    static var userManagement:  String { isCzech ? "Správa uživatelů"  : "User Management" }

    // Admin dashboard sections & row subtitles
    static var adminSectionOverview:    String { isCzech ? "Přehled"       : "Overview" }
    static var adminSectionUsers:       String { isCzech ? "Uživatelé"     : "Users" }
    static var adminSectionContent:     String { isCzech ? "Obsah"         : "Content" }
    static var adminSectionAnalytics:   String { isCzech ? "Analytika"     : "Analytics" }
    static var adminSectionMaintenance: String { isCzech ? "Údržba"        : "Maintenance" }
    static var adminRowUsers:           String { isCzech ? "Uživatelé"     : "Users" }
    static var adminRowNewUser:         String { isCzech ? "Nový uživatel" : "New User" }
    static var adminRowCSVImport:       String { isCzech ? "Import CSV"    : "CSV Import" }
    static var adminRowSpots:           String { isCzech ? "Místa"         : "Spots" }
    static var adminRowPosts:           String { isCzech ? "Příspěvky"     : "Posts" }
    static var adminRowCards:           String { isCzech ? "Karty"         : "Cards" }
    static var adminRowTrends:          String { isCzech ? "Trendy"        : "Trends" }
    static var adminRowCleanup:         String { isCzech ? "Čištění"       : "Cleanup" }
    static var adminPurgeDeleting:      String { isCzech ? "Mažu…"         : "Deleting…" }

    static var all:             String { isCzech ? "Vše"               : "All" }
    static var pending:         String { isCzech ? "Čekající"          : "Pending" }
    static var activeFilter:    String { isCzech ? "Aktivní"           : "Active" }
    static var suspended:       String { isCzech ? "Pozastavení"       : "Suspended" }
    static var searchUsers:     String { isCzech ? "Hledat jménem nebo e-mailem…" : "Search by name or email…" }
    static var searchSpots:     String { isCzech ? "Hledat parkovací místo…"      : "Search parking spots…" }
    static var deselect:        String { isCzech ? "Zrušit výběr"      : "Done" }
    static var activateAs:      String { isCzech ? "Aktivovat jako:"   : "Activate as:" }
    static var selectAll:       String { isCzech ? "Vybrat vše"        : "Select All" }
    static var deselectAll:     String { isCzech ? "Zrušit výběr vše" : "Deselect All" }
    static var suspend:         String { isCzech ? "Pozastavit"        : "Suspend" }
    static var manage:          String { isCzech ? "Spravovat"         : "Manage" }
    static var restore:         String { isCzech ? "Obnovit"           : "Restore" }
    static var suspendUser:     String { isCzech ? "Pozastavit uživatele" : "Suspend User" }
    static var changeRole:      String { isCzech ? "Změnit roli"       : "Change Role" }
    static var activateUser:    String { isCzech ? "Aktivovat uživatele": "Activate User" }
    static var activate:        String { isCzech ? "Aktivovat"         : "Activate" }

    static func activateNUsers(_ n: Int) -> String {
        isCzech ? "Aktivovat \(n) uživatel\(n == 1 ? "e" : "ů")" : "Activate \(n) User\(n == 1 ? "" : "s")"
    }
    static func deleteNUsers(_ n: Int) -> String {
        isCzech ? "Smazat \(n) uživatel\(n == 1 ? "e" : "ů")" : "Delete \(n) User\(n == 1 ? "" : "s")"
    }
    static func selectAllCount(_ n: Int) -> String {
        isCzech ? "Vybrat vše (\(n))" : "Select All (\(n))"
    }
    static func suspendUserMsg(_ name: String) -> String {
        isCzech
            ? "Pozastavit \(name)? Ztratí přístup k aplikaci."
            : "Suspend \(name)? They will lose access to the app."
    }
    static func activateAsRole(_ role: String) -> String {
        isCzech ? "Aktivovat jako \(role)" : "Activate as \(role)"
    }

    static var noPendingUsers:    String { isCzech ? "Žádné čekající registrace.\nVšichni uživatelé jsou aktivní." : "No pending registrations.\nAll users are activated." }
    static var noActiveUsers:     String { isCzech ? "Zatím žádní aktivní uživatelé."  : "No active users yet." }
    static var noSuspendedUsers:  String { isCzech ? "Žádní pozastavení uživatelé."   : "No suspended users." }
    static var noUsersFound:      String { isCzech ? "Žádní uživatelé nenalezeni."    : "No users found." }
    static var noUsersMatchSearch:String { isCzech ? "Žádní uživatelé neodpovídají hledání." : "No users match your search." }

    static var reviewRequest:          String { isCzech ? "Zkontrolovat žádost"       : "Review Request" }
    static var approve:                String { isCzech ? "Schválit"                  : "Approve" }
    static var rejectAccount:         String { isCzech ? "Zamítnout žádost"          : "Reject Account" }
    static var rejectUser:             String { isCzech ? "Zamítnout"                 : "Reject" }
    static var rejectionReason:        String { isCzech ? "Důvod zamítnutí"           : "Reason for rejection" }
    static var rejectionReasonHint:    String { isCzech ? "Doporučujeme uvést důvod…" : "Explain why (optional)…" }
    static var accountRejected:        String { isCzech ? "Žádost zamítnuta"          : "Account Rejected" }
    static var accountRejectedMsg:     String { isCzech ? "Vaše registrace byla zamítnuta administrátorem." : "Your registration was rejected by an administrator." }
    static var rejectedReasonLabel:    String { isCzech ? "Důvod:"                   : "Reason:" }
    static var deleteUser:             String { isCzech ? "Smazat uživatele"          : "Delete User" }
    static var editVehicle:            String { isCzech ? "Upravit vozidlo"           : "Edit Vehicle" }
    static var registrationPlate:      String { isCzech ? "SPZ"                       : "Registration Plate" }
    static var carModel:               String { isCzech ? "Model vozu"                : "Car Model" }
    static var carBodyType:            String { isCzech ? "Typ karoserie"             : "Body Type" }
    static var carColorCustom:         String { isCzech ? "Vlastní"                   : "Custom" }
    static var userDeleted:            String { isCzech ? "Uživatel byl smazán"       : "User deleted" }

    static func confirmDeleteUser(_ name: String) -> String {
        isCzech
            ? "Opravdu smazat \(name)? Tato akce je nevratná. Budou smazány všechny rezervace a přístup bude zablokován."
            : "Are you sure you want to delete \(name)? This cannot be undone. All bookings will be removed and access revoked."
    }
    static func rejectedByAdmin(_ name: String) -> String {
        isCzech ? "Zamítnuto administrátorem \(name)" : "Rejected by administrator \(name)"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Admin — Stats
    // ─────────────────────────────────────────────────────────────────────────

    static var bookingStatistics:     String { isCzech ? "Statistiky rezervací"     : "Booking Statistics" }
    static var last30Days:            String { isCzech ? "POSLEDNÍCH 30 DNÍ"        : "LAST 30 DAYS" }
    static var statisticsDot:         String { isCzech ? "Statistiky."              : "Statistics." }
    static var loadingStats:          String { isCzech ? "Načítám statistiky…"      : "Loading statistics…" }
    static var totalBookingsStat:     String { isCzech ? "Celkem rezervací"         : "Total Bookings" }
    static var activeUsersStat:       String { isCzech ? "Aktivní uživatelé"        : "Active Users" }
    static var avgOccupancy:          String { isCzech ? "Průměrná obsazenost"      : "Avg Occupancy" }
    static var totalSpots:            String { isCzech ? "Celkem míst"              : "Total Spots" }
    static var bookingsByDay:         String { isCzech ? "Rezervace podle dne v týdnu" : "Bookings by Day of Week" }
    static var mostBookedSpots:       String { isCzech ? "Nejrezervovanější místa"  : "Most Booked Spots" }
    static var noBookingData:         String { isCzech ? "Pro toto období nejsou k dispozici žádná data o rezervacích." : "No booking data available for this period." }

    static var weekDays: [String] {
        isCzech
            ? ["Po", "Út", "St", "Čt", "Pá", "So", "Ne"]
            : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Admin — Info Cards
    // ─────────────────────────────────────────────────────────────────────────

    static var infoCards:         String { isCzech ? "Info karty"            : "Info Cards" }
    static var noInfoCards:       String { isCzech ? "Zatím žádné info karty": "No info cards yet" }
    static var tapPlusToAdd:      String { isCzech ? "Klepnutím na + přidejte první." : "Tap + to add the first one." }
    static var iconLabel:         String { isCzech ? "IKONA"                 : "ICON" }
    static var titleLabel:        String { isCzech ? "NÁZEV"                 : "TITLE" }
    static var descriptionLabel:  String { isCzech ? "POPIS"                 : "DESCRIPTION" }
    static var pushToAll:         String { isCzech ? "Odeslat všem uživatelům" : "Push to all users" }
    static var sendNotifOnSave:   String { isCzech ? "Odeslat okamžité oznámení při uložení" : "Send an instant notification when saving" }
    static var sendNotifOnPublish:String { isCzech ? "Odeslat okamžité oznámení při zveřejnění" : "Send an instant notification when publishing" }
    static var newInfoCard:       String { isCzech ? "Nová info karta"       : "New Info Card" }
    static var editInfoCard:      String { isCzech ? "Upravit info kartu"    : "Edit Info Card" }
    static var infoTitlePlaceholder: String { isCzech ? "např. Parkovací hodiny"    : "e.g. Parking Hours" }
    static var infoDescPlaceholder:  String { isCzech ? "např. 07:00 – 18:00 v pracovní dny" : "e.g. 07:00 – 18:00 weekdays" }
    static var addCard:           String { isCzech ? "Přidat kartu"          : "Add Card" }
    static var addCardAndNotify:  String { isCzech ? "Přidat a upozornit" : "Add & Notify" }
    static var saveAndNotify:     String { isCzech ? "Uložit a upozornit" : "Save & Notify" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Admin — Announcements
    // ─────────────────────────────────────────────────────────────────────────

    static var newsAndAnnouncements:String { isCzech ? "Novinky a oznámení"    : "News & Announcements" }
    static var noAnnouncementsYet:  String { isCzech ? "Zatím žádná oznámení"  : "No Announcements Yet" }
    static var tapPlusToCreate:     String { isCzech ? "Klepnutím na + vytvořte první příspěvek" : "Tap + to create your first post" }
    static var newAnnouncement:     String { isCzech ? "Nové oznámení"          : "New Announcement" }
    static var editAnnouncement:    String { isCzech ? "Upravit oznámení"       : "Edit Announcement" }
    static var postAnnouncement:    String { isCzech ? "Zveřejnit" : "Post" }
    static var pinned:              String { isCzech ? "Připnuto"               : "Pinned" }
    static var alwaysShownAtTop:    String { isCzech ? "Vždy zobrazeno nahoře"  : "Always shown at the top" }
    static var setExpiry:           String { isCzech ? "Nastavit vypršení"       : "Set Expiry" }
    static var autoHideAfterDate:   String { isCzech ? "Automaticky skrýt po zvoleném datu" : "Auto-hide after a chosen date" }
    static var visibleToAllOnHome:  String { isCzech ? "Viditelné pro všechny uživatele na domovské obrazovce" : "Visible to all users on Home" }
    static var activeLabel:         String { isCzech ? "Aktivní"                : "Active" }
    static var expired:             String { isCzech ? "Vypršelo"               : "Expired" }
    static var expiresOn:           String { isCzech ? "Vyprší dne"             : "Expires on" }
    static var announcementTitlePlaceholder: String { isCzech ? "Název oznámení…"     : "Announcement title…" }
    static var announcementBodyPlaceholder:  String { isCzech ? "Napište podrobnou zprávu…" : "Write a detailed message…" }

    static func activeSectionHeader(_ n: Int)   -> String { isCzech ? "Aktivní (\(n))"     : "Active (\(n))" }
    static func inactiveSectionHeader(_ n: Int) -> String { isCzech ? "Neaktivní (\(n))"   : "Inactive (\(n))" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Errors / Feedback
    // ─────────────────────────────────────────────────────────────────────────

    static var errorTitle:     String { isCzech ? "Chyba"                      : "Error" }
    static var noNetwork:      String { isCzech ? "Žádné připojení k internetu": "No internet connection" }
    static var bookingSuccess: String { isCzech ? "Rezervace potvrzena"         : "Booking confirmed" }
    static var bookingFailed:  String { isCzech ? "Rezervace se nezdařila"      : "Booking failed" }
    static var spotTaken:      String { isCzech ? "Místo je již obsazeno"       : "This spot is already booked" }

    // Admin: Cancel Booking
    static var adminCancelBooking: String { isCzech ? "Správce: Zrušit rezervaci" : "Admin: Cancel Booking" }
    static var notifyUserTitle: String { isCzech ? "Upozornit uživatele?" : "Notify the user?" }
    static func notifyUserMessage(_ name: String) -> String {
        isCzech ? "Dejte vědět uživateli \(name), že jeho rezervace byla zrušena." : "Let \(name) know their booking was cancelled."
    }
    static var notifyViaMessage: String { isCzech ? "Zpráva (SMS)" : "Message (SMS)" }
    static var notifyViaEmail:   String { isCzech ? "E-mail" : "Email" }
    static var notifyLater:      String { isCzech ? "Teď ne" : "Not now" }
    static var bookingCancelledSubject: String { isCzech ? "Zrušená rezervace parkování" : "Parking booking cancelled" }
    static var phoneNumber:      String { isCzech ? "Telefon" : "Phone" }
    static var phoneOptional:    String { isCzech ? "Telefon (volitelné)" : "Phone (optional)" }
    static var cancelAndNotify:    String { isCzech ? "Zrušit a odeslat oznámení" : "Cancel & Notify" }
    static var cancelBookingFailed: String { isCzech ? "Rezervaci se nepodařilo zrušit" : "Could Not Cancel Booking" }
    static var adminBookingProtectedTitle: String { isCzech ? "Rezervace správce je chráněna" : "Admin Booking Protected" }

    static var adminBookingProtectedMessage: String {
        isCzech
            ? "Jeden správce nemůže zrušit rezervaci jiného správce."
            : "One admin cannot cancel another admin's booking."
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Admin — Dashboard
    // ─────────────────────────────────────────────────────────────────────────

    static var administrationLabel: String { isCzech ? "SPRÁVA"     : "ADMINISTRATION" }
    static var dashboardDot:        String { isCzech ? "Přehled."   : "Dashboard." }
    static var spotManagement:      String { isCzech ? "Správa míst": "Spot Management" }
    static var statsSubtitle:       String { isCzech ? "30denní obsazenost, nejlepší místa a trendy" : "30-day occupancy, top spots & trends" }

    static func adminPendingSubtitle(total: Int, pending: Int) -> String {
        if pending == 0 {
            return isCzech ? "\(total) uživatelů celkem – všichni aktivní" : "\(total) total users — all activated"
        } else if pending == 1 {
            return isCzech ? "1 uživatel čeká na aktivaci" : "1 user awaiting activation"
        } else {
            return isCzech ? "\(pending) uživatelů čeká na aktivaci" : "\(pending) users awaiting activation"
        }
    }

    static func adminSpotSubtitle(blocked: Int, total: Int) -> String {
        blocked == 0
            ? (isCzech ? "\(total) míst, žádné blokované" : "\(total) spots, none blocked")
            : (isCzech ? "\(blocked) z \(total) míst blokováno" : "\(blocked) of \(total) spots blocked")
    }

    static func adminAnnouncementSubtitle(_ count: Int) -> String {
        if count == 0 { return isCzech ? "Žádná aktivní oznámení" : "No active announcements" }
        if isCzech { return "\(count) aktivní příspěvek\(count >= 5 ? "ů" : count >= 2 ? "y" : "")" }
        return "\(count) active post\(count == 1 ? "" : "s")"
    }

    static func adminInfoSubtitle(_ count: Int) -> String {
        if count == 0 { return isCzech ? "Žádné info karty – klepnutím přidejte" : "No info cards — tap to add some" }
        if isCzech { return "\(count) kart\(count == 1 ? "a" : count < 5 ? "y" : "") na domovské obrazovce" }
        return "\(count) card\(count == 1 ? "" : "s") on Home screen"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Message (optional) label — Announcements
    // ─────────────────────────────────────────────────────────────────────────

    static var messageOptional: String { isCzech ? "ZPRÁVA (NEPOVINNÉ)" : "MESSAGE (OPTIONAL)" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Admin — Spot Management
    // ─────────────────────────────────────────────────────────────────────────

    static var total:        String { isCzech ? "Celkem"      : "Total" }
    static var unblock:      String { isCzech ? "Odblokovat"  : "Unblock" }
    static var blockedBadge: String { isCzech ? "BLOKOVÁNO"   : "BLOCKED" }

    static func blockSelected(_ count: Int) -> String {
        if count == 0 { return isCzech ? "Blokovat" : "Block" }
        return isCzech ? "Blokovat (\(count))" : "Block (\(count))"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Finish Registration
    // ─────────────────────────────────────────────────────────────────────────

    static var finishRegistration:      String { isCzech ? "Dokončit registraci"             : "Complete Registration" }
    static var finishRegistrationSub:   String { isCzech ? "Doplňte informace o vozidle"     : "Add your vehicle details to get started" }
    static var accountCreatedByAdmin:   String { isCzech ? "Účet vytvořil správce"            : "Account created by admin" }
    static var carColor:                String { isCzech ? "Barva vozu"                       : "Car Color" }
    static var selectCarColor:          String { isCzech ? "Vyberte barvu"                    : "Select Color" }
    static var keepTempPassword:        String { isCzech ? "Ponechat dočasné heslo"           : "Keep temporary password" }
    static var setNewPassword:          String { isCzech ? "Nastavit nové heslo"              : "Set new password" }
    static var newPasswordOptional:     String { isCzech ? "Nové heslo (nepovinné)"           : "New password (optional)" }
    static var confirmPasswordLabel:    String { isCzech ? "Potvrdit heslo"                   : "Confirm Password" }
    static var passwordsDoNotMatch:     String { isCzech ? "Hesla se neshodují"               : "Passwords do not match" }
    static var passwordTooShortHint:    String { isCzech ? "Heslo musí mít alespoň 6 znaků"  : "At least 6 characters required" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Booking Error Messages
    // ─────────────────────────────────────────────────────────────────────────

    static var maxDelegatedPerDayError: String {
        isCzech
            ? "Již jste dnes rezervovali 2 místa pro ostatní."
            : "You've already booked 2 spots for others today."
    }
    static var selfDelegationNotAllowed: String {
        isCzech
            ? "Pro rezervaci pro jiné zadejte jiný e-mail než svůj."
            : "For delegated booking, enter a different email than your own."
    }
    static var completeRegistration:    String { isCzech ? "Dokončit registraci"              : "Complete Registration" }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Admin — Create User
    // ─────────────────────────────────────────────────────────────────────────

    static var adminCreateUser:         String { isCzech ? "Vytvořit"              : "Create" }
    static var adminCreateUserSubtitle: String { isCzech ? "Vytvořte účet a sdílejte přihlašovací údaje" : "Create account and share credentials" }
    static var adminCreateUserTitle:    String { isCzech ? "Nový uživatel"                   : "New User" }
    static var generatePassword:        String { isCzech ? "Vygenerovat heslo"               : "Generate Password" }
    static var tempPassword:            String { isCzech ? "Dočasné heslo"                   : "Temporary Password" }
    static var shareCredentials:        String { isCzech ? "Sdílet přihlašovací údaje"       : "Share Credentials" }
    static var sendViaEmail:            String { isCzech ? "Poslat e-mailem"                  : "Send via Email" }
    static var credentialsCopied:       String { isCzech ? "Zkopírováno!"                    : "Copied!" }
    static var copyToClipboard:         String { isCzech ? "Kopírovat do schránky"            : "Copy to Clipboard" }
    static var passwordTooShort:        String { isCzech ? "Heslo musí mít alespoň 6 znaků"  : "Password must be at least 6 characters" }
    static var assignRole:              String { isCzech ? "Přiřadit roli"                   : "Assign Role" }
    static var companyBadge:            String { isCzech ? "Firemní značka"                   : "Company Badge" }
    static var companyBadgeHint:        String { isCzech ? "Doplňuje se automaticky podle domény e-mailu, ale správce ji může změnit." : "Auto-detected from email domain, but admins can override it." }
    static var noneLabel:               String { isCzech ? "Žádná"                            : "None" }
    static var omegaLabel:              String { isCzech ? "Omega"                            : "Omega" }
    static var essilorLuxotticaLabel:   String { isCzech ? "EssilorLuxottica"                 : "EssilorLuxottica" }
    static var grandVisionLabel:        String { isCzech ? "Grand Vision"                     : "Grand Vision" }
    static var userCreated:             String { isCzech ? "Uživatel vytvořen!"               : "User created!" }
    static var credentialsEmailSubject: String { isCzech ? "EL Parking – Přihlašovací údaje" : "EL Parking – Your login credentials" }

    static var delegatedBookingEmailSubject: String {
        isCzech ? "EL Parking – Rezervace parkovacího místa" : "EL Parking – Parking space reserved for you"
    }
    static func delegatedBookingShareBody(name: String, spot: String, date: String, timeFrom: String, timeTo: String, rangeEndDate: String? = nil) -> String {
        let dateStr = rangeEndDate.map { "\(date) – \($0)" } ?? date
        return isCzech
            ? "Ahoj \(name),\n\nrezervoval/a jsem pro tebe parkovací místo \(spot) na \(dateStr) od \(timeFrom) do \(timeTo).\n\nMísto: \(AppConfig.locationName)\nMapa: \(AppConfig.googleMapsURL)\n\nTato rezervace je vytvořena interně, nemusíš ji potvrzovat v aplikaci."
            : "Hi \(name),\n\nI've booked parking space \(spot) for you on \(dateStr) from \(timeFrom) to \(timeTo).\n\nLocation: \(AppConfig.locationName)\nMap: \(AppConfig.googleMapsURL)\n\nThis reservation is arranged internally; no app action is needed from your side."
    }

    // ── Bulk Import ──────────────────────────────────────────────────────────
    static var bulkImport:             String { isCzech ? "Hromadný import"                  : "Bulk Import" }
    static var bulkImportSubtitle:     String { isCzech ? "Vytvořit více účtů najednou"      : "Create multiple accounts at once" }
    static var bulkImportHint:         String { isCzech
        ? "Jeden uživatel na řádek: Celé jméno, email@firma.com"
        : "One user per line: Full Name, email@company.com" }
    static var bulkImportPlaceholder:  String { isCzech
        ? "Jan Novák, jan.novak@essilor.com\nAnna Svobodová, anna.svobodova@luxottica.com"
        : "John Smith, john.smith@essilor.com\nJane Doe, jane.doe@luxottica.com" }
    static func bulkImportN(_ n: Int) -> String {
        isCzech
            ? "Importovat \(n) uživatel\(n == 1 ? "e" : "ů")"
            : "Import \(n) User\(n == 1 ? "" : "s")"
    }
    static var bulkImportDone:         String { isCzech ? "Import dokončen"                  : "Import Complete" }
    static var preview:                String { isCzech ? "Náhled"                            : "Preview" }
    static var importing:              String { isCzech ? "Importuji…"                        : "Importing…" }
    static var createdLabel:           String { isCzech ? "Vytvořeno"                         : "Created" }
    static var failedLabel:            String { isCzech ? "Selhalo"                           : "Failed" }
    static var copyCredentialTemplate: String { isCzech ? "Kopírovat šablonu přihlašovacích údajů" : "Copy Credential Template" }

    static func bulkCredentialsTemplate(results: [(name: String, email: String, password: String)]) -> String {
        var t = isCzech
            ? "=== EL Parking — Přihlašovací údaje ===\n\nStáhněte aplikaci EL Parking a přihlaste se níže uvedenými údaji.\nPo prvním přihlášení budete vyzváni k dokončení profilu.\n\n"
            : "=== EL Parking — Account Credentials ===\n\nDownload the EL Parking app and sign in with the credentials below.\nYou will be asked to complete your profile on first login.\n\n"
        for r in results {
            t += "---\n"
            t += isCzech
                ? "Jméno: \(r.name)\nE-mail: \(r.email)\nHeslo: \(r.password)\n\n"
                : "Name: \(r.name)\nEmail: \(r.email)\nPassword: \(r.password)\n\n"
        }
        t += isCzech ? "=== Konec ===" : "=== End ==="
        return t
    }
    static func credentialsEmailBody(name: String, email: String, password: String) -> String {
        if isCzech {
            return """
            Dobrý den, \(name),

            Váš účet EL Parking byl vytvořen správcem.

            E-mail: \(email)
            Dočasné heslo: \(password)

            Přihlaste se do aplikace a dokončete registraci – zadejte SPZ, popis vozu a vyberte barvu. Heslo si můžete změnit nebo ponechat.

            S pozdravem,
            Správa EL Parking
            """
        } else {
            return """
            Hello \(name),

            Your EL Parking account has been created by an administrator.

            Email: \(email)
            Temporary password: \(password)

            Please sign in to the app and complete your registration by providing your vehicle details. You can keep the temporary password or set a new one.

            Best regards,
            EL Parking Administration
            """
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Recent Activations
    // ─────────────────────────────────────────────────────────────────────────

    static var recentActivations:       String { isCzech ? "Poslední aktivace"               : "Recent Activations" }
    static var noRecentActivations:     String { isCzech ? "Žádné nedávné aktivace"           : "No recent activations" }
    static var activated:               String { isCzech ? "Aktivováno"                       : "Activated" }
    static var pendingActivation:       String { isCzech ? "Čeká na aktivaci"                 : "Pending activation" }
    static func lastRefreshed(_ relative: String) -> String {
        isCzech ? "Aktualizováno \(relative)" : "Updated \(relative)"
    }
    static func adminCreateUserCardSubtitle(_ count: Int) -> String {
        count == 0
            ? (isCzech ? "Vytvořte nový uživatelský účet" : "Create a new user account")
            : (isCzech ? "\(count) uživatel\(count == 1 ? "" : "ů") čeká na dokončení registrace"
                       : "\(count) user\(count == 1 ? "" : "s") pending activation")
    }
}
