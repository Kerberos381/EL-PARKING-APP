# Implementation Plan: Kinetic Sanctuary Design System

## Design Reference Files
| Screen | File | Key Elements |
|--------|------|-------------|
| Dashboard (Home) | `updated_refined_dashboard_v2` | "Hello, Name" greeting, Next Booking card (white), Garage Status bar, Book a Spot button, News bento grid |
| Glow-up Booking Card | `glow_up_next_booking_card` | Dark obsidian card, giant green `63` spot number, car background image, Navigate/Edit/Cancel buttons |
| Parking Overview | `parking_overview` | Editorial "Parking." header, date pill selector, large 2-col spot grid (3:4 aspect), status labels, legend |
| New Booking Flow | `new_booking_flow` | "Reserve Your Space." header, date pills, From/To time, info tooltip, spot grid, Delegate Booking toggle |
| Guest Booking | `guest_booking_form` | "Book for a Guest" header, constraint cards, guest identity form, horizontal spot scroll |
| Design System | `obsidian_glass/DESIGN.md` | Full spec: colors, typography, elevation, components, do's/don'ts |

---

## Design System Tokens (SwiftUI Translation)

### Colors
| Token | Hex | SwiftUI |
|-------|-----|---------|
| Background (Canvas) | `#f8f9fa` | `pageBg` |
| Primary (Dark Text) | `#000100` | `darkText` - **change from #1C1C1E** |
| Success Green (Accent) | `#b1f800` | `accent` - **change from current lime** |
| Surface Lowest (Cards) | `#ffffff` | `cardBg` (keep) |
| Surface Low (Sections) | `#f3f4f5` | new `surfaceLow` |
| Surface High (Recessed) | `#e7e8e9` | new `surfaceHigh` |
| Secondary Text | `#5d5e61` | `subtleGray` - **change from #8E8E93** |
| Outline Variant | `#c5c6ca` at 15% | ghost borders |
| Error | `#ba1a1a` | `spotOccupied` - **change** |
| Accent Dim | `#9bd900` | `accentDim` for active states |

### Typography Rules (iOS approximation)
- **Display (spot numbers)**: `.system(size: 56+, weight: .black, design: .rounded)` — tight tracking
- **Headline**: `.system(size: 28, weight: .bold)` — Manrope equivalent
- **Title**: `.system(size: 22, weight: .semibold)`
- **Label**: `.system(size: 10-11, weight: .bold)` + `.tracking(2)` + `.uppercased`
- **Body**: `.system(size: 14, weight: .regular)`

### Shape & Elevation
- Minimum corner radius: **24pt** for cards, **16pt** for cells
- **No 1px dividers** — use background color shifts and whitespace
- Cloud shadows: `shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 6)`
- Ghost borders: `outlineVariant.opacity(0.15)` if needed

---

## Screen-by-Screen Implementation

### 1. HomeView.swift (Dashboard)

**Layout order (from designs):**
1. Greeting: "Hello, {FirstName}" — large 3.5rem bold, left-aligned
2. **Next Booking Card** — TWO variants:
   - **If booking is TODAY**: Dark obsidian card (`#1A1C1E`) with:
     - "YOUR NEXT BOOKING" label (tiny uppercase, white/40%)
     - Giant spot number in `#b1f800` (10rem equivalent ~96pt)
     - "North Wing" / floor info
     - Calendar icon + "Tomorrow, Oct 24" or "TODAY"
     - Clock icon + "07:00 — 18:00"
     - Green "Navigate" button (full width, `#b1f800`)
     - Glass Edit + Cancel buttons (white/10% bg, backdrop blur)
   - **If booking is UPCOMING (not today)**: White card variant (from `updated_refined_dashboard_v2`):
     - "B-12" large spot number
     - "Tomorrow" + time range
     - Edit / Cancel buttons in surface-low bg
3. **Garage Status bar**: surface-low bg, green dot with glow + "Garage Status" label + "X Spots Available"
4. **"Book a Spot" button**: `#b1f800` bg, full-width, rounded-2xl, parking icon + text, shadow with green glow
5. **News & Information bento grid**:
   - Full-width news tile (announcement icon, title, description)
   - 2-column: "Zones Map" tile (with bg texture) + "EV Chargers" dark tile
   - Adapt for our context: Parking Hours, Registration Plates reminder, Contact Admin

**Changes needed:**
- Replace current greeting with "Hello, {FirstName}" large editorial style
- Replace hero card with dark obsidian variant for today's booking
- Add garage status bar
- Restyle "Book a Spot" with green glow shadow
- Replace news section with bento grid layout
- Remove "Book for Someone Else" button from home (moved to booking flow toggle)

### 2. OverviewView.swift (Parking Tab — Admin + Regular merged)

**Layout (from `parking_overview`):**
1. Header: "EXECUTIVE MOBILITY" label + "Parking." huge editorial headline
2. **Date selector**: Horizontal scroll pills (Today highlighted black, others white with day number, greyed weekends)
3. **Spot Grid**: 2-column layout on phone, 3-col on larger screens
   - Each cell: tall (aspect 3:4), large rounded corners (24pt)
   - **Available**: white bg, green `#b1f800` border (2px), large spot number, green "+" circle button bottom-right
   - **Yours**: `#b1f800` solid bg, car icon top-left, "YOURS" label, spot number
   - **Occupied**: `#e7e8e9` bg, 60% opacity, "OCCUPIED" label (admin sees name)
   - **Blocked**: `#e7e8e9` bg, 40% opacity, lock icon bottom-right
4. **Legend**: Free / Taken / Yours / Blocked — horizontal, centered
5. **Admin extras** (visible only to admins):
   - Bookings list below grid with cancel buttons
   - Stats bar (free/booked/blocked counts)

**Changes needed:**
- Replace compact 5-column grid with editorial 2-column tall cells
- Add editorial "Parking." header
- Replace date navigator arrows with horizontal scroll pills
- Style cells per design (large numbers, status labels, + button, car icon)
- Admin sees names inside occupied cells + cancel button in booking list
- Regular users see status labels only
- Tapping available spot = opens BookingSheet
- Tapping occupied spot = shows SpotDetailSheet

### 3. BookingSheet.swift (New Booking Flow)

**Layout (from `new_booking_flow` + `guest_booking_form`):**
1. Header: "RESERVATION" label + "Reserve Your Space." editorial headline
2. **Date selection**: Horizontal scroll pills (Mon 12, Tue 13, etc.) — active = black bg, available with green border if advance-bookable
3. **Time selection**: Two cards side-by-side (From/To) with icon + time, surface-low bg
4. **Info tooltip card**: Left green border, info icon, rules text ("Company car can book 3 days ahead", "Private car bookings open after 17:00 for tomorrow")
5. **Spot selection grid**: 3-column, selected = black bg with green checkmark, available = white with green border, occupied = grey
6. **Delegate Booking toggle**: Full-width card, headline + description + toggle switch
7. **Guest fields** (when toggle on, from `guest_booking_form`):
   - Full Name input (surface-low bg, 24px rounding, floating label)
   - Email input
   - Constraint cards (horizon: 1 week, allowance: 3/week)
8. **"Confirm Booking" button**: Black bg, white text, full-width pill, arrow icon

**Changes needed:**
- Replace graphical DatePicker with horizontal date pills
- Restyle time pickers as side-by-side cards
- Add info tooltip card with booking rules
- Restyle spot picker grid to 3-column with selected=black
- Keep delegate booking toggle (already exists)
- Style confirm button as black pill (not green)
- Add floating label inputs for guest fields

### 4. ContentView.swift (Tab Bar)

**From all designs — bottom nav:**
- 3 tabs: Home, Booking/Parking, Settings
- Glass effect: `bg-white/60 backdrop-blur-3xl rounded-t-[32px]`
- Active tab: `#b1f800` bg pill with icon + label
- Inactive: gray icon + tiny uppercase label
- iOS: Use system TabView with `.tint` and minimal customization to stay native

**Changes needed:**
- Confirm 3 tabs (Home, Overview, Settings) — already correct
- Ensure tab bar uses glass material (remove any opaque overrides)
- Active tint = `#b1f800`

### 5. AppConfig.swift (Design Tokens)

**Color updates:**
```
accent:      #b1f800 (was slightly different lime)
accentDim:   #9bd900 (for dimmer accent states)
darkText:    #000100 (was #1C1C1E — almost black now)
subtleGray:  #5d5e61 (was #8E8E93 — darker now, more readable)
pageBg:      #f8f9fa (was #F5F5F5 — slightly cooler)
surfaceLow:  #f3f4f5 (new — for section grouping)
surfaceHigh: #e7e8e9 (new — for recessed/occupied elements)
spotOccupied:#ba1a1a (was red — now error red from design)
```

### 6. MyBookingsView.swift

- Keep current structure (upcoming/past sections)
- Restyle cards to match design system (24pt corners, no dividers, surface shifts)
- "TODAY" / "TOMORROW" / "Wed 29th" natural dates (already working)
- Active today booking: green left accent or glow border
- Edit/Cancel buttons styled as glass pills

### 7. SettingsView.swift

- Keep current structure
- Update colors to new design tokens
- Ensure 24pt corner radius on all cards
- Remove dividers, use spacing instead

### 8. SpotDetailSheet.swift

- Restyle with design tokens
- Large spot number display
- Card with user info, no dividers

---

## Files to Modify

| File | Action |
|------|--------|
| `AppConfig.swift` | Update all color tokens to match design system |
| `HomeView.swift` | Full redesign: obsidian card, garage status, bento news |
| `OverviewView.swift` | Full redesign: editorial header, 2-col tall grid, date pills |
| `BookingSheet.swift` | Restyle: date pills, side-by-side time, 3-col spot grid, info card |
| `ContentView.swift` | Minor: ensure glass tab bar, correct icons |
| `MyBookingsView.swift` | Restyle cards, remove dividers |
| `SettingsView.swift` | Update colors, remove dividers |
| `SpotDetailSheet.swift` | Restyle with new tokens |

## Files to Delete

| File | Reason |
|------|--------|
| `AdminView.swift` | Merged into OverviewView (admin sees extra controls in same tab) |

---

## Implementation Order

1. **AppConfig.swift** — Update design tokens first (all views depend on these)
2. **HomeView.swift** — Most impactful screen, obsidian card + bento news
3. **OverviewView.swift** — Editorial grid + admin merge + date pills
4. **BookingSheet.swift** — Booking flow restyle
5. **ContentView.swift** — Tab bar glass finish
6. **MyBookingsView.swift** — Card restyle
7. **SettingsView.swift** — Token updates
8. **SpotDetailSheet.swift** — Minor restyle
9. **Delete AdminView.swift** — Cleanup
10. **Build & test** — Verify on all screen sizes

---

## Responsive Design Notes

- Use `GeometryReader` sparingly — prefer flexible layouts
- Overview grid: 2 columns on iPhone SE/Mini, 2 columns on regular, 3 on iPad
- Spot cells: use `aspectRatio(3/4)` for consistent tall cells
- All text: add `.minimumScaleFactor(0.7)` on large numbers
- Bottom padding: 100pt minimum to clear tab bar
- Date pills: `ScrollView(.horizontal)` with `.flexibleFrame`
- News bento: `LazyVGrid` with 2 columns, full-width first tile
