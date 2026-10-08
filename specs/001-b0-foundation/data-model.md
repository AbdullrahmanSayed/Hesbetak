# Data Model: B0 — Foundation

**Date**: 2026-09-27 | **Plan**: [plan.md](./plan.md)

B0 creates **no database entities**: no migrations, tables, functions, or policies (Rule 2, FR-026,
SC-008). The "data" in B0 is a set of application-level value types and one configuration constant.
B0 founder decisions D-B0-01…D-B0-11 and the Section 18 Rule 3 amendment are confirmed in `docs/DECISIONS.md`.

## Piasters (value type) — `src/lib/money.ts`

| Attribute | Rule |
|-----------|------|
| Representation | TS `bigint` branded as `Piasters` (approved D-B0-03) |
| Unit | 1 EGP = 100 piasters (Section 2 P4) |
| Range | PostgreSQL signed-`bigint`: `-9_223_372_036_854_775_808n` to `9_223_372_036_854_775_807n`; out-of-range inputs/results and wrong runtime types rejected with `MoneyError` |
| Sign | Value type allows negatives (balances can be negative, Section 6.10); **parsing typed EGP** rejects signs (approved D-B0-01) |
| Creation | Only via `parseMoney`, `toPiasters`, `piastersFromWire`, or the rounding helpers |
| JSON boundary | Canonical ASCII integer string using `piastersToWire`/`piastersFromWire`; never pass financial data through JS `number`. B1+ SQL must yield monetary text before JSON decoding. |
| Display | Only via `formatMoney` (Rule 3: no money arithmetic in React components; P4: formatting at the UI edge through the shared formatter, never ad hoc) |

## Money parse result (value type)

- `{ ok: true, value: Piasters }` or `{ ok: false, error: MoneyParseError }`.
- `MoneyParseError` ∈ `empty | invalid_format | too_many_decimals | signed | out_of_range`
  (approved D-B0-01). Each code maps to one Arabic message in `MONEY_PARSE_MESSAGES_AR`.

## Money format options (value type)

- Output always ends with ` ج.م` (Section 11).
- `digits: 'latn' | 'arab'` (default `'latn'`; optional `'arab'` approved D-B0-05).
- Negative rendering uses isolated LTR signed number (approved D-B0-02); with Arabic-Indic digits exactly `\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م` for −2,000,000 piasters (approved D-B0-10).

## BusinessDate (value type) — `src/lib/dates.ts`

| Attribute | Rule |
|-----------|------|
| Representation | string `YYYY-MM-DD`, branded `BusinessDate` |
| Meaning | A calendar date in `Africa/Cairo` (Section 2 P10); no time, no zone |
| Validity | Civil Gregorian date from `0001-01-01` through `9999-12-31`; matches `^\d{4}-\d{2}-\d{2}$` **and** is a real calendar date (round-trip check). Year `0000` is invalid. |
| Creation | `cairoToday()`, `toBusinessDate(instant)`, `parseBusinessDate(text)` only |
| Ordering | ISO strings compare correctly with `<`/`>`; no extra helper in B0 |

## Cairo day range (value type)

- `{ start: Date, end: Date }`, half-open `[start, end)`; `start` = the earliest instant whose Cairo
  business date is the given date; `end` = `start` of the next Cairo day.
- Modern Cairo days are 23 h, 24 h, or 25 h depending on DST. Historical time-zone offsets may produce other exact durations; boundaries always follow the instant-to-Cairo-date mapping.

## APP_NAME (configuration) — `src/config/app.ts`

- `APP_NAME = { en: "Hesbetak", ar: "حسبتك" } as const` — the only place the product name exists
  (Section 0 header, FR-012).

## State transitions

None in B0.
