# US storefront / three-language implementation

## Included

- Flutter localization for English, Simplified Chinese and Traditional Chinese. Defaults to the device language with English fallback. Me → Language can override it; the preference is stored separately from domain data.
- Shared iOS/Android UI catalogs under `assets/l10n/`; Simplified Chinese source strings remain canonical. `LText` is a compatibility display boundary for existing Chinese exercise/food names, dynamic messages and rich text. It does not translate or migrate stored records. Framework/system controls use Flutter's official localization delegates. Future new features should use unambiguous complete message keys, not string concatenation.
- English search and Traditional Chinese search for built-in foods return canonical food entries. User input stays as entered.
- iOS app name/camera permission and Android launcher name have native locale resources. System permission dialogs follow OS language; manually choosing an in-app language does not change the OS language.
- Offline legal policies for all three languages, public static privacy/support pages, and a dedicated Pages publishing branch.
- AI consent bound to disclosure revision, HTTPS endpoint and protocol; backend enforces it before reading photos or making HTTP requests. Consent is excluded from backup, revoked on restore, and can be revoked in advanced settings. AI prose requests the current app language.

## Publication

1. Commit the intended `website/` changes. Run `python3 tool/publish_site.py --dry-run` to inspect, then `python3 tool/publish_site.py` to publish.
2. Repository Settings → Pages uses **Deploy from a branch**, **gh-pages**, **/ (root)**. The publishing branch contains only public site files; application source branches are unaffected.
3. Confirm all six privacy/support language URLs load without login on phone and desktop. Only then fill App Store Connect privacy/support URLs.

The repository source page alone is not the public website. Enabling Pages requires repository administration access. Do not claim deployment until the public URLs respond successfully.

## Before App Store submission

- Apple Developer membership, signing team, final bundle identifier and App Store Connect app record.
- App names, subtitle, description, keywords, screenshots for en-US, zh-Hans and zh-Hant; storefront availability set to United States. App UI language and store listing language are separate settings.
- Confirm current age rating and health/fitness disclosures; the app does not provide medical diagnosis/treatment.
- Complete privacy answers using `STORE_DATA_SAFETY.md`, considering optional AI/provider retention.
- Review the full English exercise guidance and Traditional Chinese terminology on real devices. Catalog drafts are a starting point; critical labels, privacy and consent wording have curated English overrides in `tool/l10n/reviewed_en.json`.
- Real iPhone acceptance: camera, photo picker, document export/import, locked-screen reminders, cold start, language persistence, large text and offline behavior. Simulator checks do not establish real-device camera or notification delivery.
- Signed archive and TestFlight acceptance, then submit for review. An unsigned local build is not a store submission.

## Maintaining translations

`dart run tool/l10n/extract.dart` produces the legacy source inventory. `tool/l10n/translate_local.py` is an optional offline draft generator with explicit local-model prerequisites; it is not needed to build the app. `tool/l10n/apply_reviewed.py` merges curated corrections into packaged catalogs. Keep placeholders `{p0}`, `{p1}` unchanged; test/localization_test.dart verifies catalog coverage and placeholders.

Never mass-replace saved Chinese values or JSON schema keys. Review language changes alongside small-screen layout and accessibility labels. Legal Markdown and website copy are explicit language versions, not runtime machine translations.
