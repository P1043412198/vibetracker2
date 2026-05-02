# Vibesight Tracker — Flutter port

Native Flutter rewrite of the existing React + Vite + Capacitor app. See
[../MIGRATION_PLAN.md](../MIGRATION_PLAN.md) for the full migration roadmap.

## Quick start

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

The built APK lands at `build/app/outputs/flutter-apk/app-release.apk`.
By default it is signed with the bundled Flutter debug keystore — good
enough for sideloading and dogfooding.

### Release signing (Phase 10)

To sign with a real upload key:

1. Generate a keystore once:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks \
           -keyalg RSA -keysize 2048 -validity 10000 \
           -alias upload
   ```
2. Copy `android/key.properties.example` to `android/key.properties` and fill
   in `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
3. Re-run `flutter build apk --release`. `android/app/build.gradle`
   auto-detects `android/key.properties` and switches `signingConfigs.release`
   to the upload key. Without that file, builds fall back to the debug key.

`android/key.properties` and `*.jks` are git-ignored — never commit them.

### Localisation

Strings are stored in `lib/l10n/app_<locale>.arb`. The base locale is `ru`
(`app_ru.arb`); `be` (Belarusian) and `en` (English) are translated mirrors.
After editing any ARB file run `flutter gen-l10n` to regenerate
`lib/l10n/app_localizations*.dart`. The user picks a language in
**Настройки → Язык**; "Системный" follows the device locale.

### Share-target

The Android manifest registers an `ACTION_SEND` / `text/plain` intent filter
so other apps can share text/URLs into Vibesight. The text is forwarded
through `MethodChannel("ai.vibesight.tracker/share")` (see
`android/.../MainActivity.kt` and `lib/services/share_intent_service.dart`)
and stored as a note in the "Заметки" sphere.

### PIN lock

Optional 4-digit PIN protects the app from casual access (set via
**Настройки → Безопасность**). The PIN is stored in Hive in plaintext —
this is a privacy gate, **not** a cryptographic vault. The lock auto-engages
whenever the app leaves the foreground (`AppLifecycleState.paused`).

## Structure

```
lib/
├── main.dart                # bootstrap: init Hive + Riverpod
├── app.dart                 # MaterialApp.router with theme & locale
├── theme/                   # Material 3 light/dark themes
├── router/                  # go_router config (16 routes)
├── services/storage.dart    # Hive Box<String> JSON store
├── state/                   # Riverpod controllers
│   ├── json_list_controller.dart   # generic CRUD-over-JSON-list
│   ├── providers.dart              # one StateNotifierProvider per entity
│   └── settings_state.dart         # theme mode, default currency
├── models/                  # 30+ data models ported from src/types.ts
├── widgets/                 # AppShell (bottom nav) + ComingSoon page
└── features/                # one folder per route
    ├── dashboard/
    ├── spheres/
    ├── tasks/
    ├── habits/
    ├── finance/
    ├── shopping_list/
    ├── goals/
    ├── settings/
    └── …                    # workouts/household/work_schedule/analytics/passwords/tools (placeholders)
```

## Why one shared `Box<String>`

The React app's `useStore.ts` keeps everything in a Zustand store persisted as
a single JSON blob into IndexedDB via `idb-keyval`. We mirror that with a
single Hive `Box<String>` so the data shape is recognisable: each "slice"
(`spheres`, `tasks`, …) is one JSON-encoded list under a key matching the
React store. This sidesteps the need for `build_runner` + Hive type adapters
during the early port and keeps the migration story trivial.

When a feature stabilises (or its persistence becomes a bottleneck), promote
its slice to a typed `Box<MyModel>` with a generated adapter — the
`JsonListController` interface stays the same.
