# US storefront preparation validation — 2026-10-17

Verified on Flutter 3.47.6 / Dart 3.13.5 and Xcode 26.3.

- Full Flutter suite: **1,147 passed**. Covers existing domain behavior, records, backups, cold start and UI. Cold-start ordering stays in a separate test directory without the normal catalog/binding preload.
- Localization/consent suite: **10 passed** after the last wording changes. Includes catalog coverage and placeholders, device language resolution, English/Traditional Chinese at 320 and 393 widths, persisted choice without record/plan rewriting, English food search and consent enforcement/decline.
- Native iOS XCTest: **12 passed** (storage, Keychain, photos, HTTPS, cancellation, notifications).
- `dart analyze`: no issues. Design-token check passed. Python release-tool tests: **5 passed**.
- Final Android APK and iOS release bundle language/legal assets were compared byte-for-byte against the working source and matched.
- iOS Simulator debug build succeeded. Actual simulator UI inspected in English. Native `InfoPlist.strings` confirmed in the built app for en, zh-Hans and zh-Hant.
- Unsigned iOS release build succeeded, about **23.1 MB**. This is not a signed archive or an App Store upload.
- Local public-site preview: all six privacy/support language URLs returned HTTP 200. Traditional Chinese page visually inspected at 390 px; no horizontal overflow.
- English catalog has 1,000+ curated entries, including all 300 food names, all portion units, common exercise names, dynamic counts and progression messages. Remaining longer guidance started from offline translation drafts and needs editorial acceptance before the store release.

## Public deployment

- Public GitHub Pages deployment is verified: `gh-pages` / root, HTTPS enforced. All six URLs returned unauthenticated HTTP 200 and their SHA-256 hashes matched the local HTML. Deployment commit: `12f296e586c84a7020584f79c93f180d3e73157b`.
- Privacy: https://hunter-ght.github.io/LeanDaily/privacy/ ; support: https://hunter-ght.github.io/LeanDaily/support/ . Chinese versions use `zh_Hans/` or `zh_Hant/` beneath each path.
## Not yet certified

- Physical iPhone camera, locked-screen delivery and large-text acceptance; signing, TestFlight and App Store review.
- Final App Store Connect privacy questionnaire, age rating, screenshots and legal/contact acceptance. `store_metadata.json` is draft copy, not submitted metadata.
- Android debug APK build succeeded (`build/app/outputs/flutter-apk/app-debug.apk`). Required SDK/NDK/CMake components were installed by the existing Android tooling. No physical Android device acceptance was performed in this pass.

## Latest AI provider preparation — 2026-10-17

This supersedes the earlier Flutter count for the current implementation:

- Full Flutter suite: **1,166 passed**. New coverage checks exact provider identity, no send before consent, revision-1 consent invalidation, `store=false` for both official OpenAI protocols, unchanged custom-provider request schema, draft-only preset changes, and English/Simplified/Traditional disclosure cancellation. A 320×568 screen with 1.7× text can scroll policy content while both decision buttons remain usable.
- `dart analyze`: no issues; design-token lint and all five Python release-tool tests passed.
- Unsigned iOS Release and Android debug APK builds passed. All three packaged legal policies match source bytes on both platforms; the iOS collected-data privacy manifest matches its source.
- Policy text now distinguishes optional official OpenAI usage from arbitrary custom services, explains response storage versus safety retention, and includes current OpenAI data-control links. Privacy manifest conservatively covers optional AI flows; final App Store Connect answers still require publisher acceptance.
- No real API request was sent: API account permissions, billing, model access and live output quality are **not verified**. No production credentials are embedded.
- User confirmed an organization Apple Developer team and App Manager role. Certificates/Identifiers/Profiles access, signed archive, live TestFlight acceptance and store submission remain unverified. Public publisher identity and support email are explicitly deferred by the user. See `APP_STORE_NEXT_STEPS.md` for the exact handoff.

## API input and Google Gemini preparation — 2026-10-18

- Full Flutter regression: **1,192 passed**. Provider-focused suite: **16 passed**; an additional focused check verifies the long-press Paste menu is actually visible and its action pastes text. No real credentials are used.
- API Key is normal text input with correction/suggestions/autofill disabled. FormInput now uses the unstyled Cupertino editing wrapper for selection gestures and context menus; numeric input and app styling remain covered by the full suite. Explicit paste reads the clipboard only when tapped, stays in the draft and does not save or send automatically.
- Gemini example: exact Google /v1beta/openai/ base, gemini-3.5-flash-lite, Chat Completions. Tests verify image payload, one /chat/completions suffix, no unsupported OpenAI store flag, consent blocking, age blocking and cross-provider key clearing.
- Three-language Gemini disclosures fit 320px screens; settings and consent screenshots inspected. Policies and iOS privacy manifest include the Google unpaid-service distinction. Publisher still needs to confirm service eligibility, privacy questionnaire and under-18 API-client terms before distribution.
- dart analyze and design-token lint pass; five Python release-tool tests pass. iOS unsigned Release build succeeded (23.6 MB); packaged legal assets and privacy manifest match source. This is not a new signed IPA or TestFlight upload.
- No live Google API call, account quota or physical iPhone paste/keyboard verification was performed. The previously uploaded 2.3.2 (24) IPA does not contain these changes.
