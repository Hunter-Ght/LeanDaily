# Privacy Policy

[简体中文](PRIVACY.md) · [English](PRIVACY.en.md)

Effective date: 16 October 2026

LeanDaily (薄肌日课) is a free, open-source, ad-free workout and nutrition log. Our principle is simple: **your data belongs to you and stays on your own phone.**

## In one sentence

- No account, no sign-in.
- We do not collect or upload any personal information.
- No ads, no analytics, no crash reporting, no third-party trackers.
- The app goes online in only two situations, both under your control (see "Network requests").

## 1. What is stored, and where

All of the following is stored **only in your phone's local storage**:

- The profile you enter: sex, age, height, weight, body fat, waist, etc.;
- Training plans, workout logs, reps / weights / feelings for each set;
- Meal logs and the meal photos you take;
- Body-weight and waist entries, daily targets and settings.

None of it is uploaded to us — we have no server. Android's automatic cloud backup is turned off for the app (`allowBackup=false`), so the system does not copy it to the cloud either. Uninstalling the app or clearing its data deletes it.

If you configure an API key for photo recognition, it is encrypted with the Android Keystore and kept on the device; it is never included in backup files.

## 2. Network requests

The app goes online only in these two cases, always over HTTPS:

**① Photo recognition (optional, off by default).** Only if you enter a model provider's endpoint, model and API key under "Me → Backup & Advanced" **and** tap "Recognize" while logging a meal, the app sends **that one meal photo** and a prompt to **the provider you entered**. That provider's own privacy policy applies; we never see or handle the data.

**② Update check.** When the app starts (at most once a day) or when you tap "Check for updates", it makes one ordinary web request to the release page to read the latest version number. The request **carries no personal information, device identifier or usage data**. You can turn off "Check for updates at launch" under "Me → About".

The app sends nothing anywhere else.

## 3. Permissions and what they are for

| Permission | Purpose |
| --- | --- |
| Network | Only the photo recognition and update check described above |
| Notifications | Daily workout reminders and rest-timer alerts |
| Exact alarms / boot completed | Reminders on time, and restored after a reboot |
| Camera | Taking meal photos (only when you tap to take one) |

The app requests no location, contacts, microphone, SMS or call permissions.

## 4. Backups and export

You can export a backup file under "Me → Backup & Advanced". It contains your workouts, meals, weight entries and photos, and **you are responsible for keeping it safe**. Importing only reads the file you choose.

## 5. Health information

Calorie and protein targets, body-fat estimates, training suggestions and progression rules are **general guidance** computed by fixed rules from what you enter. They are not medical advice and do not replace a doctor, dietitian or qualified coach. If you feel unwell, have pain or a medical condition, are pregnant or recovering, consult a doctor first.

The app is designed for adults. Users under 18 are placed on a "growth" route with no calorie-deficit advice and no aggressive load increases; training under the guidance of a parent or coach is still recommended.

## 6. Third-party content

- Exercise demo images come from the open exercise database [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (Unlicense, public domain), bundled with the app and used offline.
- The app is built with Flutter; the wordmark uses the open-source font Smiley Sans (SIL OFL 1.1).
- The app contains no ad SDK, analytics SDK or third-party sign-in.

## 7. Your rights

Your data is entirely in your hands: view it in the app, export it as a backup, edit it, or delete it by uninstalling or clearing app data. Because we do not hold your data, there is nothing for us to delete on your behalf.

## 8. Changes

If this policy changes, the new version ships with an app update and is noted in the release notes. Continuing to use the updated app means you accept the new policy.

## 9. Contact

For questions or suggestions, please open an issue on the project page: `<project page URL — fill in before release>`.
