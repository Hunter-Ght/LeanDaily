# US storefront preparation validation — 2026-10-17

Verified on Flutter 3.47.6 / Dart 3.13.5 and Xcode 26.3.

- Full Flutter suite: **1,147 passed**. Covers existing domain behavior, records, backups, cold start and UI. Cold-start ordering stays in a separate test directory without the normal catalog/binding preload.
- Localization/consent suite: **10 passed** after the last wording changes. Includes catalog coverage and placeholders, device language resolution, English/Traditional Chinese at 320 and 393 widths, persisted choice without record/plan rewriting, English food search and consent enforcement/decline.
- Native iOS XCTest: **12 passed** (storage, Keychain, photos, HTTPS, cancellation, notifications).
- `dart analyze`: no issues. Design-token check passed. Python release-tool tests: **5 passed**.
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
- Android debug build status is recorded below after the build finishes; no physical Android device acceptance was performed in this pass.
