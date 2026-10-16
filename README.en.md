<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/wordmark-dark.png">
  <img src="docs/images/wordmark.png" alt="LeanDaily" width="420">
</picture>

**A lean-physique training plan built around your body — and an app that coaches you up, week by week.**

Free · Open source · No ads · No account · Your data stays on your phone

[![License: MIT](https://img.shields.io/badge/License-MIT-ff6a13.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Android-8.0%2B-3ddc84?logo=android&logoColor=white)](#install)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-1100%2B%20passing-30d158)](#development)
[![No ads](https://img.shields.io/badge/ads-none-ff6a13)](PRIVACY.en.md)

[简体中文](README.md) · [English](README.en.md)

<img src="docs/images/hero.png" alt="LeanDaily screenshots" width="100%">

</div>

---

> The app UI is currently **Simplified Chinese only**. English UI is on the roadmap.

## What is it

**LeanDaily (薄肌日课)** is a workout + nutrition log for people who want a *lean* physique: low body fat with well-defined, proportionate muscle — not maximum size.

Everyone starts from a different place. Some need to cut first, some are lean and need to eat and build, some already train and want to refine shoulders, back and abs. So instead of handing you one fixed plan, LeanDaily:

> **asks a few questions → works out your route, daily calories and protein → recommends a plan that fits → keeps adjusting your targets from your own performance.**

It is a fully offline app: no account, no ads, no analytics, no server.

## Highlights

**Today, at a glance.** Open the app and see what to train today, how many sets, what's next, and one big button. Every exercise has a looping demo that plays right inside the workout screen.

<div align="center">
<img src="docs/images/flow.gif" alt="Today → workout → summary" height="420">
&nbsp;&nbsp;&nbsp;
<img src="docs/images/demo-floor-press.gif" alt="Exercise demo" height="420">
</div>

**Choosing a plan without a wall of text.** Each plan is a "fingerprint card": a 7-day strip showing which days you train and what (push / pull / legs / full / upper / lower), a mini body map shaded by the plan's real weekly volume per muscle, a one-line summary and a "who it's for" meter. Onboarding asks days per week, where you train (home without / with dumbbells, gym, or both) and experience, then shows **one recommended card** plus swipeable alternatives.

<img src="docs/images/feature-plan.png" alt="Plan picker" width="100%">

**Progress you can see.** A muscle map coloured by *recovery*, *volume* or *neglect*; a 7-day-average weight trend with estimated body-fat progress; a weekly review that suggests next week's adjustment (e.g. ±100 kcal) you can apply in one tap.

<img src="docs/images/feature-progress.png" alt="Progress" width="100%">

**A workout mode built for the gym.** One exercise at a time, one tap per set (numbers carry over), automatic rest timer, optional "reps left / any discomfort" feedback that never blocks the next set and can be added later, swipe between exercises, a summary at the end.

<img src="docs/images/feature-training.png" alt="Workout mode" width="100%">

**Rule-based progression, no black box.** All rules are deterministic, explained and tested — see [docs/PROGRESSION.md](docs/PROGRESSION.md). Double progression within a rep range; faster for beginners, stricter for advanced lifters; equipment-aware load steps; pain/form flags freeze progression; return-from-break regression; a *suggest-only* deload; special protection for under-18s and for cutting phases. A 26-week simulation test suite guards against absurd recommendations.

**Nutrition, kept simple.** Daily calorie + protein targets (Mifflin-St Jeor with safety floors), ~300 built-in foods, one-tap favourites, optional photo recognition through *your own* OpenAI-compatible endpoint (never contacted unless you configure it).

**Dark mode, foldables, accessibility.** Rail navigation and two-pane layouts on wide screens, reduced-motion support, interruptible animations.

<img src="docs/images/feature-dark.png" alt="Dark mode" width="100%">

## Privacy

No account. No ads, analytics or crash reporting. Everything is stored locally; Android cloud backup is disabled. The only two network uses are the photo-recognition endpoint **you** configure and the update check (can be turned off). Full text: [PRIVACY.en.md](PRIVACY.en.md).

## Install

Android 8.0+ (64-bit ARM). Download the latest APK from [Releases](../../releases) and allow installation from unknown sources.

## Development

Requires Flutter 3.47+ (Dart 3.13+), JDK 17+, Android SDK and NDK.

```bash
git clone https://github.com/Hunter-Ght/LeanDaily.git
cd LeanDaily
flutter pub get
flutter run

flutter analyze
bash tool/lint_tokens.sh      # no hard-coded colours / Material look-alike widgets in UI code
TZ=Asia/Shanghai flutter test # tests assume a fixed time zone
```

Release build with your own signing key:

```bash
export LEANDAILY_STORE_FILE=/path/to/your.jks
export LEANDAILY_SIGNING_PASSWORD=...
export LEANDAILY_KEY_ALIAS=leandaily
flutter build apk --release --target-platform android-arm64
python3 tool/check_apk.py build/app/outputs/flutter-apk/app-release.apk
```

Keep R8 minification **off** (`isMinifyEnabled = false`): the Flutter engine calls back into `FlutterJNI` by class name.

[`lib/config/app_links.dart`](lib/config/app_links.dart) is configured for [Hunter-Ght/LeanDaily](https://github.com/Hunter-Ght/LeanDaily), the GitHub latest-release API, and the [online privacy policy](https://github.com/Hunter-Ght/LeanDaily/blob/main/PRIVACY.md). Contact: [Issues](https://github.com/Hunter-Ght/LeanDaily/issues).

Pushing `PRIVACY.md` to `main` makes it readable on GitHub without GitHub Pages. APKs must be built, signed, and uploaded to [Releases](https://github.com/Hunter-Ght/LeanDaily/releases) separately; a normal `git push` does not create them. See [the release checklist](docs/RELEASING.md).

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/DESIGN.md](docs/DESIGN.md).

## Roadmap

- [ ] Bodyweight progression ladders (squat / row / bridge / crunch)
- [ ] "Graduate to the next plan" suggestions
- [ ] Estimated 1RM as a unified strength metric
- [ ] English UI and more languages
- [ ] iOS

Issues and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

Exercise demo images: [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (Unlicense). Wordmark: a 4-character subset of [Smiley Sans](https://github.com/atelier-anchor/smiley-sans) (SIL OFL 1.1). Built with [Flutter](https://flutter.dev). Details in [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md).

## Disclaimer

Calorie and protein targets, body-fat estimates and training suggestions are general guidance computed from what you enter. **They are not medical advice.** Consult a doctor if you have pain, a medical condition, are pregnant or recovering. Nutrition values for built-in foods are estimates.

## License

[MIT](LICENSE) © 2026 Hunter-Ght
