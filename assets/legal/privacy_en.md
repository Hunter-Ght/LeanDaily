# Privacy Policy

Effective: October 17, 2026

LeanDaily is a free, open-source training and food journal. No account is required. We do not operate a server for your health records, and the app contains no ads, analytics or tracking SDKs.

## 1. Data on your device

Your profile (including age, sex, height and body measurements), training plans, workout logs, meal records, photos, goals and settings are stored locally. Local records and photos are excluded from automatic Android/iCloud backup. There is no automatic cloud sync. API keys are stored using Android Keystore encryption or a device-only iOS Keychain entry and are excluded from exported backups.

## 2. Optional AI photo recognition

Recognition is off until you configure your own HTTPS endpoint, model and API key. Before the first request to that endpoint and protocol, the app shows the destination and asks for permission. Only after you agree and tap recognition does it send your selected meal photos, meal name, note (up to 300 characters) and a nutrition estimation prompt. Your profile, body measurements and workout history are not included. The API key authenticates the request to that provider.

Your chosen AI provider receives this data and standard network information such as your IP address. It may retain or use the data under its own terms, privacy policy and billing rules. We do not control that provider or promise deletion from its systems. Review its policy before agreeing; avoid photos or notes containing sensitive personal information. A changed endpoint or protocol requires new permission. You can revoke permission in Backup & advanced. Revoking prevents future requests; it does not delete information already received by the provider. Recognition is optional: you can record meals manually.

### OpenAI example and provider identification

The optional OpenAI example uses https://api.openai.com/v1, gpt-4.1-mini and the Responses protocol. It does not include a key or enable recognition. You need your own eligible API account, key and API billing; a ChatGPT subscription does not include API usage. Model access and service availability depend on your provider account and region. LeanDaily is independent and is not endorsed by OpenAI.

Only the exact HTTPS api.openai.com /v1 endpoint is identified as OpenAI in the app. Other endpoints are custom services, even if their model names include OpenAI or GPT. Verify their privacy, retention, training, deletion and billing terms before sending data.

For the official OpenAI endpoint, the app sets store=false for Responses and Chat Completions requests. This disables response storage for later retrieval; it is not Zero Data Retention. OpenAI states API data is not used for model training by default unless you opt in. Abuse monitoring logs may contain inputs and outputs and are normally retained for up to 30 days, with legal and safety exceptions; flagged image content may be retained for safety review. Account-specific controls may differ. Read the current data controls: https://developers.openai.com/api/docs/guides/your-data . Delete requests and account settings must be handled with OpenAI; revoking app consent cannot erase provider-held copies. Do not upload children's photos, faces, medical documents or other sensitive information. We cannot certify the practices of arbitrary custom providers.

## 3. Other network activity

On Android, optional update checks request release information from GitHub. No health records, advertising identifiers or usage events are included. GitHub receives ordinary network information such as IP addresses under its own policy. You can disable automatic checks in Me. iOS uses its installation channel for updates unless a separate update service is configured. Opening public privacy, support or project links uses your browser and the hosting site's policies. Exercise demonstration images ship with the app and are available offline.

## 4. Permissions

Camera access is used only when you choose to take a meal photo. The system photo picker reads only images you select; the app does not request access to your full library on iOS. Notifications are local reminders for training and rest timers. Android alarm and reboot permissions restore scheduled reminders. The app does not request location, contacts or microphone access. You can manage permissions in your device settings.

## 5. Export, deletion and retention

You control local records and can edit or export them in the app. Exported files include health records and photos, so keep them private. If you choose a cloud drive or share an export, that destination handles the file under its own rules. Restoring a backup does not restore AI consent or API keys. Deleting the app (not iOS offloading) or clearing app storage deletes local records; separately saved exports remain until you delete them. Provider-held AI data must be handled directly with that provider. Because we do not hold your local records, we cannot recover them after deletion.

## 6. Health information and age

Calorie estimates, nutrition targets, body-fat estimates and training suggestions are general fitness information, not medical advice, diagnosis or treatment. Consult a qualified professional for medical concerns. AI estimates may be wrong; check them before saving. The app is designed for adults. When an under-18 age is entered, it uses a growth-focused route without weight-loss deficits. This is not a service directed to children under 13. Do not submit children's photos or personal information to an AI service.

## 7. Changes and contact

Changes are published with an updated effective date in the app and on this page. A materially changed AI disclosure requires renewed consent. Questions and support: https://github.com/Hunter-Ght/LeanDaily/issues . Issues are public: do not post health records, photos, API keys or backup files there.
