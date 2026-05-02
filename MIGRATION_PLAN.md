# Vibesight Tracker — Flutter migration plan

This document tracks the rewrite of the React + Vite + Capacitor Vibesight
Tracker into a native Flutter (Android/iOS) application. The first pass lives
under [`flutter_app/`](./flutter_app) and ships a working APK with the
foundational architecture and 7 functional screens. The remaining 9 pages are
placeholders that link back to this plan.

## Why a phased rewrite

The React app is large (~16 500 lines across 16 pages, 38 components, 13
custom charts, 20 dashboard widgets) and depends on a number of web-only
libraries (`@nivo/sankey`, `@uiw/react-md-editor`, `tesseract.js`,
`@mediapipe/pose`, `react-grid-layout`, `better-sqlite3`, `html5-qrcode`,
`otpauth`, `@google/genai`, `openai`, `framer-motion`). Most have direct
Flutter equivalents but the UI logic and many widget interactions need to be
re-implemented. A 1:1 port is best done feature by feature behind a shared
foundation rather than as a big-bang rewrite.

## Architecture decisions

| Concern | React (current) | Flutter (port) |
|---|---|---|
| Language / runtime | TypeScript 5.8 + Vite 6 + React 19 | Dart 3.6, Flutter stable 3.27 |
| Routing | `react-router-dom` v7 | `go_router` 14.x with `ShellRoute` |
| State | Zustand + `idb-keyval` persist | Riverpod 2.x + custom `JsonListController` over Hive |
| Persistence | IndexedDB / `better-sqlite3` (web), file system (Capacitor) | Hive (`Box<String>`) holding JSON-encoded collections, identical keys to the Zustand store |
| Theming | Tailwind v4 + custom CSS | Material 3 with `ColorScheme.fromSeed(0xFF6D5CFF)` |
| Localisation | Hardcoded RU strings | `flutter_localizations` (RU primary, BY/EN later) |
| Charts | `recharts`, `@nivo/sankey`, `@nivo/treemap` | `fl_chart` (line/bar/pie); Sankey/Treemap → custom `CustomPainter` |
| OCR | `tesseract.js` | `google_mlkit_text_recognition` |
| Pose | `@mediapipe/pose` | `google_mlkit_pose_detection` |
| QR | `html5-qrcode` | `mobile_scanner` |
| Markdown | `react-markdown` / `jodit-react` / `@uiw/react-md-editor` | `flutter_markdown` (view) + `flutter_quill` (rich edit) |
| TOTP | `otpauth` | `otp` (RFC 6238) |
| AI | `@google/genai`, `openai` | direct REST via `dio`/`http` (SDKs aren't Dart-native) |
| Drag & drop | `@dnd-kit`, `react-grid-layout` | Built-in `ReorderableListView`; grid layout custom |
| File hashing / animations | `framer-motion` | Built-in `AnimatedSwitcher`, `Hero`, `flutter_animate` if needed |

### Storage shape

The Hive keys mirror the React `useStore.ts` field names so a future
migration tool could ingest exported JSON from the React build:

```
spheres                  -> List<Sphere>
tasks                    -> List<TaskItem>
habits                   -> List<Habit>
habitLogs                -> List<HabitLog>
goals                    -> List<Goal>
transactions             -> List<Transaction>
accounts                 -> List<Account>
budgetLimits             -> List<BudgetLimit>
monthlyBudgetPlans       -> List<MonthlyBudgetPlan>
waterLogs                -> List<WaterLog>
inboxItems               -> List<InboxItem>
sleepLogs                -> List<SleepLog>
shoppingItems            -> List<ShoppingItem>
passwords                -> List<PasswordEntry>
workoutNodes             -> List<WorkoutNode>
themeMode                -> 'system' | 'light' | 'dark'
defaultCurrency          -> ISO-4217 string
```

Each list is JSON-encoded as a single string in a `Box<String>` so adding new
fields never requires Hive type-adapter regeneration. When/if the data model
stabilises, individual collections can be promoted to typed `Box<T>` with
`@HiveType` adapters for performance.

## Phase plan

Each phase targets a self-contained, shippable improvement. Phases are
expected to land as separate PRs and ideally separate release builds so the
user can dogfood incrementally.

### Phase 0 — Foundation (this PR ✅)

- Flutter project scaffold (`flutter_app/`).
- Material 3 theme (light/dark) with the violet accent from
  [`fe4046f feat(ui): premium nav + dashboard polish`](https://github.com/P1043412198/vibetracker2/commit/fe4046f).
- `go_router` with bottom-nav `ShellRoute` covering all 16 routes from
  [`src/App.tsx`](./src/App.tsx).
- Riverpod-based generic `JsonListController<T>` for any persisted entity.
- 30+ data models ported from [`src/types.ts`](./src/types.ts) (Sphere, Task,
  Habit, HabitLog, Goal, Transaction, Account, BudgetLimit, MonthlyBudgetPlan,
  WorkoutNode, PasswordEntry, ShoppingItem, SleepLog, WaterLog, InboxItem,
  …).
- Functional screens: **Dashboard, Spheres, Tasks, Habits, Finance,
  Shopping list, Goals, Settings**.
- Placeholders linking back to this plan: Workouts, Household, Work Schedule,
  Analytics, Passwords, Tools.
- Release APK that installs and runs (signed with the bundled debug key for
  developer distribution).

### Phase 1 — Finance core (highest priority)

The React app puts most of its value here. We need parity with
[`src/pages/Finance.tsx`](./src/pages/Finance.tsx) (2 714 lines).

- Tabs: "Транзакции", "Счета", "Графики", "Цели", "Кредиты",
  "Регулярные платежи", "Конверты".
- Multi-currency with the same converter logic from
  [`src/lib/finance/`](./src/lib/finance/).
- Monthly budget plan / fact comparison (port the Zustand
  [`monthlyBudgetSlice`](./src/store/slices/monthlyBudgetSlice.ts) — already
  modelled in `lib/models/finance.dart`).
- CSV import for Belarus banks (port [`BankCsvImportModal`](./src/components)
  parsing rules).
- AI assistant tab (`@google/genai` → REST via `dio`).

### Phase 2 — Habits & Tasks polish

- Per-day habit heatmap, streak chains, year-view —
  [`src/components/charts/HabitYearHeatmap.tsx`](./src/components/charts/HabitYearHeatmap.tsx),
  [`StreakChains.tsx`](./src/components/charts/StreakChains.tsx).
- Eisenhower-quadrant view for tasks, GTD contexts, subtasks reorder.
- Reminders & local notifications (`flutter_local_notifications`).

### Phase 3 — Goals + Spheres deep view

- Steps editor with reorder, status `todo|in_progress|done`.
- Book progress chart (port
  [`BookProgressChart.tsx`](./src/components/charts/BookProgressChart.tsx)).
- Sphere notes with checkbox/comments, image notes
  (port [`SphereDetails.tsx`](./src/pages/SphereDetails.tsx)).
- Goal/Sphere Gantt
  ([`GoalsGantt.tsx`](./src/components/charts/GoalsGantt.tsx)).

### Phase 4 — Workouts & body tracking

- Tree of folders/exercises (port
  [`Workouts.tsx`](./src/pages/Workouts.tsx) — 2 367 lines).
- Body measurements timeline.
- Planned vs completed workout heatmap.
- Pose tracking via `google_mlkit_pose_detection` (replaces
  `@mediapipe/pose`) — gated behind a permission flow.

### Phase 5 — Analytics & charts pack

- Custom `CustomPainter`-based Sankey
  (replaces [`SankeyFlow.tsx`](./src/components/charts/SankeyFlow.tsx)).
- Treemap of expenses
  ([`TreemapExpenses.tsx`](./src/components/charts/TreemapExpenses.tsx)).
- Currency donut, expenses calendar heatmap, net-worth chart, sphere radar,
  task velocity, task close heatmap.

### Phase 6 — Productivity micro-tools ✅

- ✅ Pomodoro timer with persisted state (port `PomodoroState` from
  [`types.ts`](./src/types.ts)): circular progress ring, work/break/long-break
  toggle, configurable durations, session counter.
- ✅ Inbox of thoughts (already done in an earlier pass).
- ✅ Sleep tracker: log hours + quality (1–5), 7-day area chart, readiness
  score, history list with delete.
- ✅ Water intake widget with cup/bottle visualization: custom `CustomPainter`
  vessel with animated wave fill, configurable daily goal and increment,
  today's log list.

### Phase 7 — Belarus localisation pack ✅

- ✅ Full "Tools" page with 8 tabs: Calculators, FinLit, Tax Calendar,
  What-If, FX Converter, Glossary, Mini-courses, Templates.
- ✅ 10 financial calculators ported from React:
  - Compound interest, Deposit BY (with 13% tax), Loan (annuity/differential),
    Salary deductions (gross→net with FSZN 1%, income tax 13%, standard/child
    deductions), IP USN (5%/3%), NPD (self-employed 10%/20%), Safety fund,
    FX stress test, Vacation pay, FIRE.
- ✅ Belarus tax calculation library (`lib/finance/by_tax.dart`) and generic
  financial calculators (`lib/finance/calculators.dart`).
- ✅ BY-2026 financial-literacy module: 9 categories, 55+ tips with kind
  badges (tip/warning/rule/fact), tag chips, color accents.
- ✅ Tax calendar for 2026: 15 events, filterable by audience
  (all/individuals/employed/IP), monthly grouping.
- ✅ What-If scenario simulator: 6 interactive sliders, real-time FIRE/safety
  fund/savings projections.
- ✅ FX converter: multi-currency BYN/USD/EUR/RUB/PLN with swap and rate table.
- ✅ Glossary: 30+ financial terms in 5 groups (personal/belarus/invest/tax/credit).
- ✅ Mini-courses: 5 step-by-step courses with progress tracking.
- ✅ Templates: habit and goal templates for financial literacy.

### Phase 8 — Passwords & TOTP ✅

- ✅ Full password manager with search, category filtering, pin/unpin,
  add/edit/delete entries.
- ✅ Password generator with 4 paranoia levels (8–32 chars, configurable
  character sets) using `Random.secure()`.
- ✅ TOTP authenticator: RFC 6238 implementation using `package:crypto`
  HMAC-SHA1, base32 decoding, 30-second rotation with live countdown
  progress bar. Supports raw secrets and `otpauth://` URIs.
- ✅ Clipboard integration (copy password, copy TOTP code).
- ✅ Notes and URL fields per entry.
- ✅ Persistent storage via Hive (same JsonListController pattern).
- ⏳ AES encryption layer and biometric unlock deferred to Phase 10 polish.

### Phase 9 — Household / Shopping / Work schedule

- Port [`Household.tsx`](./src/pages/Household.tsx),
  [`ShoppingList.tsx`](./src/pages/ShoppingList.tsx) (full version with
  categories, hashtags, photos, price history),
  [`WorkSchedule.tsx`](./src/pages/WorkSchedule.tsx) (cyclic shift schedule).

### Phase 10 — Cross-cutting polish

- Dashboard widget reorder/visibility settings (port
  [`DashboardConfig`](./src/types.ts)).
- PIN-lock screen
  ([`PinLockScreen.tsx`](./src/components/PinLockScreen.tsx)).
- Share-target intent handling
  ([`ShareTarget.tsx`](./src/pages/ShareTarget.tsx)) via Android intent
  filter + `receive_sharing_intent` package.
- Light/dark theme switch parity with the React redesign.
- Localizations: BY (Belarusian) and EN.
- Release-keystore signing config with documentation.

## Status legend

- ✅ Done in this PR
- 🚧 In progress
- ⏳ Planned

| Phase | Status | Owner | Notes |
|---|---|---|---|
| 0 — Foundation | ✅ | Devin | This PR |
| 1 — Finance core | ⏳ | next session | depends on Phase 0 |
| 2 — Habits & Tasks polish | ⏳ | | |
| 3 — Goals + Spheres deep | ⏳ | | |
| 4 — Workouts & body | ⏳ | | needs camera permission flow |
| 5 — Analytics & charts | ⏳ | | mostly custom painters |
| 6 — Productivity tools | ✅ | Devin | Pomodoro, Sleep, Water, Inbox |
| 7 — Belarus localisation | ✅ | Devin | 8 tabs, 10 calculators, FinLit, calendar, glossary, courses |
| 8 — Passwords & TOTP | ✅ | Devin | Password vault, TOTP authenticator, generator |
| 9 — Household etc. | ⏳ | | |
| 10 — Polish | ⏳ | | |

## Build & run (Phase 0)

```bash
cd flutter_app
flutter pub get
flutter build apk --release          # → build/app/outputs/flutter-apk/app-release.apk
flutter run                          # on a connected device/emulator
```

The first APK is signed with the bundled Flutter debug keystore so the user
can sideload it for dogfooding. A proper release keystore will land in
Phase 10.
