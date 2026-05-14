# EL Parking Web (GitHub Pages)

This is a static web front-end for EL Parking, designed to mirror the mobile product flow while staying safe for a public-hosted deployment.

## What is implemented

- Firebase Email/Password login
- Active/pending account gate (`users/{uid}.status`)
- Home hero with current/upcoming booking
- Parking overview for selected date (free/booked/blocked + grid)
- Book a spot (canonical Firestore write shape)
- My bookings list + cancel
- Admin snapshot (read-only counts)
- Settings profile save (`displayName`, `preferredVocative`, `registrationPlate`, `carDescription`)

## Security hardening included

- Session-scoped auth persistence (`browserSessionPersistence`)
- Narrow Firestore reads (date-bounded where possible)
- No HTML injection (`textContent` only; no `innerHTML` rendering of user data)
- CSP meta policy in `index.html`
- No service-account keys or server secrets
- Local `firebase-config.js` ignored by git

## 1) Configure Firebase for web

1. In Firebase Console -> Project Settings -> General -> Your Apps, create a **Web app**.
2. Copy `web/firebase-config.example.js` to `web/firebase-config.js`.
3. Paste your web app config values.
4. Firebase Auth -> Settings -> **Authorized domains**:
   - add your GitHub Pages host (for example `kerberos381.github.io`).

## 2) Firestore + Storage rules baseline

Use your existing app rules. For this web app to work:

- `users/{uid}`: user can read own profile, admin can read broader scope
- `bookings/*`: enforce owner/admin permissions for create/delete
- `parkingSpots/*`: read for authenticated users
- `announcements/*`: read for authenticated users

## 3) Deploy to GitHub Pages

This repo contains workflow:

- `.github/workflows/deploy-web-pages.yml`

It deploys `web/` as static site when pushed to `main` with web changes.

If your default branch is not `main`, update workflow branch filter.

## 4) Optional next security step (recommended)

Enable Firebase App Check for web (reCAPTCHA v3 or Enterprise), then enforce App Check in Firestore/Storage. This reduces abuse from scripted clients.
