# Vibesight Tracker — Flutter port

Native Flutter rewrite of the existing React + Vite + Capacitor app. See
[../MIGRATION_PLAN.md](../MIGRATION_PLAN.md) for the full migration roadmap.

## Quick start

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

The built APK lands at `build/app/outputs/flutter-apk/app-release.apk` and is
signed with the bundled Flutter debug keystore (good enough for sideloading
and CI dogfooding; production will swap to a managed release key in Phase 10
of the plan).

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
