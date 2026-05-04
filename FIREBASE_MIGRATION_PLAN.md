# Firebase Migration Plan — EL Parking

## Overview

Migrate from local UserDefaults persistence to **Firebase (free Spark plan)** for multi-user, real-time parking booking. The app currently stores everything locally — this plan moves all data to Firestore with Firebase Auth, enabling real users, real-time spot availability, and admin features that work across devices.

---

## Firebase Services Used (All Free Tier)

| Service | Free Tier Limit | Our Usage |
|---------|----------------|-----------|
| **Firebase Auth** | 50k MAU | ~20 employees |
| **Cloud Firestore** | 1 GiB storage, 50k reads/day, 20k writes/day | ~15 spots × 30 days = tiny |
| **Cloud Functions** (optional) | 2M invocations/month | Notifications only |
| **Firebase Cloud Messaging** | Unlimited | Push notifications |

---

## Firestore Database Schema

### Collection: `users`
> One document per registered user. Document ID = Firebase Auth UID.

```
users/{uid}
├── email: string              // "stiv.malakjan@ext.essilor.com"
├── displayName: string        // "MALAKJAN Stiv"
├── firstName: string          // "Stiv"
├── role: string               // "admin" | "privileged" | "user"
├── carDescription: string     // "Volvo EX30"
├── registrationPlate: string  // "EL977BX"
├── fcmToken: string           // Firebase Cloud Messaging token (for push)
├── createdAt: timestamp
└── updatedAt: timestamp
```

**Firestore Rules:**
- Users can read/write their own document
- Admins can read all user documents
- `role` field can only be set by admin or Cloud Function

---

### Collection: `bookings`
> One document per booking. Document ID = auto-generated.

```
bookings/{bookingId}
├── spotId: string             // "63"
├── spotLabel: string          // "Parking 63"
├── userId: string             // Firebase Auth UID of person booking is FOR
├── userEmail: string          // "stiv.malakjan@ext.essilor.com"
├── userName: string           // "MALAKJAN Stiv"
├── date: timestamp            // Booking date (date-only, midnight UTC)
├── fromTime: string           // "07:00"
├── toTime: string             // "18:00"
├── createdBy: string          // UID of who created (differs for delegate bookings)
├── createdByEmail: string     // Email of creator
├── status: string             // "active" | "cancelled"
├── cancelledBy: string?       // UID if cancelled by admin
├── cancelReason: string?      // Reason for admin cancellation
├── createdAt: timestamp
└── updatedAt: timestamp
```

**Indexes needed:**
- `spotLabel + date` (composite) — check spot availability
- `userEmail + date` (composite) — user's bookings on a date
- `date + status` (composite) — all active bookings for a date
- `userEmail + status` (composite) — user's active bookings

**Firestore Rules:**
- Any authenticated user can create a booking (with validation)
- Users can cancel their own bookings
- Admins can read/cancel/edit any booking
- Privileged users can create bookings for others

---

### Collection: `parkingSpots`
> One document per spot. Managed by admin. Document ID = spot number.

```
parkingSpots/{spotId}
├── label: string              // "Parking 63"
├── isAccessible: bool         // true for wheelchair spots
├── isBlocked: bool            // true = temporarily unavailable
├── blockReason: string?       // "Maintenance"
├── order: number              // Display order in grid
├── createdAt: timestamp
└── updatedAt: timestamp
```

**Firestore Rules:**
- All authenticated users can read
- Only admins can write

---

### Collection: `config`
> App-wide configuration. Single document.

```
config/appSettings
├── locationName: string       // "Rohanské nábřeží 721/39"
├── companyName: string        // "EssilorLuxottica"
├── googleMapsURL: string
├── defaultTimeFrom: string    // "07:00"
├── defaultTimeTo: string      // "18:00"
├── autoAdvanceHour: number    // 17
├── selfBookingMaxAdvanceDays: number   // 3
├── selfBookingMaxPerDay: number        // 1
├── othersBookingMaxAdvanceDays: number // 7
├── othersBookingMaxDurationDays: number // 5
├── adminEmails: [string]      // List of admin emails
├── privilegedEmails: [string] // List of privileged emails
├── availableTimeSlots: [string]
└── updatedAt: timestamp
```

**Why in Firestore (not hardcoded)?**
- Admins can change rules without app update
- Add/remove admin users remotely
- Adjust booking constraints on the fly

---

## Authentication Strategy

### Firebase Auth with Microsoft (Entra ID) SSO
Since EssilorLuxottica uses corporate Microsoft accounts:

1. **Primary**: Firebase Auth with **Microsoft provider** (OIDC)
   - Users sign in with their `@essilor.com` / `@essilorluxottica.id` email
   - Firebase automatically creates a UID
   - No password management needed

2. **Fallback**: Firebase Auth with **Email Link** (passwordless)
   - Send magic link to corporate email
   - Good for `@ext.essilor.com` accounts if SSO isn't configured

3. **Development**: Firebase Auth with **Email/Password**
   - For testing during development
   - Can be disabled in production

### Auth Flow in App
```
Launch → Check Firebase Auth state
  ├── Signed in → Load user profile from Firestore → Home
  └── Not signed in → Sign In screen
        ├── "Sign in with Microsoft" (primary)
        └── "Sign in with Email Link" (fallback)
```

---

## Migration Architecture

### Current Architecture
```
┌─────────────┐     ┌──────────────┐
│   SwiftUI   │────▶│BookingManager│
│    Views    │     │ (UserDefaults)│
└─────────────┘     └──────────────┘
```

### Target Architecture
```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   SwiftUI   │────▶│BookingManager│────▶│  FirebaseRepo │
│    Views    │     │ (unchanged)  │     │  (Firestore)  │
└─────────────┘     └──────────────┘     └──────────────┘
                                               │
                                         ┌─────┴─────┐
                                         │ Firebase   │
                                         │ Auth +     │
                                         │ Firestore  │
                                         │ + FCM      │
                                         └───────────┘
```

### Key Principle: Views Don't Change
- `BookingManager` keeps the same `@Published` properties and method signatures
- Views continue using `@EnvironmentObject var bookingManager: BookingManager`
- Only the persistence layer inside BookingManager changes: `UserDefaults` → `Firestore`

---

## Implementation Steps

### Phase 1: Firebase Project Setup
1. Create Firebase project "el-parking" at console.firebase.google.com
2. Add iOS app with bundle ID `com.StivMalakjan.EL-PARKING-APP`
3. Download `GoogleService-Info.plist` → add to Xcode project
4. Add Firebase SPM packages:
   - `firebase-ios-sdk` → FirebaseAuth, FirebaseFirestore, FirebaseMessaging
5. Initialize Firebase in `ParkKingApp.swift`:
   ```swift
   import FirebaseCore
   FirebaseApp.configure()  // in init()
   ```

### Phase 2: Authentication
1. Create `AuthManager.swift` (ObservableObject):
   - `@Published var currentUser: FirebaseAuth.User?`
   - `@Published var isSignedIn: Bool`
   - `@Published var userProfile: UserProfile?`
   - Sign in / sign out methods
   - Auth state listener
2. Create `SignInView.swift` — sign-in screen
3. Gate `ContentView` behind auth check in `ParkKingApp`
4. Migrate `currentUserEmail`, `currentUserName` → from Firestore `users/{uid}`

### Phase 3: Firestore Repository
1. Create `FirestoreBookingRepository.swift`:
   ```swift
   class FirestoreBookingRepository {
       // Real-time listeners
       func listenToBookings(for date: Date) -> AsyncStream<[Booking]>
       func listenToUserBookings(email: String) -> AsyncStream<[Booking]>

       // CRUD
       func createBooking(_ booking: Booking) async throws
       func updateBooking(_ booking: Booking) async throws
       func cancelBooking(_ bookingID: String) async throws
       func adminCancelBooking(_ bookingID: String, by: String, reason: String) async throws

       // Queries
       func getBookingsForDate(_ date: Date) async throws -> [Booking]
       func isSpotAvailable(spotLabel: String, on date: Date) async throws -> Bool
   }
   ```
2. Add Firestore snapshot listeners for real-time updates
3. Implement optimistic updates (update local state immediately, sync to Firestore)

### Phase 4: Swap Persistence in BookingManager
1. Replace `loadBookings()` with Firestore listener:
   ```swift
   private func startListening() {
       db.collection("bookings")
           .whereField("status", isEqualTo: "active")
           .addSnapshotListener { snapshot, error in
               self.bookings = snapshot?.documents.compactMap {
                   try? $0.data(as: Booking.self)
               } ?? []
           }
   }
   ```
2. Replace `saveBookings()` with individual Firestore writes
3. Replace `saveUserProfile()` / `loadUserProfile()` with Firestore `users/{uid}`
4. Keep UserDefaults as offline cache (Firestore has built-in offline support)

### Phase 5: Push Notifications (FCM)
1. Store FCM token in `users/{uid}/fcmToken`
2. When admin cancels a booking → Cloud Function triggers:
   - Looks up affected user's FCM token
   - Sends push notification with booking details
   - Replaces current local-only `UNUserNotificationCenter` approach
3. Daily reminders → Cloud Function scheduled (cron) at user's preferred time

### Phase 6: Admin Features
1. Admin reads all bookings (no filter on email)
2. Admin can update any user's `role` in `users/{uid}`
3. Admin can block/unblock spots in `parkingSpots/{spotId}`
4. Config changes in `config/appSettings` propagate to all users in real-time

### Phase 7: Widget & Live Activity
1. Widget reads from shared UserDefaults (App Group) — same as now
2. `updateWidgetData()` still called after Firestore sync
3. Live Activities still managed locally (correct approach)

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: check if user is admin
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Helper: check if user is privileged
    function isPrivileged() {
      let role = get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
      return role == 'admin' || role == 'privileged';
    }

    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && (request.auth.uid == userId || isAdmin());
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && (
        request.auth.uid == userId && !('role' in request.resource.data) ||
        isAdmin()
      );
    }

    // Bookings collection
    match /bookings/{bookingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        resource.data.createdBy == request.auth.uid ||
        resource.data.userId == request.auth.uid ||
        isAdmin()
      );
      allow delete: if false; // Never delete, use status = "cancelled"
    }

    // Parking spots
    match /parkingSpots/{spotId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && isAdmin();
    }

    // App config
    match /config/{configId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && isAdmin();
    }
  }
}
```

---

## Booking Model Changes

### Current `Booking` struct → minimal changes needed:

```swift
struct Booking: Identifiable, Codable {
    @DocumentID var id: String?     // Was: UUID, now Firestore doc ID
    var spot: String                // Same
    var user: String                // Same
    var email: String               // Same
    var date: Date                  // Same (Firestore Timestamp auto-converts)
    var fromTime: String            // Same
    var toTime: String              // Same
    var createdBy: String           // Was email, now UID (or keep email for simplicity)
    var createdByEmail: String      // NEW — for display
    var status: String              // NEW — "active" | "cancelled"
    var cancelledBy: String?        // NEW
    var cancelReason: String?       // NEW
    var createdAt: Date?            // NEW — server timestamp
    var updatedAt: Date?            // NEW — server timestamp

    // All existing computed properties (spotNumber, isToday, etc.) — unchanged
}
```

### UserProfile (new model):
```swift
struct UserProfile: Codable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var firstName: String
    var role: UserRole
    var carDescription: String
    var registrationPlate: String
    var fcmToken: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum UserRole: String, Codable {
        case admin
        case privileged
        case user
    }
}
```

---

## Data Seeding Script

Run once to populate initial Firestore data:

### Parking Spots (15 documents):
```
63 → { label: "Parking 63", isAccessible: false, isBlocked: false, order: 0 }
64 → { label: "Parking 64", isAccessible: false, isBlocked: false, order: 1 }
65 → { label: "Parking 65", isAccessible: false, isBlocked: false, order: 2 }
66 → { label: "Parking 66", isAccessible: false, isBlocked: false, order: 3 }
67 → { label: "Parking 67", isAccessible: false, isBlocked: false, order: 4 }
68 → { label: "Parking 68", isAccessible: false, isBlocked: false, order: 5 }
71 → { label: "Parking 71", isAccessible: false, isBlocked: false, order: 6 }
72 → { label: "Parking 72", isAccessible: false, isBlocked: false, order: 7 }
73 → { label: "Parking 73", isAccessible: false, isBlocked: false, order: 8 }
74 → { label: "Parking 74", isAccessible: false, isBlocked: false, order: 9 }
75 → { label: "Parking 75", isAccessible: false, isBlocked: true,  order: 10 }
76 → { label: "Parking 76", isAccessible: false, isBlocked: false, order: 11 }
80 → { label: "Parking 80", isAccessible: true,  isBlocked: false, order: 12 }
81 → { label: "Parking 81", isAccessible: false, isBlocked: false, order: 13 }
82 → { label: "Parking 82", isAccessible: false, isBlocked: false, order: 14 }
```

### Admin Users (seed after first sign-in):
```
Set role = "admin" for:
  - stiv.malakjan@ext.essilor.com
  - katerina.zimova@essilor.cz
  - zimovak@essilor.cz
  - evelyna.leirvik@essilor.cz
  - leirvike@essilorluxottica.id
```

### App Config (1 document):
```
config/appSettings → all values from current AppConfig.swift
```

---

## Free Tier Budget Analysis

| Metric | Daily Estimate | Free Limit | Headroom |
|--------|---------------|------------|----------|
| Reads | ~500 (20 users × 25 reads) | 50,000 | 100× |
| Writes | ~60 (20 users × 3 actions) | 20,000 | 333× |
| Storage | ~5 KB/day new data | 1 GiB | Years |
| Auth MAU | 20 | 50,000 | 2,500× |
| FCM messages | ~40/day | Unlimited | ∞ |

**Verdict: Will never exceed free tier for this use case.**

---

## Files to Create/Modify

### New Files:
| File | Purpose |
|------|---------|
| `AuthManager.swift` | Firebase Auth state, sign in/out, user profile |
| `FirestoreBookingRepository.swift` | All Firestore CRUD and listeners |
| `UserProfile.swift` | User model matching Firestore `users` collection |
| `SignInView.swift` | Sign-in screen with Microsoft SSO |
| `FirestoreSeeder.swift` | One-time data seeding utility |

### Modified Files:
| File | Changes |
|------|---------|
| `ParkKingApp.swift` | Add `FirebaseApp.configure()`, auth gate |
| `BookingManager.swift` | Replace UserDefaults with FirestoreBookingRepository |
| `Booking.swift` | Add `@DocumentID`, `status`, `createdAt`, `updatedAt` fields |
| `AppConfig.swift` | Make dynamic (load from Firestore `config/appSettings`), keep defaults as fallback |
| `ContentView.swift` | Wrap in auth check |
| `SettingsView.swift` | Real sign-out button, profile from Firestore |

### Unchanged Files:
| File | Reason |
|------|--------|
| `HomeView.swift` | Uses BookingManager — no changes needed |
| `OverviewView.swift` | Uses BookingManager — no changes needed |
| `BookingSheet.swift` | Uses BookingManager — no changes needed |
| `SpotDetailSheet.swift` | Uses BookingManager — no changes needed |
| `MyBookingsView.swift` | Uses BookingManager — no changes needed |
| `UnifiedSpotCell.swift` | Pure UI component — no changes |
| `Date+Helpers.swift` | Pure utility — no changes |
| `ParkingWidget/*` | Reads from shared UserDefaults — no changes |

---

## Timeline Estimate

| Phase | Effort | Dependencies |
|-------|--------|-------------|
| Phase 1: Firebase setup | 30 min | Firebase console access |
| Phase 2: Authentication | 2-3 hours | GoogleService-Info.plist |
| Phase 3: Firestore repo | 2-3 hours | Phase 1 |
| Phase 4: Swap persistence | 1-2 hours | Phase 2 + 3 |
| Phase 5: Push notifications | 2-3 hours | Phase 4 + Apple push cert |
| Phase 6: Admin features | 1 hour | Phase 4 |
| Phase 7: Widget sync | 30 min | Phase 4 |
| **Total** | **~10-12 hours** | |

---

## Pre-Migration Checklist (Do Now)

- [x] Models are already `Codable` ✓
- [x] BookingManager is centralized (`@EnvironmentObject`) ✓
- [x] Views don't directly access persistence ✓
- [x] Admin/privileged role checks exist ✓
- [x] All booking operations go through BookingManager ✓
- [ ] Add `status` field to `Booking` model (backward compatible)
- [ ] Add `createdAt` / `updatedAt` to `Booking` model
- [ ] Change `Booking.id` from `UUID` to `String` (for Firestore document IDs)
- [ ] Create `UserProfile` model
- [ ] Add Firebase SPM dependency
