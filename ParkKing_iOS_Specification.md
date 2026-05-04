# ParkKing iOS App — Full Technical Specification

**Version:** 1.0
**Date:** 2026-03-24
**Source:** Reverse-engineered from Microsoft Power Apps canvas app "Parking EL Prague"
**Target:** Native iOS (SwiftUI, iOS 17+)

---

## 1. PURPOSE

Office parking reservation system for EssilorLuxottica Prague (Karlín, Rohanské nábřeží 721/39). Users book numbered parking spots for date+time ranges, view their bookings, see a live overview grid of all spots, and cancel bookings. Admins can cancel any booking. A "Book for Others" flow sends HTML email confirmations to third parties.

---

## 2. ARCHITECTURE

### 2.1 Pattern

MVVM + Repository pattern.

```
┌─────────────────────────────────────────┐
│  Views (SwiftUI)                        │
│  HomeView · MyBookingsView · OverviewView│
│  ParkingSchemeView · BookForOthersView  │
├─────────────────────────────────────────┤
│  ViewModels                             │
│  BookingViewModel · OverviewViewModel   │
│  UserViewModel                          │
├─────────────────────────────────────────┤
│  Repository Layer (protocol-based)      │
│  BookingRepository  ← conforms to →     │
│  ├─ MockBookingRepository  (v1, local)  │
│  └─ RemoteBookingRepository (v2, API)   │
├─────────────────────────────────────────┤
│  Models (value types)                   │
│  ParkingSpot · Booking · User · TimeSlot│
└─────────────────────────────────────────┘
```

### 2.2 Key Design Decisions

- **Protocol-driven data layer.** All data access goes through `BookingRepositoryProtocol`. The v1 implementation uses in-memory arrays with hardcoded test data. Swapping to a real backend (SharePoint REST, Firebase, custom API) requires only a new conforming type — zero view/viewmodel changes.
- **`@Observable` macro** (iOS 17) for ViewModels; no Combine needed.
- **No external dependencies** in v1. Pure SwiftUI + Foundation.

### 2.3 File/Folder Structure

```
ParkKing/
├── App/
│   └── ParkKingApp.swift              // @main, environment injection
├── Models/
│   ├── ParkingSpot.swift
│   ├── Booking.swift
│   ├── AppUser.swift
│   └── TimeSlot.swift
├── Repositories/
│   ├── BookingRepositoryProtocol.swift
│   └── MockBookingRepository.swift    // ← SWAP TARGET for real backend
├── ViewModels/
│   ├── BookingViewModel.swift
│   ├── OverviewViewModel.swift
│   └── UserViewModel.swift
├── Views/
│   ├── MainTabView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── BookForOthersView.swift
│   ├── Bookings/
│   │   ├── MyBookingsView.swift
│   │   └── BookingCardView.swift
│   ├── Overview/
│   │   ├── OverviewView.swift
│   │   └── SpotTileView.swift
│   ├── Scheme/
│   │   └── ParkingSchemeView.swift
│   └── Components/
│       ├── GlassCard.swift
│       └── TabBarView.swift
├── Config/
│   └── AppConfig.swift                // ← ALL hardcoded values live here
├── Extensions/
│   └── Date+Helpers.swift
└── Assets.xcassets/
    ├── AppIcon
    ├── parking-scheme.imageset/       // floor plan PNG
    └── el-logo.imageset/             // EssilorLuxottica logo
```

---

## 3. DATA MODELS

### 3.1 ParkingSpot

```swift
// ── Config/AppConfig.swift ──────────────────────────────────────
// MARK: - ⚙️ CONFIGURABLE — Edit this struct to change app behavior

struct AppConfig {

    // MARK: Parking Spots
    // ✏️ ADD/REMOVE spots here. This is the single source of truth.
    static let allParkingSpots: [ParkingSpot] = [
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
        ParkingSpot(id: "75", label: "Parking 75"),  // ⚠️ currently temp-blocked (see blockedSpots)
        ParkingSpot(id: "76", label: "Parking 76"),  // ⚠️ currently temp-blocked (see blockedSpots)
        ParkingSpot(id: "80", label: "Parking 80", isAccessible: true),  // ♿
        ParkingSpot(id: "81", label: "Parking 81"),
        ParkingSpot(id: "82", label: "Parking 82"),
    ]

    // MARK: Temporarily Blocked Spots
    // ✏️ Spots listed here appear in the master list but cannot be booked.
    static let blockedSpotIDs: Set<String> = ["75"]
    // Power Apps also had "76" blocked at times — add/remove as needed.

    // MARK: Authorized Cancelers (admin emails)
    // ✏️ These users can cancel ANY booking from the Overview screen.
    static let authorizedCancelers: Set<String> = [
        "stiv.malakjan@ext.essilor.com",
        "katerina.zimova@essilor.cz",
        "zimovak@essilor.cz",
        "evelyna.leirvik@essilor.cz",
        "leirvike@essilorluxottica.id",
    ]

    // MARK: Time Slots
    // ✏️ Available booking hours. Displayed in dropdowns.
    static let availableTimeSlots: [String] = [
        "07:00", "08:00", "09:00", "10:00", "11:00",
        "12:00", "13:00", "14:00", "15:00", "16:00", "17:00"
    ]
    static let defaultTimeFrom: String = "07:00"
    static let defaultTimeTo: String = "17:00"

    // MARK: Booking Constraints
    // ✏️ Self-booking: max 7 days ahead, max 5-day duration.
    static let selfBookingMaxAdvanceDays: Int = 7
    static let selfBookingMaxDurationDays: Int = 5

    // ✏️ Book-for-others: max 30 days ahead, max 10-day duration.
    static let othersBookingMaxAdvanceDays: Int = 30
    static let othersBookingMaxDurationDays: Int = 10

    // MARK: Auto-Advance After 17:00
    // ✏️ After this hour (24h), date pickers default to tomorrow.
    static let autoAdvanceHour: Int = 17

    // MARK: Location
    static let locationName = "Rohanské nábřeží 721/39, Praha"
    static let googleMapsURL = "https://maps.app.goo.gl/bd3Cu4DBJHWxYAZx6"
    static let appTitle = "PARKING - KARLÍN ROHANSKÉ NÁBŘEŽÍ"
}
```

### 3.2 Core Model Types

```swift
// ── Models/ParkingSpot.swift ────────────────────────────────────
struct ParkingSpot: Identifiable, Hashable, Codable {
    let id: String          // e.g. "63", "80"
    let label: String       // e.g. "Parking 63", "Parking 80"
    var isAccessible: Bool = false  // ♿ flag

    /// Display label including ♿ if accessible
    var displayLabel: String {
        isAccessible ? "\(label) ♿" : label
    }

    /// Short label like "P63"
    var shortLabel: String {
        label.replacingOccurrences(of: "Parking ", with: "P")
    }
}

// ── Models/Booking.swift ────────────────────────────────────────
struct Booking: Identifiable, Codable {
    let id: UUID
    var title: String       // "Reservation for {displayName}"
    var spot: String        // "Parking 63" (matches ParkingSpot.label)
    var user: String        // display name of the booking creator
    var email: String       // email of the booking creator
    var date: Date          // booking date (date-only, no time component)
    var fromTime: String    // "07:00"
    var toTime: String      // "17:00"

    /// Person name extracted from title
    var personName: String {
        title
            .replacingOccurrences(of: "Reservation for ", with: "")
            .replacingOccurrences(of: "Rezervace pro ", with: "")
    }

    /// Spot short code
    var spotShortCode: String {
        spot.replacingOccurrences(of: "Parking ", with: "P")
    }

    /// True if this booking is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// ── Models/AppUser.swift ────────────────────────────────────────
// MARK: - ⚙️ CONFIGURABLE — Replace with real auth in production
struct AppUser: Codable {
    let displayName: String  // "MALAKJAN Stiv"
    let givenName: String    // "Stiv"
    let email: String        // "stiv.malakjan@ext.essilor.com"

    var isAdmin: Bool {
        AppConfig.authorizedCancelers.contains(email.lowercased())
    }
}

// ── Models/TimeSlot.swift ───────────────────────────────────────
struct TimeSlot: Comparable, Codable {
    let value: String  // "07:00"

    static func < (lhs: TimeSlot, rhs: TimeSlot) -> Bool {
        lhs.value < rhs.value
    }
}
```

---

## 4. REPOSITORY LAYER

```swift
// ── Repositories/BookingRepositoryProtocol.swift ────────────────
// MARK: - ⚙️ SWAP TARGET — Implement this protocol for real backend

protocol BookingRepositoryProtocol {

    /// All bookings (optionally filtered)
    func fetchBookings() async throws -> [Booking]

    /// Bookings for a specific user, from today onward, sorted by date then spot
    func fetchUserBookings(userDisplayName: String) async throws -> [Booking]

    /// Bookings that overlap with the given date + time range
    func fetchConflictingBookings(
        spotLabel: String, date: Date,
        fromTime: String, toTime: String
    ) async throws -> [Booking]

    /// Bookings for a date + time range (all spots)
    func fetchBookingsForDateRange(
        date: Date, fromTime: String, toTime: String
    ) async throws -> [Booking]

    /// Create booking(s) for a date range (one record per day)
    func createBookings(
        spotLabel: String,
        user: String,
        email: String,
        dateFrom: Date, dateTo: Date,
        fromTime: String, toTime: String
    ) async throws -> [Booking]

    /// Delete a single booking
    func deleteBooking(id: UUID) async throws

    /// Force-refresh from data source
    func refresh() async throws
}
```

### 4.1 Mock Implementation

```swift
// ── Repositories/MockBookingRepository.swift ────────────────────
// MARK: - ⚙️ TEST DATA — Edit seed bookings here

@Observable
final class MockBookingRepository: BookingRepositoryProtocol {

    private var bookings: [Booking] = MockBookingRepository.seedData()

    private static func seedData() -> [Booking] {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            Booking(id: UUID(), title: "Reservation for MALAKJAN Stiv",
                    spot: "Parking 63", user: "MALAKJAN Stiv",
                    email: "stiv.malakjan@ext.essilor.com",
                    date: today, fromTime: "07:00", toTime: "17:00"),
            Booking(id: UUID(), title: "Reservation for ZIMOVA Katerina",
                    spot: "Parking 71", user: "ZIMOVA Katerina",
                    email: "katerina.zimova@essilor.cz",
                    date: today, fromTime: "09:00", toTime: "15:00"),
            Booking(id: UUID(), title: "Reservation for LEIRVIK Evelyna",
                    spot: "Parking 80", user: "LEIRVIK Evelyna",
                    email: "evelyna.leirvik@essilor.cz",
                    date: Calendar.current.date(byAdding: .day, value: 1, to: today)!,
                    fromTime: "07:00", toTime: "17:00"),
        ]
    }

    // ... protocol conformance with in-memory array operations ...
    // Time-overlap check logic:
    // Overlap exists when: existingFromTime < queryToTime AND existingToTime > queryFromTime
}
```

---

## 5. BUSINESS LOGIC (EXACT RULES)

### 5.1 Available Spot Calculation

A spot is **available** for a given date + time range when ALL of these are true:

1. Spot exists in `AppConfig.allParkingSpots`
2. Spot ID is NOT in `AppConfig.blockedSpotIDs`
3. No existing booking has **time overlap** with the requested range on that date

**Time overlap formula** (from Power Apps source):
```
booking.fromTime < requested.toTime  AND  booking.toTime > requested.fromTime
```
This means a booking 09:00–12:00 and request 12:00–17:00 do **not** overlap (boundary-touching is allowed).

### 5.2 Self-Booking Rules

| Rule | Value | Error Message |
|------|-------|---------------|
| Start date >= today | required | "Start date cannot be in the past." |
| Start date <= today + 7 days | required | "Start date cannot be more than 7 days in advance." |
| End date >= start date | required | "End date cannot be before the start date." |
| End date - start date <= 4 | required | "Booking duration cannot exceed 5 days." |
| All fields filled | required | "Please fill in all fields before booking." |
| No time-overlap conflict | required | "Spot already taken. Please choose another." |
| After 17:00 local → default start date = tomorrow | auto | Orange text: "You are booking for next day" |

**On successful booking:** One Booking record is created **per day** in the range (ForAll/Sequence pattern from Power Apps). User is navigated to MyBookingsScreen. Success toast: "Parking spot booked successfully!"

### 5.3 Book-for-Others Rules

Same as self-booking except:

| Difference | Self | Others |
|------------|------|--------|
| Max advance days | 7 | 30 |
| Max duration days | 5 | 10 |
| Additional fields | — | Name (text), Email (validated) |
| Email validation | — | Must match regex for valid email format |
| On success | navigate | navigate + send confirmation email |
| Button color | Green (#2D8028) | Gold (#CF9C04) |
| Header warning | — | Yellow banner: "YOU ARE BOOKING FOR 3rd Party" |

### 5.4 Cancellation Rules

- **MyBookingsScreen:** User can cancel **their own** bookings (delete icon on each card). Deletes single booking record.
- **OverviewScreen (admin):** If `user.email` is in `authorizedCancelers`, tapping an occupied tile shows a confirmation popup, then deletes.
- **OverviewScreen (non-admin):** Tapping occupied tile shows: "You do not have permission to cancel this booking."
- Success toast: "Booking cancelled successfully."

### 5.5 Overview Screen — Quick Book

On the Overview grid, if a spot tile is **green** (available) AND the spot is not in the hardcoded block list `["Parking 66", "Parking 68"]` (from Screen2 `ButtonCanvas1.Visible`), a "Book" button appears. Tapping it creates a single-day booking for the selected date/time and the current user. Double-check before patching that the spot hasn't been taken in the meantime.

---

## 6. SCREENS & UI SPECIFICATION

### 6.0 Global Theme

| Property | Value |
|----------|-------|
| Background | Pure black `#000000` |
| Primary text | White `#FFFFFF` |
| Accent / active tab | Blue `#3860B2` at 60% opacity |
| Inactive tab bg | White at 12% opacity |
| Success / available | Green `#2D8028` or `#2FCD4D` |
| Danger / occupied | Red `#EA384C` at 80% |
| Warning / 3rd-party | Gold `#FFBF00` (text), `#CF9C04` (button) |
| Card style | Glassmorphism: linear gradient white 15% → black 50%, 1px white border at 30% opacity, corner radius 20 |
| Font | System font (SF Pro, matching Segoe UI from Power Apps) |
| Tab bar height | 108pt including labels |
| Screen width | 640pt (Power Apps phone layout) — use standard iOS sizing |

### 6.1 Tab Bar (persistent, bottom of every screen)

Three tabs, each a rounded-rect button (radius 20):

| Tab | Icon | Label | Navigates To |
|-----|------|-------|--------------|
| 1 | House (SF Symbol: `house.fill`) | "Home" | HomeView |
| 2 | Car (SF Symbol: `car.fill`) | "Bookings" | MyBookingsView |
| 3 | Clipboard (SF Symbol: `doc.text.fill`) | "Overview" | OverviewView |

Active tab: blue `#3860B2` at 60%. Inactive: white at 12%. Icons and labels always white.

### 6.2 HomeView (Booking Screen)

**Layout (top to bottom):**

1. **Header row:**
   - Left: EssilorLuxottica logo image (tappable → navigates to Screen1/ParkingScheme)
   - Right: Parking app icon (tappable → ParkingSchemeView, tooltip "Click here to see parking floorplan")

2. **Subtitle:** `"PARKING - KARLÍN ROHANSKÉ NÁBŘEŽÍ"` (white, bold, 12pt)

3. **Greeting row:**
   - User avatar (circular, 58×50pt)
   - "Hello," (semibold, 20pt) + user's given name (bold)
   - Right side: "Book For Others" button with PeopleAdd icon → navigates to BookForOthersView

4. **Form fields** (each inside a glass-card, stacked vertically):

   | Field | Type | Details |
   |-------|------|---------|
   | "Date From" | Date picker | Default: today (or tomorrow if after 17:00). Min: today. Max: today+7. Week starts Monday. |
   | "Date To" | Date picker | Default: same as Date From. Disabled until Date From is set. Max: Date From + 4 days. |
   | "Time From" | Dropdown | Items: `["07:00"..."17:00"]` hourly. Default: "07:00" |
   | "Time To" | Dropdown | Items: same. Default: "17:00" |
   | "Choose Parking Spot" | Dropdown | Dynamically filtered — shows only available spots. Includes ♿ suffix for Parking 80. Shows "Available 🟢" count label to the right. |

5. **"Book Parking Spot" button:** Full-width, green `#2D8028`, white text, radius 20, height 77pt.

6. **Orange warning text** (visible only when after 17:00): "You are booking for next day" — color `#E05606`.

### 6.3 BookForOthersView

**Layout:** Same form structure as HomeView with these differences:

1. **Yellow header banner:** "YOU ARE BOOKING FOR 3rd Party" — color `#FFBF00`, bold, 20pt
2. **Same date/time/spot fields** (but max advance=30 days, max duration=10 days)
3. **Additional fields:**
   - "Name of person you book it for" → text input (dark fill `#1C1C1E`, white text, 22pt)
   - "Email of person you book it for" → text input (same style, validated as email)
4. **Button:** "Book Parking Spot" — gold `#CF9C04`, bold, radius 30, width 413pt centered
5. **On success:** Creates bookings + sends HTML email (see Section 7) + navigates to MyBookingsView

### 6.4 MyBookingsView

**Layout:**

1. **Header:**
   - Avatar (82×89pt) + "Hello," + user's first name (bold, 30pt)
   - Subtitle: "Your bookings overview!" (bold, 23pt)
   - Parking icon → ParkingSchemeView

2. **Booking list** (Gallery, vertical scroll, template height 290pt):

   Each booking card contains:

   | Element | Style | Content |
   |---------|-------|---------|
   | Status badge | Top-left label, border 1px white | "Active Booking" (24pt) if date=today, "Upcoming Booking" (18pt) otherwise |
   | Today highlight | Green card `#40A851` behind the white card, visible only for today's booking |
   | White card | Radius 20, full width, height 183pt | Contains all details |
   | Date large | Lato Black, 38pt | e.g. "24 Mar" (dd MMM, en-GB) |
   | Day of week | Lato, 24pt, color `#3A5C3A` | e.g. "Tuesday" (shows year if not current year) |
   | Spot code | Segoe UI bold, 50pt, color `#0F548C` | e.g. "P63" (Substitute "Parking " → "P") |
   | Time range | 17pt | "07:00 - 17:00" with pipe separators |
   | Person name | Semibold, 17pt, with green Person icon | Extracted from title |
   | Cancel button | Red X circle icon, top-right of card | Calls `Remove(Bookings, ThisItem)` |

   **Sort order:** By date ascending, then spot ascending.
   **Filter:** Only current user's bookings where date >= today.

### 6.5 OverviewView (All Spots Grid)

**Layout:**

1. **Filter bar (top):** Date picker + Time From dropdown + Time To dropdown (all inline, compact)

2. **Spot grid:** 5 columns × 3 rows (15 spots from ParkingSpots data source). Each tile is 170×177pt with 10pt padding. Template:

   | State | Tile Color | Content |
   |-------|-----------|---------|
   | Available | Green `#2FCD4D` | Parking icon image + "Book" button (27pt, transparent bg) |
   | Occupied | Red `#EA384C` at 80% | User avatar + booker name (12pt) + time range (10pt) + car icon |
   | Blocked (66, 68) | Green but NO "Book" button | Just shows as available-looking but not bookable |

3. **Tile tap behavior:**
   - If available: does nothing (use Book button)
   - If occupied + user is admin: shows **cancellation confirmation popup**
   - If occupied + user is NOT admin: toast "You do not have permission to cancel this booking."

4. **Cancellation popup** (modal overlay):
   - Shows booking details
   - "Cancel Booking" destructive button
   - "Keep" dismiss button

### 6.6 ParkingSchemeView

Static floor plan image of the parking lot, full-screen. Shows an animated SVG arrow overlay (three chevrons animating in sequence, white on black, pointing right — replicated as a Lottie or SwiftUI animation).

Image source: the `'schema parking'` asset from Power Apps resources.

---

## 7. EMAIL TEMPLATE (Book for Others)

On successful third-party booking, compose and send an HTML email:

**To:** `TextInputMail.Value`
**Subject:** "Parking Spot reservation confirmation"

**Body content (key fields):**
```
Hello {name},

Your Parking Reservation with following details:

Parking Spot Number: {spot}
From Date: {dateFrom as dd.MM.yyyy}
To Date: {dateTo as dd.MM.yyyy}
Time: from {timeFrom} to {timeTo}
Address: Rohanské nábřeží 721/39, Praha (View on Google Maps)

This is automatically generated email. Please do not respond.
```

**Styling:** Background `#fcebeb`, font: system/Segoe UI, background image from GitHub URL (branded template). The Power Apps version uses Office365Outlook.SendEmailV2 connector. For iOS v1, use `MFMailComposeViewController` or a mailto: link. For v2, integrate with Microsoft Graph API or SMTP.

---

## 8. STATE MANAGEMENT

### 8.1 App-Level State (via @Observable ViewModels in Environment)

| State | Type | Purpose |
|-------|------|---------|
| `currentUser` | `AppUser` | Logged-in user. v1: hardcoded mock. v2: MSAL auth. |
| `showAlert` | `Bool` | One-time daily alert flag (set true on launch) |
| `varDate` | `Date` | Today's date reference |

### 8.2 Screen-Level State (via @State in Views)

**HomeView / BookForOthersView:**

| State | Type | Default |
|-------|------|---------|
| `dateFrom` | `Date` | Today (or tomorrow if after 17:00) |
| `dateTo` | `Date` | Same as dateFrom |
| `timeFrom` | `String` | "07:00" |
| `timeTo` | `String` | "17:00" |
| `selectedSpot` | `ParkingSpot?` | nil |
| `availableSpots` | `[ParkingSpot]` | Computed from filters |
| `isLoading` | `Bool` | false |
| `thirdPartyName` | `String` | "" (BookForOthers only) |
| `thirdPartyEmail` | `String` | "" (BookForOthers only) |

**OverviewView:**

| State | Type | Default |
|-------|------|---------|
| `selectedDate` | `Date` | Today |
| `timeFrom` | `String` | "07:00" |
| `timeTo` | `String` | "17:00" |
| `showCancelPopup` | `Bool` | false |
| `bookingToCancel` | `Booking?` | nil |

---

## 9. NAVIGATION FLOW

```
App Launch
  │
  ├── OnStart: load AllParkingSpots, set currentUser, set varShowAlert
  │
  └── MainTabView
        ├── Tab 1: HomeView
        │     ├── [logo tap] → ParkingSchemeView
        │     ├── [parking icon tap] → ParkingSchemeView
        │     ├── [Book For Others] → BookForOthersView
        │     └── [Book button] → MyBookingsView (on success)
        │
        ├── Tab 2: MyBookingsView
        │     ├── [parking icon tap] → ParkingSchemeView
        │     └── [Overview link] → Tab 3
        │
        └── Tab 3: OverviewView
              ├── [green tile Book] → creates booking inline
              └── [red tile tap (admin)] → cancel popup
```

### 9.1 Screen OnAppear Behavior

**HomeView.onAppear:**
1. Refresh bookings from repository
2. Reset all form fields to defaults
3. Recompute available spots collection

**MyBookingsView.onAppear:**
1. Fetch filtered bookings for current user

**OverviewView.onAppear/onChange:**
1. Fetch all bookings for selected date + time range
2. Refresh on date/time change

---

## 10. MOCK USER (v1)

```swift
// ── MARK: ⚙️ CONFIGURABLE — Change mock user for testing
extension AppUser {
    static let mock = AppUser(
        displayName: "MALAKJAN Stiv",
        givenName: "Stiv",
        email: "stiv.malakjan@ext.essilor.com"
    )
}
```

---

## 11. UPGRADE PATH (v1 → v2)

| Component | v1 (Local/Test) | v2 (Production) |
|-----------|-----------------|-----------------|
| Data layer | `MockBookingRepository` (in-memory) | `SharePointBookingRepository` or `FirebaseBookingRepository` |
| Auth | `AppUser.mock` hardcoded | Microsoft MSAL (Azure AD) via `MSAL` SDK |
| User profile | Static mock | `MSGraphRequest` → `/me` endpoint |
| User photo | SF Symbol placeholder | `MSGraphRequest` → `/me/photo/$value` |
| Email | `MFMailComposeViewController` | Microsoft Graph `sendMail` API |
| Push notifications | — | APNs for booking reminders |
| Parking scheme | Static PNG | Backend-served image or interactive SVG |
| Blocked spots | `AppConfig.blockedSpotIDs` | Backend flag on ParkingSpot entity |
| Admin list | `AppConfig.authorizedCancelers` | Backend role/group membership |

**No view or viewmodel code needs to change.** Only inject a different `BookingRepositoryProtocol` conformer and auth provider.

---

## 12. ACCEPTANCE CRITERIA (v1)

1. User sees greeting with mock name on HomeView
2. Date pickers enforce all validation rules from Section 5.2
3. Spot dropdown shows only non-blocked, non-conflicting spots
4. Booking creates one record per day in range
5. MyBookingsView shows only current user's future bookings, sorted correctly
6. Cancel button removes booking and shows success toast
7. OverviewView grid shows red/green tiles based on booking status
8. Admin user can cancel others' bookings from Overview
9. Non-admin tapping occupied tile gets permission-denied toast
10. "Book For Others" validates email format before submission
11. After 17:00, date defaults to tomorrow with orange warning
12. Tab bar highlights active tab correctly on all screens
13. All hardcoded data lives exclusively in `AppConfig.swift` — no magic strings in views/viewmodels

---

## 13. COLOR REFERENCE (exact hex from Power Apps RGBA)

| Usage | RGBA (Power Apps) | Hex |
|-------|-------------------|-----|
| Screen background | RGBA(0,0,0,1) | `#000000` |
| Primary text | RGBA(255,255,255,1) | `#FFFFFF` |
| Active tab fill | RGBA(56,96,178,0.6) | `#3860B2` 60% |
| Inactive tab fill | RGBA(255,255,255,0.12) | `#FFFFFF` 12% |
| Book button (self) | RGBA(45,128,40,1) | `#2D8028` |
| Book button (others) | RGBA(207,156,4,1) | `#CF9C04` |
| 3rd party warning text | RGBA(255,191,0,1) | `#FFBF00` |
| Next-day warning text | RGBA(224,86,6,1) | `#E05606` |
| Available spot tile | RGBA(47,205,77,1) | `#2FCD4D` |
| Occupied spot tile | RGBA(234,56,76,0.8) | `#EA384C` CC |
| Today card green | RGBA(64,168,81,1) | `#40A851` |
| Spot code blue | RGBA(15,84,140,1) | `#0F548C` |
| Day-of-week green | RGBA(58,92,58,1) | `#3A5C3A` |
| Cancel icon red | RGBA(171,32,32,1) | `#AB2020` |
| Loading spinner | RGBA(56,96,178,1) | `#3860B2` |
| Glass card border | white at 30% opacity | `#FFFFFF` 4D |
| Glass card gradient start | white at 15% | — |
| Glass card gradient end | `#0F0F0F` at 50-60% | — |
| Dropdown dark fill | RGBA(28,28,30,1) | `#1C1C1E` |
| Available badge text | Color.Green | `#00FF00` (system) |

---

*End of specification. All values marked with ✏️ or ⚙️ are designed for easy modification.*
