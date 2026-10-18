# Store privacy declarations

Last reviewed: 2026-10-17. Applies to iOS and Android.

Do not automatically select **Data Not Collected**. Local-only core records and optional third-party AI requests have different behavior.

| Flow | Data / destination | Trigger | Retention |
| --- | --- | --- | --- |
| Core journal | Profile, measurements, workouts, food records and photos on device | User entry | Until edited, deleted or app data removed |
| AI recognition | Selected photos, meal name, up to 300 characters of note, nutrition prompt, API authentication, ordinary network metadata to user-configured HTTPS endpoint | Separate endpoint/protocol-bound consent, then manual recognition | Provider-controlled; unknown until its policy is verified |
| Android update check | Release request to GitHub; no records/advertising ID | Optional automatic check or manual check | GitHub policy applies |
| Public links | Browser request to GitHub/GitHub Pages | User opens link | Hosting policy applies |
| Export | Records/photos to user-selected file destination | Explicit export | User/target storage controlled |

No app accounts, ads, tracking SDKs, analytics or crash-reporting SDKs. No HealthKit integration. Camera and system photo picker only; local notifications. No automatic cloud sync. Local database/photos excluded from automatic system backup. API keys and AI consent excluded from exported backups.

## App Store Connect

Public policy: https://hunter-ght.github.io/LeanDaily/privacy/ (must return HTTP 200 before submission).
Support: https://hunter-ght.github.io/LeanDaily/support/ . Both pages have English, Simplified Chinese and Traditional Chinese versions.

Audit optional AI handling under Apple's current collection definition. Photos/videos, other user content and health/fitness are the categories to review against the exact inputs and provider retention. Do not assume unlinked data merely because LeanDaily has no account: an API provider may associate requests with its user's account. Tracking is not implemented in this app. Confirm the final privacy answers against supported providers before submission. The on-device privacy manifest is not a substitute for the App Store Connect questionnaire.

If a provider demonstrably discards a request after real-time processing, Apple's collection definition can differ from a retained request. A configurable endpoint does not establish that guarantee. The static app source cannot certify arbitrary provider behavior.

## Google Play

If publishing on Play, complete the current Data safety form for the same actual flows, including optional data sharing/collection and provider retention. Recheck the policy when adding any SDK, account, backend, analytics or fixed AI provider.

Primary requirements: [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/), [App privacy details](https://developer.apple.com/app-store/app-privacy-details/).

## OpenAI example added on 2026-10-17

The optional example fills https://api.openai.com/v1, gpt-6-luna and Responses as a draft. It contains no key and does not activate, consent or send. Official OpenAI requests explicitly use store=false in both supported protocols. This does not remove abuse-monitoring retention or legal/safety exceptions, and no live API acceptance was performed without an owner-provided test account. Disclosure revision 2 invalidates previous grants. Exact HTTPS host/path validation prevents custom proxies from being identified as OpenAI.

The app privacy manifest now declares the optional AI photo, text, meal nutrition, provider account linkage and ordinary network metadata flows conservatively as linked, for app functionality and not tracking. It no longer states an unconditional empty collected-data list. App Store Connect answers still need owner acceptance and provider-account verification; see [Chinese submission walkthrough](APP_STORE_NEXT_STEPS.md). Ordinary local-only body profiles/workouts are not part of recognition requests.

## Support contact added — 2026-10-18

Publisher/operator confirmed as Skylance LLC. Support and privacy email: 2436759690@qq.com. Voluntary support emails include the sender address and any information the sender provides; they are used to respond and resolve requests. Review Email Address and Other User Content against Apple’s optional-disclosure criteria for infrequent, optional support flows before submitting the questionnaire; this is not an automatic Data Not Collected exemption. Do not ask users to send API keys, full backups or unnecessary health information.

## Google Gemini example — 2026-10-18

- Compatible base: https://generativelanguage.googleapis.com/v1beta/openai/ ; protocol: Chat Completions; model: gemini-3.5-flash-lite. Model accepts image input; free quota is conditional, not an unlimited service promise.
- Exact host/path identification and destination-bound consent are shared with OpenAI. Disclosure revision 3 invalidates older grants. Switching examples changes only the draft, requires confirmation for a different destination and clears the draft key; it never sends or grants consent.
- Google unpaid-service terms can allow product/model improvement and human review; paid-service and certain regional rules differ. Do not claim Google’s free service has OpenAI’s default no-training behavior, or that store=false disables Google processing. No unsupported store flag is sent to Gemini.
- The manifest conservatively adds Other Purposes for AI photos, other user content and health/nutrition because Google’s unpaid terms permit model/product improvement. The questionnaire must be revisited before submission; the earlier functionality-only table must not be copied unchanged. Provider authentication/network declarations remain functionality purposes; no advertising/tracking has been added.
- Google terms prohibit sensitive/confidential/personal inputs to unpaid services and require adult use, including restrictions on API clients likely accessed by under-18s. The UI warns before consent; the backend refuses official Gemini when profile age is missing/under 18, before photo reading or HTTP. This local age gate does not certify that the overall app meets Google’s API-client eligibility; the publisher must assess this against the app’s existing youth route before production distribution. Manual logging stays available.
- No real Google key was supplied or used. Fake HTTP tests verify request shape, image payload, consent blocking and age blocking; account/region/quota and live recognition quality remain unverified.

Sources: https://ai.google.dev/gemini-api/docs/openai , https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite , https://ai.google.dev/gemini-api/docs/pricing , https://ai.google.dev/gemini-api/terms .
