//
//  AppReleaseNotes.swift
//  EL PARKING APP
//
//  Hardcoded release notes shown once per version on first launch after an update.
//  ─────────────────────────────────────────────────────────────────────────────
//  HOW TO ADD A NEW VERSION:
//    1. Bump CFBundleShortVersionString in Xcode (e.g. "1.3")
//    2. Prepend a new AppRelease entry to the `all` array below with that version string
//    3. Ship — the What's New sheet will appear automatically on first launch
//
//  Only add entries for feature releases; skip pure bug-fix builds.
//

import Foundation

// MARK: - Models

struct AppRelease {
    let version: String
    let features: [ReleaseFeature]
}

struct ReleaseFeature {
    let icon: String        // SF Symbol name
    let color: String       // AppConfig color key: "accent", "green", "orange", "red", "blue"
    let title: String
    let description: String
}

// MARK: - Release Notes Registry

struct AppReleaseNotes {

    // ─── Prepend new releases at the top ──────────────────────────────────────
    // computed var so L10n strings reflect the current language at access time
    static var all: [AppRelease] {[

        AppRelease(
            version: "4.0",
            features: [
                ReleaseFeature(
                    icon: "leaf.fill",
                    color: "accent",
                    title: L10n.lang == .czech ? "Klidná barevná paleta" : "Calm Color Theme",
                    description: L10n.lang == .czech
                        ? "Tlumená severská paleta — méně křiklavých barev, méně vizuálního šumu, klidnější parkování. Přepněte v Nastavení → Vzhled."
                        : "A muted, Nordic-inspired palette — softer colors, less visual noise, calmer parking. Switch anytime in Settings → Appearance."
                ),
                ReleaseFeature(
                    icon: "sparkles",
                    color: "accent",
                    title: L10n.lang == .czech ? "Nový vzhled" : "Refreshed Design",
                    description: L10n.lang == .czech
                        ? "Liquid Glass povrchy, plynulejší animace, nová úvodní obrazovka a klidnější domovská stránka."
                        : "Liquid Glass surfaces, smoother animations, a new splash screen, and a calmer home screen."
                ),
                ReleaseFeature(
                    icon: "car.fill",
                    color: "green",
                    title: L10n.lang == .czech ? "Vaše auto zaparkuje" : "Your Car Parks In",
                    description: L10n.lang == .czech
                        ? "Po potvrzení rezervace vaše vlastní auto zajede na místo — s jemnou haptickou odezvou."
                        : "After confirming a booking, your own car drives into the spot — with a satisfying haptic thunk."
                ),
                ReleaseFeature(
                    icon: "square.grid.2x2.fill",
                    color: "blue",
                    title: L10n.lang == .czech ? "Rychlé akce" : "Quick Actions",
                    description: L10n.lang == .czech
                        ? "Podržte ikonu aplikace pro rezervaci, moje rezervace, navigaci nebo správu."
                        : "Long-press the app icon to book, see bookings, navigate, or open admin."
                ),
                ReleaseFeature(
                    icon: "checkmark.shield.fill",
                    color: "green",
                    title: L10n.lang == .czech ? "Bezpečnější smazání účtu" : "Safer Account Deletion",
                    description: L10n.lang == .czech
                        ? "Smazání účtu nyní vyžaduje potvrzení přes Face ID."
                        : "Deleting your account now requires Face ID confirmation."
                ),
            ]
        ),

        AppRelease(
            version: "2.0",
            features: [
                ReleaseFeature(
                    icon: "square.and.arrow.up.fill",
                    color: "accent",
                    title: L10n.lang == .czech ? "Sdílení rezervace"   : "Share Your Booking",
                    description: L10n.lang == .czech
                        ? "Sdílejte krásnou vizitku parkování jako obrázek nebo text – ideální pro Teams nebo WhatsApp."
                        : "Share a beautifully branded parking card as an image or text — perfect for Teams or WhatsApp."
                ),
                ReleaseFeature(
                    icon: "globe",
                    color: "blue",
                    title: L10n.lang == .czech ? "Čeština & English"   : "Czech & English",
                    description: L10n.lang == .czech
                        ? "Aplikace teď mluví vaším jazykem. Přepínejte mezi angličtinou a češtinou kdykoli v Nastavení."
                        : "The app now speaks your language. Switch between English and Čeština anytime in Settings."
                ),
                ReleaseFeature(
                    icon: "bolt.shield.fill",
                    color: "green",
                    title: L10n.lang == .czech ? "Ochrana konfliktů"   : "Conflict Protection",
                    description: L10n.lang == .czech
                        ? "Atomické transakce zabraňují dvojitým rezervacím – i při současném klepnutí dvou uživatelů."
                        : "Atomic booking transactions prevent double-bookings — even if two people tap at the exact same moment."
                ),
                ReleaseFeature(
                    icon: "wifi.slash",
                    color: "orange",
                    title: L10n.lang == .czech ? "Offline režim"       : "Offline Awareness",
                    description: L10n.lang == .czech
                        ? "Živý banner vás upozorní při výpadku připojení a toast notifikace informují o chybách."
                        : "A live banner warns you when you lose connection, and toast notifications keep you informed of errors."
                ),
                ReleaseFeature(
                    icon: "person.3.fill",
                    color: "accent",
                    title: L10n.lang == .czech ? "Hromadná aktivace"   : "Admin Bulk Activate",
                    description: L10n.lang == .czech
                        ? "Správci nyní mohou vybrat a aktivovat více čekajících uživatelů najednou."
                        : "Admins can now select and activate multiple pending users at once — no more one-by-one approvals."
                ),
                ReleaseFeature(
                    icon: "info.circle.fill",
                    color: "blue",
                    title: L10n.lang == .czech ? "Info karty"          : "Info Cards",
                    description: L10n.lang == .czech
                        ? "Správci mohou zveřejňovat info karty na domovské obrazovce s vlastními ikonami a push notifikací."
                        : "Admins can publish info cards on the home screen with custom icons — and optionally push-notify everyone."
                ),
            ]
        ),

        AppRelease(
            version: "1.1",
            features: [
                ReleaseFeature(
                    icon: "hand.wave.fill",
                    color: "accent",
                    title: L10n.lang == .czech ? "Průvodce aplikací"   : "App Guide",
                    description: L10n.lang == .czech
                        ? "Noví uživatelé nyní projdou interaktivním průvodcem každé funkce při prvním přihlášení."
                        : "New users now get an interactive walkthrough of every feature on their very first login."
                ),
                ReleaseFeature(
                    icon: "bell.badge.fill",
                    color: "orange",
                    title: L10n.lang == .czech ? "Vlastní připomenutí" : "Custom Reminders",
                    description: L10n.lang == .czech
                        ? "Nastavte přesně, jak brzy vás upozorníme – dny, hodiny a minuty před zahájením rezervace."
                        : "Pick exactly how far ahead you're notified — days, hours and minutes before your booking starts."
                ),
                ReleaseFeature(
                    icon: "faceid",
                    color: "accent",
                    title: L10n.lang == .czech ? "Chytřejší Face ID"   : "Smarter Face ID",
                    description: L10n.lang == .czech
                        ? "Rychlé přepnutí aplikace již nespustí opětovné zamčení. Face ID se ptá až po 30 sekundách v pozadí."
                        : "Quick app switches no longer trigger a re-lock. Face ID only prompts after 30 seconds in the background."
                ),
                ReleaseFeature(
                    icon: "wifi.slash",
                    color: "blue",
                    title: L10n.lang == .czech ? "Offline přehled"     : "Offline Parking Grid",
                    description: L10n.lang == .czech
                        ? "Místa se načítají z mezipaměti i offline, takže přehled je vždy viditelný."
                        : "Parking spots now load from cache when offline, so the grid is always visible."
                ),
                ReleaseFeature(
                    icon: "person.2.fill",
                    color: "green",
                    title: L10n.lang == .czech ? "Face ID pro každého" : "Per-User Face ID Prompt",
                    description: L10n.lang == .czech
                        ? "Odhlášení resetuje dotaz na Face ID, takže každý uživatel zařízení dostane vlastní nabídku."
                        : "Signing out resets the setup prompt so each user on the device gets asked individually."
                ),
            ]
        ),

    ]}
    // ──────────────────────────────────────────────────────────────────────────

    /// Returns the release notes for the currently installed version, or nil if none exist.
    static var forCurrentVersion: AppRelease? {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return all.first { $0.version == v }
    }

    /// Intro shown once for each user/device on first authenticated launch.
    static var firstLaunchIntro: AppRelease {
        AppRelease(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            features: [
                ReleaseFeature(
                    icon: "sparkles",
                    color: "accent",
                    title: L10n.lang == .czech ? "Vítejte v EL Parking" : "Welcome to EL Parking",
                    description: L10n.lang == .czech
                        ? "Rychlé rezervace, chytrá připomenutí a přehled parkování v jednom čistém prostoru."
                        : "Fast booking, smart reminders, and clear parking visibility in one focused app."
                ),
                ReleaseFeature(
                    icon: "calendar.badge.plus",
                    color: "blue",
                    title: L10n.lang == .czech ? "Rezervujte za pár sekund" : "Book in Seconds",
                    description: L10n.lang == .czech
                        ? "Vyberte místo, čas a potvrďte. Aplikace hlídá kolize za vás."
                        : "Pick a spot, choose time, and confirm. Collision checks are handled for you."
                ),
                ReleaseFeature(
                    icon: "bell.badge.fill",
                    color: "orange",
                    title: L10n.lang == .czech ? "Mějte vše pod kontrolou" : "Stay in Control",
                    description: L10n.lang == .czech
                        ? "Nastavte si notifikace přesně podle sebe a mějte denní plán vždy po ruce."
                        : "Tune reminders to your workflow and keep your daily plan always within reach."
                )
            ]
        )
    }
}
