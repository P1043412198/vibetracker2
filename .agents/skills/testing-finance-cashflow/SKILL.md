---
name: testing-finance-cashflow
description: Test the Vibesight finance "safe-to-spend" cashflow forecast (SafeToSpendCard) end-to-end in the React PWA. Use when verifying budget/cashflow forecast UI or calculations, the configurable reserve, or cash-gap detection.
---

# Testing the Safe-to-Spend Cashflow Forecast

End-to-end UI testing for the "Сколько можно тратить" (`SafeToSpendCard`) feature.

## Where things live
- React dev server: `http://localhost:3000` (Vite). Start with `npm run dev` from repo root.
- Engine: `src/lib/finance/budgetPlanner.ts` → `computeCashflowForecast`.
- UI card: `src/components/BudgetPlannerTab.tsx` (`SafeToSpendCard`).
- Reserve store field: `src/store/useStore.ts` → `safeToSpendReserve` / `setSafeToSpendReserve`.
- The card renders under **Финансы → Бюджет → Планирование → Факт** (the third sub-tab, NOT "План доходов"/"План расходов").

## System date matters
The forecast is date-relative. The reference scenario assumes **today = 2026-06-26**. If the
VM clock differs, the "days until advance" and headline number change. Confirm the frozen/system
date before asserting exact values; recompute expected numbers from the actual `today` if needed.

## Reference scenario + expected values (today = 26 Jun)
Setup via UI:
- Финансы → **Счета**: add account, balance **360 BYN**.
- Планирование → **План доходов**: add «Аванс» type Аванс, day **30**, **+500**; «Зарплата» type Зарплата, day **15**, **+1200**.

Expected on the Факт card:
- Headline **90 BYN/день** (360 / 4 days to advance). Sub-line names «Аванс», через 4 дня, 30 июн., +500.
- "Сейчас на счетах" = **360 BYN**. No cash-gap warning.
- Set reserve **100** → headline **65 BYN/день** ((360−100)/4).
- Reset reserve to 0; add unpaid planned expense **600 BYN** due day **27** in План расходов → return to Факт → red «**Кассовый разрыв**» warning + headline **0 BYN/день**.

## Tips / gotchas
- After editing the reserve input, press Enter (blur) for the headline to recompute.
- The card needs the **Факт** sub-tab; the other two sub-tabs (План доходов / План расходов) do not show it.
- Adding/paying planned expenses is done on **План расходов**; the "Добавить плановый расход" form takes name, amount, and a day-range (set both from/to to the same day, e.g. 27→27).
- Known cosmetic issue (may or may not be fixed): the План доходов list labels income day-of-month
  using the *current* month (e.g. "15-е → 15 июн." even when next salary is 15 Jul). This is a
  display label only and does NOT affect forecast math — verify the forecast segments/headline
  rather than trusting the list label.
- For the Flutter port, the equivalent engine is `flutter_app/lib/services/budget_planner_calc.dart`
  and state `flutter_app/lib/state/settings_state.dart` (`safeToSpendReserveProvider`).

## Recording & evidence
- Maximize the browser first (`wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz`).
- Annotate with `annotate_recording`: one `setup` (account+income entered), then a `test_start`
  + consolidated `assertion` per test (headline, reserve, cash-gap).
- Convert the recording to animated webp before embedding in a PR comment (mp4 is rejected):
  `ffmpeg -y -i edited.mp4 -vf "fps=10,scale=900:-1:flags=lanczos" -loop 0 -q:v 55 out.webp`
- Post ONE consolidated PR comment with `<details>` sections and a `test-report.md` attachment.

## Devin Secrets Needed
None — runs fully locally against the bundled dev server (no external API keys required for this flow).
