# MyopiaCare iOS

An iPhone app for parents/guardians to monitor their children's **axial length (AL)** measurements collected at myopia-management clinics registered on [myopiamanage.org](https://myopiamanage.org).

The app is a **read-only** clinical viewer for regular users (parents). All axial-length data is pulled from the existing myopiamanage.org PostgreSQL database via a new set of mobile-specific API endpoints. Parents cannot enter measurement data themselves — only clinicians who operate on the web do.

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
- Backend: existing Node/Express server at `myopiamanage.org`, extended with `/api/mobile/*` endpoints (see [`docs/BACKEND_CHANGES.md`](docs/BACKEND_CHANGES.md))
- Database: existing **PostgreSQL** on Google Cloud (no schema changes for v1 other than new `parent_guardian`, `parent_child_link` and `child_hospital_link` tables)

---

## Repo layout

```
myopia-ios/
├── MyopiaCareApp/              # Xcode app target (you create the .xcodeproj once)
│   ├── App/                    # AppDelegate, @main entry, RootView
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
│   └── Resources/              # Assets.xcassets, Info.plist snippets
├── backend-patches/            # Drop-in TypeScript files for myopiamanage.org server
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
   Open Xcode → **File → New → Project → iOS → App**. Product name `MyopiaCareApp`, interface SwiftUI, language Swift, minimum iOS 17.
2. **Point the project at this folder's sources.** Delete the auto-generated `ContentView.swift` and drag the files under `MyopiaCareApp/` into the project (Create groups, add to `MyopiaCareApp` target).
3. **Install Swift packages** (File → Add Package Dependencies):
   - `https://github.com/google/GoogleSignIn-iOS`
   - `https://github.com/kakao/kakao-ios-sdk` (via Swift Package)
   - `https://github.com/naver/naveridlogin-sdk-ios-swift`
4. **Configure URL schemes & Info.plist keys** – see [`docs/ARCHITECTURE.md § Auth configuration`](docs/ARCHITECTURE.md).
5. **Set backend base URL** in `MyopiaCareApp/Core/Networking/APIConfig.swift`.

---

## See also

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) – full system design
- [`docs/API_SPEC.md`](docs/API_SPEC.md) – every mobile endpoint contract
- [`docs/BACKEND_CHANGES.md`](docs/BACKEND_CHANGES.md) – what you need to add on myopiamanage.org
- [`docs/SCREEN_TIME_PLAN.md`](docs/SCREEN_TIME_PLAN.md) – how the Family Controls feature ships in v2
- [`PUSH_TO_GITHUB.md`](PUSH_TO_GITHUB.md) – commands to create the GitHub repo and push

## License

TBD (suggest MIT or a proprietary license — discuss with your hospital/institution).
