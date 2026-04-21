# Architecture

## 1. System diagram

```
                ┌───────────────────────────────┐
                │       iPhone (iOS 17+)        │
                │  MyopiaCareApp (SwiftUI)      │
                │                               │
                │  ┌─────────────────────────┐  │
                │  │ Auth providers          │  │
                │  │ • Password              │  │
                │  │ • Sign in with Apple    │  │
                │  │ • Google Sign-In        │  │
                │  │ • Kakao Login           │  │
                │  │ • Naver Login           │  │
                │  └─────────────┬───────────┘  │
                │                │              │
                │  ┌─────────────▼──────────┐   │
                │  │ APIClient (async/await)│   │
                │  │  Bearer <JWT>          │   │
                │  └─────────────┬──────────┘   │
                └────────────────┼──────────────┘
                                 │ HTTPS
                                 ▼
   ┌─────────────────────────────────────────────────────┐
   │     Google Cloud Compute Engine (existing VM)       │
   │                                                     │
   │  ┌─────────────────────────────────────────────┐    │
   │  │   Node/Express server (existing)            │    │
   │  │   /api/*     ← web routes (unchanged)       │    │
   │  │   /api/mobile/*  ← NEW routes for iOS       │    │
   │  └──────────────┬──────────────────────────────┘    │
   │                 │                                   │
   │  ┌──────────────▼──────────────┐                    │
   │  │ PostgreSQL (existing)       │                    │
   │  │ • patient, measurement, ... │                    │
   │  │ • NEW: parent_guardian      │                    │
   │  │ • NEW: parent_child_link    │                    │
   │  │ • NEW: child_hospital_link  │                    │
   │  │ • NEW: hospital_link_request│                    │
   │  └─────────────────────────────┘                    │
   └─────────────────────────────────────────────────────┘
```

## 2. Core domain concepts

| Concept on web | Concept in app | Relationship |
|----------------|----------------|--------------|
| `user` (`regular_user` role) | **Parent/Guardian** account | 1:1 |
| `patient` (registration_number + hospital_id) | **Child profile** | 1:N via `parent_child_link` |
| `hospital` | Hospital a child visits | N:M via `child_hospital_link` |
| `axial_length`, `refractive_error`, `mean_k`, `treatment` | Measurements shown in the app | fetched read-only |

### Why a new `parent_guardian` concept?

The existing `user` table with role `regular_user` already represents a parent who has logged in. The web app lets that user *be* the patient, or create a patient record. The iOS app deliberately narrows this: a logged-in user can only manage **children** (never themselves as patient), and only via **linking** to clinical records that clinicians already entered.

In v1, we reuse `user` with `role='regular_user'` and introduce a `parent_child_link` table keyed by `(user_id, patient_id)`. No change to the existing `user` schema.

### Hospital linking rule

A child is linked to a patient record only when **both** of these match an existing row in `patient`:
1. `hospital_code` (the hospital's registration code in `hospital` table)
2. `registration_number` (the patient's MRN at that hospital)

A parent may also add the child's **date of birth** and **sex**, which must additionally match the stored record for the link to succeed (a "triple check" — reduces accidental linking to another child).

Multiple hospitals are supported: a child can be linked to `patient` rows at several hospitals. The app merges and deduplicates measurements across linked hospitals when rendering the chart.

## 3. Authentication

### Goal
Accept any of: Password, Google, Apple, Kakao, Naver. On success, the server issues a **mobile JWT** (short-lived access + refresh), stored in the iOS Keychain.

### Flow (all providers identical after step 3)
1. User taps "Sign in with <provider>"
2. iOS provider SDK returns an `idToken` (Google/Apple) or an `accessToken` (Kakao/Naver)
3. App POSTs `{provider, token}` to `/api/mobile/auth/social`
4. Server verifies the token against the provider's public keys / userinfo endpoint
5. Server finds-or-creates a `user` row with `role='regular_user'` and an OAuth linking row
6. Server returns `{accessToken, refreshToken, user}`
7. App stores tokens in Keychain and transitions to the Home tab

### Password flow
- Signup: `POST /api/mobile/auth/signup` with `{username, password, email}` → returns JWT
- Login: `POST /api/mobile/auth/login` with `{username, password}` → returns JWT
- Reuses the existing `password_auth` table.

### Token lifecycle
- Access token: JWT, 1 hour, HS256
- Refresh token: opaque, 90 days, stored hashed in `mobile_refresh_token` table
- Refresh endpoint: `POST /api/mobile/auth/refresh`

## 4. App navigation

```
RootView
├── if !isAuthenticated → LoginView
│       ├── password fields
│       ├── [Sign in with Apple]
│       ├── [Sign in with Google]
│       ├── [카카오 로그인]
│       ├── [네이버 로그인]
│       └── [Create account]
└── if isAuthenticated → MainTabView
        ├── Home (list of children + add button)
        │     └── ChildDetailView
        │           ├── Overview (DOB, sex, linked hospitals)
        │           ├── AxialLengthChartView (Swift Charts)
        │           ├── MeasurementListView
        │           └── LinkedHospitalsView
        │                 └── AddHospitalLinkView (code + MRN)
        └── Settings
              ├── Account info
              ├── Change password / linked auth providers
              ├── Privacy policy / TOS (links to myopiamanage.org)
              └── Logout / Delete account
```

## 5. Networking layer

Single `APIClient` (actor) with:
- `func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T`
- Automatic token refresh on 401
- JSON date decoding with ISO-8601
- Typed errors: `.unauthorized`, `.network`, `.server(code, message)`, `.decoding`

See [`MyopiaCareApp/Core/Networking/APIClient.swift`](../MyopiaCareApp/Core/Networking/APIClient.swift).

## 6. Data storage on device

| What | Where | Why |
|------|-------|-----|
| Access token, refresh token | Keychain (`kSecAttrAccessibleAfterFirstUnlock`) | Sensitive |
| Selected child ID (UI preference) | `UserDefaults` | Non-sensitive |
| Cached child list + last measurements | `URLCache` or simple on-disk JSON | Offline support v2 |

**No PHI is persisted at rest in v1** beyond the current in-memory view. v2 will introduce encrypted SQLite for offline mode (with a BAA/DPIA if you ship outside Korea).

## 7. Auth configuration (Info.plist & URL Schemes)

```xml
<key>CFBundleURLTypes</key>
<array>
  <!-- Google -->
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.googleusercontent.apps.YOUR_CLIENT_ID</string></array>
  </dict>
  <!-- Kakao -->
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>kakaoYOUR_NATIVE_APP_KEY</string></array>
  </dict>
  <!-- Naver -->
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>YOUR_NAVER_URL_SCHEME</string></array>
  </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>kakaokompassauth</string>
  <string>kakaolink</string>
  <string>naversearchapp</string>
  <string>naversearchthirdlogin</string>
</array>

<key>GIDClientID</key>
<string>YOUR_GOOGLE_IOS_CLIENT_ID</string>

<key>KAKAO_APP_KEY</key>
<string>YOUR_KAKAO_NATIVE_APP_KEY</string>
```

Add **Sign in with Apple** capability in Xcode (Signing & Capabilities → + → Sign in with Apple). No Info.plist change needed.

## 8. Privacy & App Store review

- **Privacy Nutrition Label**: Health & Fitness (Clinical) and User Content (Auth identifiers). Point to myopiamanage.org's privacy policy.
- **NSHealthShareUsageDescription** is *not* required since we do not read HealthKit in v1.
- When v2 adds Family Controls, you will need Apple's Family Controls entitlement (see [`SCREEN_TIME_PLAN.md`](SCREEN_TIME_PLAN.md)).
- Pediatric data → treat children's data as highly sensitive; avoid analytics SDKs that send identifiers.

## 9. Build & release

- CI (see `.github/workflows/ios.yml`): SwiftLint + `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 15'`
- Release flow (out of scope for v1): Fastlane + match for signing, TestFlight for beta, App Store Connect for distribution.
