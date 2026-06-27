# Test Report — Safe-to-Spend Cashflow Forecast (PR #19)

**Method:** Ran the React PWA locally (`localhost:3000`, system date frozen to **2026-06-26**),
entered the user's exact scenario through the UI (account 360 BYN, advance +500 on 30 Jun,
salary +1200 on the 15th), and verified the new "Сколько можно тратить" (`SafeToSpendCard`)
on Финансы → Бюджет → Планирование → **Факт**.

**Result: all 3 tests passed.** No escalations.

| # | Test | Result |
|---|------|--------|
| 1 | Headline = 90 BYN/день (360 / 4 days to advance), next income «Аванс» +500 in 4 days, 360 on accounts, no gap | ✅ passed |
| 2 | Reserve 100 → headline drops 90 → 65 BYN/день ((360−100)/4) | ✅ passed |
| 3 | Unpaid 600 BYN bill due 27th → red «Кассовый разрыв» warning, headline 0 BYN/день | ✅ passed |

---

## Test 1 — Headline daily limit
Account 360 BYN, advance +500 (30 Jun), salary +1200 (15th). The card shows **90 BYN/день**,
sub-line «до «АвансAvans» — через 4 дня (30 июн., +500 BYN)», «Сейчас на счетах 360 BYN»,
«Ровно в день (до зарплаты) 45 BYN». No cash-gap warning.

![Test 1 — 90 BYN/день](/home/ubuntu/screenshots/ss_e6843048.png)

## Test 2 — Reserve lowers the limit
Typing **100** into «Несгораемый резерв» updates the headline to **65 BYN/день** ((360−100)/4)
and the smoothed daily to 40 BYN. Reserve is wired into the forecast. No cash-gap warning.

![Test 2 — reserve 100 → 65 BYN/день](/home/ubuntu/screenshots/ss_c3253500.png)

## Test 3 — Cash-gap flag
Reserve reset to 0; added an unpaid planned expense **Rent 600 BYN** due day **27** (before the
advance). On the Факт tab the headline becomes **0 BYN/день**, «Ровно в день 0 BYN», and the red
warning «**Кассовый разрыв**: остатка и резерва не хватает на обязательные платежи до следующего
дохода» appears.

![Test 3 — cash gap, 0 BYN/день](/home/ubuntu/screenshots/ss_0c2d9fb1.png)

---

### Notes / caveats
- The income source list renders the **day-of-month** label using the current month
  («15-е число → 15 июн.») even though the next actual salary is 15 Jul. This is a cosmetic
  label on the План доходов list, not the forecast — the forecast correctly treats the next
  income as the advance on 30 Jun (4 days) and lists segments through 15 Jul. Worth a follow-up
  but does not affect the safe-to-spend numbers under test.
- Reserve persistence across reloads was not part of this recording (covered by unit tests).
