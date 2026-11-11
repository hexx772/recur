<h1 align="center">Recur</h1>

<p align="center">
  A subscription tracker for Android with reminders, analytics, home screen widgets and a Material 3 look.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white">
  <img alt="Design" src="https://img.shields.io/badge/design-Material%203-6750A4">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
  <img alt="Status" src="https://img.shields.io/badge/status-beta-orange">
</p>

<p align="center">
  <b>English</b> · <a href="README.ru.md">Русский</a>
</p>

---

Recur keeps all your subscriptions in one place so a charge never catches you by surprise. Everything is stored on your device: no account, no server, no ads, no analytics.

> **Status: working beta.** The core app is built and tested on an emulator, but it has not been through a real-world round of testing yet. See [Project status](#project-status) for what is verified and what is not.

## Features

**Tracking**
- Add subscriptions by hand: name, price, currency, billing period (weekly, monthly, every 3 months, yearly), next charge date, category.
- A quick-pick list of popular services (video and music, AI, software and cloud, games) fills in the name and category for you.
- The charge date rolls forward on its own after it passes. Month ends are handled (31 Jan becomes 28 Feb).
- Categories include **AI** (ChatGPT, Claude, Gemini, Perplexity, Midjourney, GitHub Copilot, Cursor).

**Money**
- Monthly and yearly totals, kept separate per currency.
- Currency conversion into one main currency at current exchange rates: per subscription, or for all subscriptions at once in settings.
- **Shared plans:** split a family or group subscription; only your share is counted.
- **Free trials:** a trial is not counted in totals, and you get a reminder to cancel before the first payment.

**Reminders**
- Push notifications a chosen number of days before each charge, at a chosen time. The next three charges of every subscription are scheduled and restored after a reboot.
- The notification permission is requested on first launch.

**Analytics**
- Spending by category (animated donut chart) and the five most expensive subscriptions.
- Trial overview and the saving from shared plans.

**How to cancel**
- A one-tap link to the cancellation page of popular services, or a web search for the rest. You can set your own link per subscription.

**Home screen widgets (Android)**
- **List:** all subscriptions, fitted to the size you give the widget (no scrolling). What does not fit collapses into an "and N more" line.
- **Next:** the next charge at a glance.
- **Total:** monthly and yearly spending.
- Colors follow your wallpaper (Material You), light and dark.

**Backup**
- Export subscriptions **and settings** (currency, reminders, theme) to a JSON file and restore them after reinstalling. Export to CSV for spreadsheets.

**Languages**
- Russian and English, chosen from the system language. Ukrainian, Belarusian and Kazakh systems get Russian.

### Beta features

- **Find subscriptions in Gmail.** Reads receipts and charge notices (read-only access), analyses them on the device and offers candidates. You confirm each one. Needs your own Google OAuth client, see [Gmail setup](#gmail-setup).
- **Find subscriptions in bank SMS (Android).** Reads SMS from the last 180 days and looks for charges from a built-in list of known services. The billing period is guessed from the gap between charges.

Nothing is added without your confirmation, and no message leaves the device.

## Design

Recur follows Material 3 and borrows its Expressive ideas, which Flutter does not ship as ready-made components yet, so they are built here:

- **Dynamic color** from your wallpaper (Android 12+), or one of six palettes, with a light, dark and black AMOLED theme.
- **Shapes:** superellipse cards with generous radii, avatars that alternate between circle and rounded square, large collapsing app bars.
- **Typography:** bold, large numbers for money, small spaced capitals for section labels.
- **Motion:** spring press feedback on cards, staggered list entrance, count-up totals, an animated donut, and a shared-axis transition between tabs.
- **Adaptive icon** with a themed (monochrome) layer.

## Project status

This is an honest snapshot of the current state.

**Works and is checked**
- The app builds and runs on an Android emulator (API 37). The subscriptions, analytics and settings screens were checked by eye.
- Static analysis is clean and 18 unit tests pass: parsing of emails and SMS, shares and trials, cancellation links, backup with settings, English translations.
- Release APK builds (about 58 MB).

**Written but not verified on a real device**
- Home screen widgets. Their layout and the row-fitting logic were fixed after a bug, but they have not been seen on a phone or across different launchers, which report widget size differently.
- Notification delivery and timing (scheduling is inexact, so delivery can be a few minutes late).
- Theme switching, the latest widget design, and the English interface were only checked by analysis and tests, not visually.
- The English translation is unreviewed by a native speaker.
- Backup export and restore through the system file picker.
- Parsing of real bank SMS, which differ a lot between banks. Only a built-in list of services is recognised.

**Known limits**
- **Android only.** The iOS project exists but is not set up: no widgets, no SMS, no app icon.
- The release build is signed with the debug key. A real release key is needed before publishing.
- Gmail sign-in needs your own Google Cloud OAuth client. Google also requires app verification for the `gmail.readonly` scope before other people can use it.
- `READ_SMS` is a restricted permission on Google Play. A Play build should leave SMS out.
- The free exchange-rate service (`open.er-api.com`) asks for attribution; a credit line is not in the app yet.
- Data is kept in local preferences without extra encryption. There is no cloud sync between devices.
- Automatic sync with services is **not possible directly**: most services have no public API for subscriptions. Gmail and SMS parsing are workarounds.

**Ideas**
- Bank sync through an open-banking aggregator (depends on the region).
- Release signing, a Play build flavor without SMS, screenshots, CI.
- iOS support and widgets.

## Getting started

You need [Flutter](https://docs.flutter.dev/get-started/install) (3.47 or newer) and the Android SDK.

```bash
flutter pub get
flutter test
flutter run
```

Build an APK:

```bash
flutter build apk --release
```

### Gmail setup

1. In the [Google Cloud Console](https://console.cloud.google.com/) create a project and enable the **Gmail API**.
2. Configure the OAuth consent screen, add the scope `https://www.googleapis.com/auth/gmail.readonly` and your account as a test user.
3. Create an OAuth client for Android with the package name `com.appsub.appsub` and the SHA-1 of your signing key.

Without it the Gmail button shows a sign-in error. The rest of the app works.

## Project structure

```
lib/
  main.dart              app start, theme, locale
  data/                  settings, subscription store, known services
  models/                the Subscription model and billing periods
  services/              Gmail, SMS, exchange rates, notifications, backup, widget sync
  screens/               home, edit, analytics, settings, beta screens
  theme/                 Material 3 theme, palettes
  widgets/               spring press and entrance animations
  l10n/                  Russian-to-English dictionary
android/app/src/main/    widget providers (Kotlin), layouts, icons, strings
test/                    unit tests
store/                   privacy policy and Google Play listing texts
```

Built with Flutter, `shared_preferences`, `dynamic_color`, `home_widget`, `flutter_local_notifications`, `google_sign_in`, `animations`, `share_plus`, `file_picker`.

## Privacy

Subscriptions and settings stay on the device. The only network request that does not go to Google is the download of public exchange rates, and it carries no personal data. The full text is in [store/privacy-policy.md](store/privacy-policy.md).

## License

[MIT](LICENSE)

Service names used as examples (Netflix, Spotify and others) are trademarks of their owners. Recur is not affiliated with them.
