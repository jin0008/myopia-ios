# Eyelog iOS (아이로그)

An iPhone app for parents/guardians to monitor their children's **axial length (AL)** measurements collected at myopia-management clinics registered on [myopiamanage.org](https://myopiamanage.org).

The app is a **read-only** clinical viewer for regular users (parents). All axial-length data is pulled from the existing myopiamanage.org PostgreSQL database via a new set of mobile-specific API endpoints under `/api/mobile/*`. Parents cannot enter measurement data themselves — only clinicians who operate on the web do.

> **Branding:** App name is **Eyelog** (한글: 아이로그). The logo and color palette match the web site at myopiamanage.org (brand blue `#0d47a1`). Source SVGs live in `Eyelog/Resources/` and are referenced from `Assets.xcassets` as `BrandLogo`, `BrandLogoEnglish`, and `BrandMark`.

> **Status:** Scaffold / specification repo. No production build yet.

---

## What the app does

| # | Capability | v1 | v2 |
|---|------------|----|----|
| 1 | Sign up / log in as a regular user | ✅ | |
| 2 | Log in with ID+password, Google, Apple, Kakao, Naver | ✅ | |
| 3 | Register one or more children (DOB, sex, nickname) | ✅ | |
| 4 | Link a child to a hospital by **hospital code + registration number** | ✅ | |
| 5 | Link a child to *additional* hospitals the child also visits | ✅ | |
| 6 | View merged axial-length growth chart across all linked hospitals | ✅ | |
| 7 | View refractive error, mean-K, and treatment history | ✅ | |
| 8 | Automatic iPhone screen-time capture (near-work activity) | | ✅ |
| 9 | Push notifications when a new measurement arrives | | ✅ |

---

## Tech stack

- **iOS 17+**, **Swift 5.10**, **SwiftUI**
- **Swift Charts** for the axial-length growth graph
- **async/await** networking layer, Keychain for token storage
- **Sign in with Apple**, **Google Sign-In SDK**, **Kakao SDK**, **Naver Login SDK**, password login
- Backend: existing Node/Express/Prisma server at `myopiamanage.org`, extended with `/api/mobile/*` endpoints (see [`docs/BACKEND_CHANGES.md`](docs/BACKEND_CHANGES.md))
- Database: existing **PostgreSQL** on Google Cloud; four additive tables — `parent_child_link`, `child_hospital_link`, `mobile_refresh_token`, `oauth_identity`

---

## Repo layout

```
myopia-ios/
├── Eyelog/              # Xcode app target source folder
│   ├── App/                    # @main entry (EyelogApp.swift), RootView
│   ├── Core/
│   │   ├── Auth/               # Auth providers (Apple, Google, Kakao, Naver, password)
│   │   ├── Models/             # Codable structs mirroring backend DTOs
│   │   ├── Networking/         # APIClient, endpoints, error types
│   │   └── Storage/            # Keychain + UserDefaults wrappers
│   ├── Features/
│   │   ├── Auth/               # Login / Signup / Social buttons
│   │   ├── Children/           # Add child, list children, child profile
│   │   ├── Hospitals/          # Link hospital flow, list linked hospitals
│   │   ├── AxialLength/        # Swift Charts graph + measurement list
│   │   └── ScreenTime/         # Family Controls plan (v2)
│   └── Resources/
│       ├── eyelog-logo.svg            # Full Eyelog wordmark (Korean)
│       ├── eyelog-english.svg         # English wordmark
│       ├── eyelog-mark.svg            # Glyph / app icon source
│       ├── Info.plist                 # Template — copy keys into Xcode target
│       └── Assets.xcassets/
│           ├── AppIcon.appiconset/    # All 15 iOS icon PNGs (rasterized)
│           ├── BrandLogo.imageset/    # References eyelog-logo.svg
│           ├── BrandLogoEnglish.imageset/
│           ├── BrandMark.imageset/
│           └── AccentColor.colorset/  # Eyelog blue #0d47a1
├── docs/
│   ├── ARCHITECTURE.md
│   ├── API_SPEC.md
│   ├── BACKEND_CHANGES.md
│   └── SCREEN_TIME_PLAN.md
└── .github/workflows/ios.yml   # CI (SwiftLint + xcodebuild)
```

---

## First-time setup

1. **Create the Xcode project shell**
   Open Xcode → **File → New → Project → iOS → App**.
   - Product name: **Eyelog**
   - Interface: SwiftUI · Language: Swift · Minimum iOS: 17.0
   - Organization identifier: e.g. `org.myopiamanage`
2. **Point the project at this folder's sources.** Delete the auto-generated `ContentView.swift` and the `EyelogApp.swift` Xcode creates, then drag the files under `Eyelog/` into the project (Create groups, add to the `Eyelog` target). Make sure `Assets.xcassets` is in the target's "Copy Bundle Resources" phase.
3. **Install Swift packages** (File → Add Package Dependencies):
   - `https://github.com/google/GoogleSignIn-iOS`
   - `https://github.com/kakao/kakao-ios-sdk` (via Swift Package)
   - `https://github.com/naver/naveridlogin-sdk-ios-swift`
4. **Configure URL schemes & Info.plist keys** – copy the template at [`Eyelog/Resources/Info.plist`](Eyelog/Resources/Info.plist) into the target, or let Xcode auto-generate and copy individual keys. Details in [`docs/ARCHITECTURE.md § Auth configuration`](docs/ARCHITECTURE.md).
5. **Set backend base URL** in `Eyelog/Core/Networking/APIConfig.swift` (or via the `API_BASE_URL` build setting referenced from `Info.plist`).

---

## See also

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) – full system design
- [`docs/API_SPEC.md`](docs/API_SPEC.md) – every mobile endpoint contract
- [`docs/BACKEND_CHANGES.md`](docs/BACKEND_CHANGES.md) – what was added on myopiamanage.org
- [`docs/SCREEN_TIME_PLAN.md`](docs/SCREEN_TIME_PLAN.md) – how the Family Controls feature ships in v2
- [`PUSH_TO_GITHUB.md`](PUSH_TO_GITHUB.md) – commands to create the GitHub repo and push

## License

TBD (suggest MIT or a proprietary license — discuss with your hospital/institution).
