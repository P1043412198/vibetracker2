# Test Plan — Safe-to-Spend Cashflow Forecast (PR #19)

App: Vibesight Tracker React PWA, dev server `http://localhost:3000`.
System date = **2026-06-26** (matches user's scenario "сегодня 26 июня").

## Feature under test
New `SafeToSpendCard` ("Сколько можно тратить") in Finance → Бюджет → Планирование → **Факт** tab.
Computed by `computeCashflowForecast` (`src/lib/finance/budgetPlanner.ts`), rendered in
`src/components/BudgetPlannerTab.tsx:538-679`, fed real account balance + income sources + reserve.

## Setup state (entered via UI before assertions)
- Finance → **Счета**: add account, balance **360 BYN**.
- Finance → **Планирование → План доходов**: add
  - "Аванс", type Аванс, **30** day-of-month, **+500**
  - "Зарплата", type Зарплата, **15** day-of-month, **+1200**

## Test 1 — Headline daily limit (the core claim)
**Steps:** Open Финансы → Бюджет → Планирование → Факт. Read the indigo "Сколько можно тратить" card.
**Pass criteria (exact values):**
- Headline = **90 BYN/день** (360 / 4 days to advance). NOT a different number, NOT "0".
- Sub-line names next income: **«Аванс»**, **через 4 дня**, dated **30 июн**, **+500 BYN**.
- "Сейчас на счетах" = **360 BYN**.
- No cash-gap warning shown (balance covers everything).
**Why adversarial:** A broken accumulator/segment calc would show 0, the salary (15 июл) as next income, or a wrong per-day figure. 90 ≠ any naive total (e.g. 360+500+1200 anything).

## Test 2 — Reserve lowers the limit (user-configurable reserve)
**Steps:** In the card's "Несгораемый резерв" field, clear it, type **100**, press Enter (blur).
**Pass criteria:**
- Headline updates to **65 BYN/день** ((360 − 100) / 4). Must change from 90 → 65.
- Still no cash-gap warning.
**Why adversarial:** If reserve weren't wired into the forecast, the number would stay 90. 65 proves reserve is subtracted before dividing.

## Test 3 (edge) — Cash-gap flag
**Steps:** Reset reserve to 0. Go to План расходов, add an unpaid planned expense **600 BYN** due **27** (before the advance).
Return to Факт.
**Pass criteria:**
- Red "Кассовый разрыв" warning appears.
- First segment daily limit shows **0 BYN/день** (cannot cover 600 from 360).
**Why adversarial:** A broken obligation/shortfall path would leave the warning hidden and still show a positive limit.

## Notes
- Verify reserve persistence is out of scope for the recording (covered by unit tests); focus on the 3 visible flows above.
