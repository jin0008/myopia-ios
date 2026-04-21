# Push this scaffold to a new GitHub repo

> I created the scaffold inside your existing web repo at `myopia/myopia-ios/`. Step 1 moves it out so it becomes its own standalone repo.

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated — run `gh auth login` if needed.
- Xcode 15.4 or later.

## 1. Move the scaffold out to its own folder

```bash
# from a terminal, on your Mac
mv ~/code/myopia/myopia/myopia-ios ~/code/myopia-ios
cd ~/code/myopia-ios
```

## 2. Initialize git

```bash
git init -b main
git add .
git commit -m "chore: initial scaffold for MyopiaCare iOS app"
```

## 3. Create the GitHub repo and push

```bash
# --private is recommended because this references your clinical product.
gh repo create myopia-ios \
  --private \
  --description "iPhone app for parents to monitor children's axial length via myopiamanage.org" \
  --source=. \
  --remote=origin \
  --push
```

This creates `https://github.com/<your-username>/myopia-ios` and pushes your `main` branch.

## 4. Create the Xcode project inside the repo

You'll need Xcode to create the `.xcodeproj` (it's binary, so I can't generate one from here cleanly).

1. Open Xcode → **File → New → Project → iOS → App**.
2. Product name: **MyopiaCareApp** · Team: your Apple Developer team · Organization identifier: e.g. `org.myopiamanage` · Interface: **SwiftUI** · Language: **Swift** · Minimum iOS: **17.0**.
3. Save it into `~/code/myopia-ios/` (so the `.xcodeproj` sits next to the existing `MyopiaCareApp/` folder from the scaffold).
4. In the Xcode Project Navigator, delete the auto-generated `ContentView.swift` and `MyopiaCareAppApp.swift` (the ones Xcode created — we will use the ones from this scaffold).
5. Drag the scaffold's `MyopiaCareApp/App/`, `MyopiaCareApp/Core/`, `MyopiaCareApp/Features/` folders into the Xcode navigator. In the import dialog, check **Create groups** and **Add to target: MyopiaCareApp**.
6. Add these Swift Package dependencies (File → Add Package Dependencies…):
   - `https://github.com/google/GoogleSignIn-iOS`
   - `https://github.com/kakao/kakao-ios-sdk-spm` (KakaoSDKCommon, KakaoSDKAuth, KakaoSDKUser)
   - `https://github.com/naver/naveridlogin-sdk-ios-swift`
7. In **Signing & Capabilities** → **+ Capability** → add **Sign in with Apple**.
8. In `Info.plist`, add the URL schemes listed under `docs/ARCHITECTURE.md § Auth configuration`.

## 5. Commit the Xcode project

```bash
cd ~/code/myopia-ios
git add MyopiaCareApp.xcodeproj Package.resolved 2>/dev/null || true
git add .
git commit -m "chore: add Xcode project + SPM deps"
git push
```

## 6. Branch-protection, secrets, and next steps

- **Branch protection**: in the GitHub repo settings, require PR review on `main`.
- **Secrets** for CI (Settings → Secrets and variables → Actions):
  - `APP_STORE_CONNECT_API_KEY` (when you add Fastlane)
- **Apple Developer portal**:
  - Create App ID matching your bundle id (e.g. `org.myopiamanage.MyopiaCareApp`).
  - Enable **Sign in with Apple** capability on the App ID.
  - Upload a Services ID and private key `.p8` to the VM (path referenced by `APPLE_PRIVATE_KEY_PATH`).
- **Provider consoles**:
  - [Google Cloud Console](https://console.cloud.google.com/) → OAuth credentials → add an **iOS** client → copy the iOS client ID into both the app's `Info.plist` (`GIDClientID`) and the backend `.env` (`GOOGLE_IOS_CLIENT_ID`).
  - [Kakao Developers](https://developers.kakao.com/) → create an iOS app → copy **Native app key** into `Info.plist` (`KAKAO_APP_KEY`) and **REST API key** into backend `.env` (`KAKAO_REST_API_KEY`).
  - [Naver Developers](https://developers.naver.com/) → create a mobile app → copy Client ID / Secret into backend `.env`, URL scheme into `Info.plist`.

## 7. Deploy backend changes

From `~/code/myopia/myopia` (your web repo), copy `~/code/myopia-ios/backend-patches/mobile.ts` into `src/api/mobile.ts`, mount the router as shown in `docs/BACKEND_CHANGES.md`, run the SQL migration, set the new env vars on your Compute Engine VM, and redeploy.
