# Push this scaffold to a new GitHub repo

> The scaffold currently sits inside the web repo at `myopia/myopia-ios/`. Step 1 moves it out so it becomes its own standalone repo.

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
git commit -m "chore: initial scaffold for 수리수리 (EAGLE vision) iOS app"
```

## 3. Create the GitHub repo and push

```bash
# --private is recommended because this references your clinical product.
gh repo create myopia-ios \
  --private \
  --description "EAGLE vision (수리수리) — iPhone app for parents to monitor children's axial length via myopiamanage.org" \
  --source=. \
  --remote=origin \
  --push
```

This creates `https://github.com/<your-username>/myopia-ios` and pushes your `main` branch.

## 4. Create the Xcode project inside the repo

You'll need Xcode to create the `.xcodeproj` (it's binary, so it can't be generated cleanly from a text-only scaffold). Because the scaffold already has an `EagleVision/` folder with our sources in it, create the Xcode project in a **temp location** first, then move just the `.xcodeproj` into place — this avoids a folder-name collision.

1. Open Xcode → **File → New → Project → iOS → App**.
2. Product name: **EagleVision** · Team: your Apple Developer team · Organization identifier: e.g. `org.myopiamanage` · Interface: **SwiftUI** · Language: **Swift** · Minimum iOS: **17.0**.
3. Save it into a throwaway folder like `~/Desktop/xcode-tmp/`. Xcode will create `~/Desktop/xcode-tmp/EagleVision/` with a `.xcodeproj` and some starter Swift files.
4. Move the `.xcodeproj` into the repo and delete the throwaway tree:
   ```bash
   mv ~/Desktop/xcode-tmp/EagleVision/EagleVision.xcodeproj ~/code/myopia-ios/
   rm -rf ~/Desktop/xcode-tmp
   ```
5. Open `~/code/myopia-ios/EagleVision.xcodeproj` in Xcode. The project will show missing-file warnings because the sources it was pointing at no longer exist. In the Project Navigator:
   - **Remove** the auto-generated `EagleVisionApp.swift`, `ContentView.swift`, `Assets.xcassets`, and `Preview Content` references (Right-click → **Delete → Remove Reference**, NOT "Move to Trash").
   - Drag the scaffold's `EagleVision/App/`, `EagleVision/Core/`, `EagleVision/Features/`, and `EagleVision/Resources/` folders from Finder into the navigator. In the import dialog, check **Create groups** and **Add to target: EagleVision**. Confirm `Assets.xcassets` is in the "Copy Bundle Resources" build phase.
6. Point `INFOPLIST_FILE` at the scaffold's template: target → **Build Settings → Info.plist File** → `EagleVision/Resources/Info.plist`, and set `GENERATE_INFOPLIST_FILE = NO`. Then set the remaining build settings (target → Build Settings, or in an `.xcconfig`):
   ```
   PRODUCT_NAME = EagleVision
   PRODUCT_BUNDLE_IDENTIFIER = org.myopiamanage.EagleVision
   KAKAO_APP_KEY = <native-app-key>
   NAVER_CONSUMER_KEY = <consumer-key>
   NAVER_CONSUMER_SECRET = <consumer-secret>
   API_BASE_URL = https://api.myopiamanage.org
   ```
7. Add these Swift Package dependencies (File → Add Package Dependencies…):
   - `https://github.com/google/GoogleSignIn-iOS`
   - `https://github.com/kakao/kakao-ios-sdk-spm` (KakaoSDKCommon, KakaoSDKAuth, KakaoSDKUser)
   - `https://github.com/naver/naveridlogin-sdk-ios-swift`
8. In **Signing & Capabilities** → **+ Capability** → add **Sign in with Apple**.
9. Drop the Google `GoogleService-Info.plist` in the project root and add the reversed client ID to the `CFBundleURLSchemes` array (already stubbed in `Resources/Info.plist`).

## 5. Commit the Xcode project

```bash
cd ~/code/myopia-ios
git add EagleVision.xcodeproj Package.resolved 2>/dev/null || true
git add .
git commit -m "chore: add Xcode project + SPM deps"
git push
```

## 6. Branch-protection, secrets, and next steps

- **Branch protection**: in the GitHub repo settings, require PR review on `main`.
- **Secrets** for CI (Settings → Secrets and variables → Actions):
  - `APP_STORE_CONNECT_API_KEY` (when you add Fastlane)
- **Apple Developer portal**:
  - Create App ID matching your bundle id (e.g. `org.myopiamanage.EagleVision`).
  - Enable **Sign in with Apple** capability on the App ID.
  - Upload a Services ID and private key `.p8` to the VM (path referenced by `APPLE_PRIVATE_KEY_PATH`).
- **Provider consoles**:
  - [Google Cloud Console](https://console.cloud.google.com/) → OAuth credentials → add an **iOS** client → copy the iOS client ID into both the app's `Info.plist` (`GIDClientID`) and the backend `.env` (`GOOGLE_IOS_CLIENT_ID`).
  - [Kakao Developers](https://developers.kakao.com/) → create an iOS app → copy **Native app key** into `Info.plist` (`KAKAO_APP_KEY`). Backend verifies against the user-info endpoint so no Kakao secret is needed server-side.
  - [Naver Developers](https://developers.naver.com/) → create a mobile app → copy Client ID / Secret and URL scheme into the Info.plist build settings above. Backend verifies via the user-info endpoint.

## 7. Deploy backend changes

The backend changes have already been applied under `myopiaBackend/` — see `myopiaBackend/MOBILE_API_SETUP.md` for:

- running `npx prisma migrate deploy` against your dev/prod DB,
- the env vars that must be added to the VM,
- the list of `/api/mobile/*` endpoints to smoke-test after deploy.

No new route file needs to be copied from this repo — the reference implementation lives in `myopiaBackend/src/routes/mobile.ts`.
