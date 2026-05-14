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
- No HTML injection (`textContent` only; no `innerHTML` rendering of user data)
- CSP meta policy in `index.html`
- No service-account keys or private credentials in repo
- `web/firebase-config.js` is gitignored and generated only during deploy

## 1) Firebase prerequisites

1. Firebase Console -> Project Settings -> General -> create/select your **Web app**.
2. Firebase Auth -> Sign-in method -> enable **Email/Password**.
3. Firebase Auth -> Settings -> **Authorized domains**:
   - `kerberos381.github.io`
4. Keep Firestore rules strict (owner/admin-only writes and scoped reads).

## 2) GitHub secret for deploy

Set repository secret:

- Name: `FIREBASE_WEB_CONFIG_JSON`
- Value (single-line JSON):

```json
{"apiKey":"YOUR_NEW_WEB_API_KEY","authDomain":"el-parking-app.firebaseapp.com","projectId":"el-parking-app","storageBucket":"el-parking-app.firebasestorage.app","messagingSenderId":"58986005782","appId":"YOUR_WEB_APP_ID"}
```

Notes:
- This value is injected into `web/firebase-config.js` during GitHub Actions deploy.
- API keys for Firebase web are not private secrets by themselves; protection comes from key restrictions + Firebase rules.

## 3) Deploy to GitHub Pages

Workflow file:

- `.github/workflows/deploy-web-pages.yml`

Flow:
- Runs on push to `main` for `web/**` changes (or manual run).
- Fails fast if `FIREBASE_WEB_CONFIG_JSON` secret is missing.
- Generates runtime `web/firebase-config.js` from secret and deploys `web/`.

## 4) Key restrictions (required)

In Google Cloud Console for the new web API key:

- Application restriction: **Websites**
- Allowed referrers:
  - `https://kerberos381.github.io/*`
  - `https://kerberos381.github.io/EL-PARKING-APP/*`
- API restriction: at minimum `Identity Toolkit API`

## 5) Optional next security step (recommended)

Enable Firebase App Check for web (reCAPTCHA v3 or Enterprise), then enforce App Check in Firestore/Storage to reduce scripted abuse.
