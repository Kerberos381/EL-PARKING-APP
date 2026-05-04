# EL PARKING APP — Redesign Plan

## Problem Statement

The current app has **3 redundant booking paths** across 4 tabs, an unused ViewModel, and a cluttered UX. Users can book from Overview, My Bookings, and Book for Others — all leading to the same sheet. The UI is overloaded and not focused.

---

## New App Structure: 3 Tabs Only

### Tab 1: 🏠 Home (New — replaces Overview)
### Tab 2: 📅 My Bookings (Simplified)
### Tab 3: ⚙️ Settings (Cleaned up)

> ❌ **Remove "Book for Others" tab** — merge into Home for authorized users only.

---

## Tab 1: Home — The Main Screen

This is the **single source of truth** for the user.

### Section A: Active/Upcoming Booking Card
- If user has a **booking today** → show it prominently:
  - Spot number (large)
  - Time: 07:00 – 18:00
  - Status badge: "Active Now" (green pulse)
  - Address with tap-to-navigate (Google Maps link)
- If **no booking today** → show the **next upcoming booking**:
  - Same card layout
  - Status badge: "Upcoming — Mon 30 Mar"
- If **no bookings at all** → show a friendly empty state:
  - "No parking booked" + illustration
  - Prominent "Book a Spot" button

### Section B: Quick Book (Below the card)
- **One button**: "Book a Spot" → opens booking flow
- For **authorized users** (defined list): additional option "Book for Someone Else"
- No calendar visible by default — clean and minimal

### Booking Flow (Sheet/Modal):

1. **Date** — Default is **today**, unless current time ≥ 17:00, then default is **tomorrow**
2. **Duration** — Fixed: **1 day only** (07:00 – 18:00), no multi-day for regular users
3. **Advance booking** — Maximum **3 days ahead** (regular users)
   - Authorized users (defined list) can book further ahead
4. **Spot Picker** — Modern horizontal scroll or grid picker:
   - Show spot numbers with availability status
   - Color-coded: green (available), red (taken), gray (blocked)
   - Accessible spot (♿) clearly marked
   - No standalone parking list page — picker is embedded
5. **"Book for Someone Else"** section (authorized users only):
   - Name + Email fields appear only when toggled
6. **Confirm** → Success animation → Return to Home with updated card

---

## Tab 2: My Bookings (Simplified)

- **Upcoming** bookings list (default view)
- **Past** bookings (collapsed/secondary)
- Each card shows: date, spot, time, status
- Cancel button on upcoming bookings (with confirmation)
- **No booking button here** — booking only from Home
- **Remove Stats tab** — move basic stats to Settings if needed

---

## Tab 3: Settings (Cleaned up)

- Profile info (name, email)
- Booking limits info
- Admin section (if applicable)
- App version
- Clear data option

---

## Editable Bookings

All bookings should be **editable** after creation:

- User taps on any upcoming booking card → opens an **Edit Booking** sheet
- Editable fields:
  - **Date** (within allowed advance range)
  - **Time** — from/to (within 07:00–18:00 window)
  - **Spot** — can switch to another available spot
- Non-editable: who booked it (creator)
- **Save Changes** button with validation (conflict check)
- **Cancel Booking** button at the bottom (with confirmation alert)
- Past bookings are **read-only** (no edit option)

### Implementation:
- Reuse `BookingSheet.swift` in "edit mode" (pass existing booking data)
- `BookingManager` needs: `updateBooking(id:, newDate:, newTime:, newSpot:)` method
- Delete old booking + create new one (or update in-place if backend supports it)

---

## Key UX Rules

| Rule | Detail |
|------|--------|
| **Default date** | Today, or tomorrow if after 17:00 |
| **Default time** | Always 07:00 – 18:00 (1 full day) |
| **Max advance booking** | 3 days for regular users |
| **Extended advance booking** | Only for authorized users (defined list in AppConfig) |
| **Spot selection** | Inline picker with visual status — no separate page |
| **Book for others** | Only visible to authorized users, accessed from Home |
| **Single booking entry point** | Home screen only |

---

## Files to Modify

| File | Action |
|------|--------|
| `ContentView.swift` | Remove "Book for Others" tab, reduce to 3 tabs |
| `OverviewView.swift` | **Replace entirely** → new `HomeView.swift` |
| `BookForOthersView.swift` | **Delete** — functionality merged into Home |
| `BookingSheet.swift` | Simplify: default 1-day, 07–18, smart date, spot picker UI |
| `MyBookingsView.swift` | Remove "+" booking button, remove Stats tab |
| `AppConfig.swift` | Update: `maxAdvanceDays = 3`, add `advanceBookingUsers` list |
| `BookingViewModel.swift` | **Delete or refactor** — currently unused, consolidate into BookingManager |
| `BookingManager.swift` | Add helpers: `getNextUpcomingBooking(for:)`, `getTodayBooking(for:)`, `updateBooking()` |
| `SettingsView.swift` | Minor cleanup |

---

## New Files to Create

| File | Purpose |
|------|---------|
| `HomeView.swift` | New home screen with active booking card + quick book |
| `SpotPickerView.swift` | Reusable visual spot picker component |

---

## Authorized Users (Advance Booking + Book for Others)

Define in `AppConfig.swift`:

```swift
static let advanceBookingUsers: [String] = [
    "user1@company.com",
    "user2@company.com",
    // defined list
]
```

These users can:
- Book more than 3 days in advance
- Book on behalf of other people

Regular users:
- Book today + up to 3 days ahead
- Book only for themselves

---

## Visual Design Direction (Dribbble Reference Style)

Inspired by: https://dribbble.com/shots/25624182

### Color Palette
- **Background**: Light gray `#F5F5F5` — clean, not pure white
- **Cards**: Pure white `#FFFFFF` with subtle shadow and `20pt` corner radius
- **Accent / CTA**: Lime/neon green `#C8FF00` (buttons, badges, highlights)
- **Primary text**: Near-black `#1A1A1A`
- **Secondary text**: Medium gray `#8E8E93`
- **Tab bar**: Dark/black `#1C1C1E` with white icons, green active indicator
- **Available spots**: Lime green `#C8FF00` badge
- **Occupied spots**: Red/coral `#FF3B30` badge or muted gray
- **Blocked spots**: Gray `#D1D1D6`

### Typography
- **Large titles**: Bold, 28–34pt (SF Pro Display or system bold)
- **Card headings**: Semibold, 17–20pt
- **Body/details**: Regular, 14–15pt
- **Badges/labels**: Medium, 12–13pt, uppercase or small caps
- **Spot numbers**: Bold, 18pt inside grid cells

### Component Style
- **Cards**: White, large corner radius (16–20pt), soft shadow (`opacity: 0.08, y: 4, blur: 16`)
- **Buttons**: Pill-shaped (full corner radius), lime green background, dark text
- **Tab bar**: Dark/black bar with rounded top corners, icons + labels
- **Status badges**: Small pill shapes — lime green for available, red for taken
- **Spot grid**: Rounded square cells in a grid layout, color-coded borders/fills

### Home Screen Layout (Dribbble-Inspired)
```
┌─────────────────────────────┐
│  Header: "EL Parking"       │
│  Subtitle: Today's date     │
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │  ACTIVE BOOKING CARD    ││
│  │  ┌──────┐               ││
│  │  │ P 72 │  07:00–18:00  ││
│  │  └──────┘               ││
│  │  ● Active Now            ││
│  │  Rohanské nábřeží 721   ││
│  │  [Navigate]  [Edit]     ││
│  └─────────────────────────┘│
│                             │
│  Parking Overview           │
│  ┌────┐┌────┐┌────┐┌────┐  │
│  │ 63 ││ 64 ││ 65 ││ 66 │  │
│  │ 🟢 ││ 🔴 ││ 🟢 ││ ⬜ │  │
│  └────┘└────┘└────┘└────┘  │
│  ┌────┐┌────┐┌────┐┌────┐  │
│  │ 67 ││ 68 ││ 69 ││ 70 │  │
│  │ 🟢 ││ ⬜ ││ 🔴 ││ 🟢 │  │
│  └────┘└────┘└────┘└────┘  │
│  ┌────┐┌────┐┌────┐┌────┐  │
│  │ 71 ││ 72 ││ 73 ││ 74 │  │
│  │ 🟢 ││ 🟡 ││ 🟢 ││ 🔴 │  │
│  └────┘└────┘└────┘└────┘  │
│  ┌────┐┌────┐┌────┐        │
│  │ 75 ││ 76 ││ ...│        │
│  │ ⬜ ││ 🟢 ││    │        │
│  └────┘└────┘└────┘        │
│                             │
│  [ 🟢 Book a Spot ]        │
│                             │
├─────────────────────────────┤
│  🏠 Home  📅 Bookings  ⚙️  │
│  (dark tab bar, green dot)  │
└─────────────────────────────┘
```

### Spot Grid Legend
- 🟢 **Lime green** = Available (tappable → opens booking)
- 🔴 **Red/coral** = Occupied (shows who booked on tap)
- ⬜ **Gray** = Blocked (non-interactive)
- 🟡 **Yellow/gold** = Your booking (highlighted)
- ♿ Accessible spot indicator on Parking 80

### Booking Sheet Style
```
┌─────────────────────────────┐
│  ━━━  (drag handle)         │
│                             │
│  Book a Spot                │
│                             │
│  Date                       │
│  ┌─────────────────────────┐│
│  │ Today, 26 Mar     ▼     ││
│  └─────────────────────────┘│
│                             │
│  Time                       │
│  ┌──────────┐ ┌────────────┐│
│  │ 07:00    │ │ 18:00      ││
│  └──────────┘ └────────────┘│
│                             │
│  Select Spot                │
│  ┌────┐┌────┐┌────┐┌────┐  │
│  │ 63 ││ 64 ││ 65 ││ 67 │  │
│  │ 🟢 ││ 🟢 ││ 🟢 ││ 🟢 │  │
│  └────┘└────┘└────┘└────┘  │
│  (only available shown)     │
│                             │
│  ┌─────────────────────────┐│
│  │    [ Confirm Booking ]   ││
│  │    (lime green pill btn) ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

### Animations & Micro-interactions
- Spot grid cells: subtle scale animation on tap (`0.95` → `1.0`)
- Booking confirmation: checkmark animation + haptic feedback
- Tab switching: smooth cross-fade
- Card appearance: fade-in + slide-up on load
- Active booking pulse: subtle green glow animation on status dot

---

## App Icon

- **Design**: Minimalist parking "P" with a modern geometric style
- **Colors**: Gradient blue-to-teal (or match app accent color)
- **Shape**: Rounded square (iOS standard)
- **Sizes needed**: 1024×1024 (App Store) + all iOS icon sizes
- **File**: `Assets.xcassets/AppIcon.appiconset/`
- **Style reference**: Clean, flat design — no 3D effects, no text except the "P"

---

## Implementation Order

1. Create `HomeView.swift` with booking card + quick book
2. Create `SpotPickerView.swift` component
3. Simplify `BookingSheet.swift` (defaults, 1-day, spot picker)
4. Update `ContentView.swift` (3 tabs)
5. Simplify `MyBookingsView.swift` (remove booking entry)
6. Update `AppConfig.swift` (new rules + authorized users list)
7. Update `BookingManager.swift` (new helpers)
8. Delete `BookForOthersView.swift` and `BookingViewModel.swift`
9. Clean up `SettingsView.swift`
10. Test all flows end-to-end
