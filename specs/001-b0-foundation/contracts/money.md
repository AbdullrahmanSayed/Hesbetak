# Contract: `src/lib/money.ts`

**Status**: founder decisions D-B0-01…D-B0-05 and D-B0-10 confirmed; D-B0-03 is project-wide (amended Section 18 Rule 3) in `docs/DECISIONS.md`. The installment schedule is **not** part of this module (FR-006; Postgres `preview_installment_schedule` in B5 is authoritative). No B1 database adapter or SQL object is implemented in B0.

## Types and constants

```ts
export type Piasters = bigint & { readonly __brand: "Piasters" };
export const PIASTERS_PER_EGP = 100n;
export const MAX_PIASTERS = 9_223_372_036_854_775_807n as Piasters;
export const MIN_PIASTERS = -9_223_372_036_854_775_808n as Piasters;
export class MoneyError extends Error {} // programming errors (not user-facing)
export type MoneyParseError =
  | "empty" | "invalid_format" | "too_many_decimals" | "signed" | "out_of_range";
export const MONEY_PARSE_MESSAGES_AR: Readonly<Record<MoneyParseError, string>>;
```

## Functions

| Function | Behavior | Errors |
|----------|----------|--------|
| `toPiasters(value: bigint): Piasters` | Brands an integer inside signed-64-bit piaster range | `MoneyError` if `typeof value !== "bigint"` or outside range |
| `isPiasters(value: unknown): value is Piasters` | `typeof value === "bigint"` and within signed-64-bit range | — |
| `parseMoney(input: string): { ok: true; value: Piasters } \| { ok: false; error: MoneyParseError }` | Typed EGP text → exact piasters; string/digit based, no floats | never throws |
| `formatMoney(value: Piasters, options?: { digits?: "latn" \| "arab" }): string` | Integer → grouped text with exactly 2 decimals and the ` ج.م` suffix | `MoneyError` if `typeof value !== "bigint"` or outside signed-64-bit range |
| `mulDivRoundHalfUp(a: bigint, b: bigint, d: bigint): Piasters` | `round_half_up(a × b / d)` (Section 8.2) | `MoneyError` if any argument is not a `bigint`, `a < 0n`, `b < 0n`, `d <= 0n`, or result outside signed-64-bit range |
| `mulDivFloor(a: bigint, b: bigint, d: bigint): Piasters` | `floor(a × b / d)` (Section 8.2 principal split, 8.4 partial split) | same |
| `divCeilToStep(n: bigint, d: bigint, step: bigint): Piasters` | `ceil_to_step(n / d, step)` = smallest multiple of `step` ≥ `n / d` | `MoneyError` if any argument is not a `bigint`, `n < 0n`, `d <= 0n`, `step <= 0n`, or result outside signed-64-bit range |
| `piastersToWire(value: Piasters): string` | Canonical ASCII decimal integer string for JSON/RPC transport | `MoneyError` if `typeof value !== "bigint"` or outside signed-64-bit range |
| `piastersFromWire(text: string): Piasters` | Validate canonical ASCII signed decimal integer string, parse directly with `BigInt(text)` and range-check | `MoneyError` if `typeof text !== "string"` (e.g. a JSON number), for noncanonical text, or out of range |

Runtime type checks run before any conversion, because values arriving from JSON or untyped code can bypass TypeScript. `parseMoney` never throws: a non-string input returns `{ ok: false, error: "invalid_format" }`. `Piasters` amounts, counts, basis-point factors and steps are `bigint` operands; intermediate products may exceed signed-64-bit range, but returned monetary results must fit. Test calls use `n` literals or `toPiasters(...)`, for example `formatMoney(toPiasters(2_000_000n))`. Wire strings match `^(0|[1-9][0-9]*|-[1-9][0-9]*)$` and signed-64-bit range: no plus, decimals, grouping, leading zeros, negative zero or whitespace. Never pass a financial value through JavaScript `number`; B1+ SQL must expose financial values as text **before** JSON decoding rather than trust generated `number` types. The B0 wire helpers implement the approved transport rule but do not create B1 RPCs or views.

## Parsing rules (approved D-B0-01 and D-B0-03)

- Trim surrounding spaces, tabs, U+00A0, U+200E, U+200F, U+061C. Digits `0-9` or `٠-٩`, one digit
  system per input.
- Separators from one family per input: Western (`,` grouping, `.` decimal) or Arabic (`٬` grouping,
  `٫` decimal); either family may be used with either digit system. Grouping only between valid
  3-digit groups (`1,234,567`).
- Error precedence when several apply: `empty` → `signed` → `invalid_format` → `too_many_decimals` →
  `out_of_range`.
- At least one digit before the decimal separator; if a decimal separator is present, 1–2 digits
  after it (3+ → `too_many_decimals`). Leading zeros allowed. Zero is valid (positivity is a per-form
  rule, not a parser rule).
- Any `+`/`-` → `signed`; exponent, internal spaces or direction marks, currency text, letters or other characters, bad grouping, mixed digit systems or separator families → `invalid_format` (3+ decimals are `too_many_decimals`, not `invalid_format`);
  empty → `empty`; above `MAX_PIASTERS` (9,223,372,036,854,775,807) piasters → `out_of_range`. Parse digit strings directly into `bigint`, with no `Number` conversion.

## Parsing edge cases (exact; approved D-B0-01/D-B0-03)

| Input | Result |
|-------|--------|
| `"20000"` | `2_000_000n` |
| `"1,234.5"` | `123_450n` |
| `"٢٠٠٠٠"` | `2_000_000n` |
| `"١٬٢٣٤٫٥"` | `123_450n` |
| `"  15.75  "` | `1_575n` |
| `"\u00A0\u200F15.75\u200E"` (no-break space and direction marks around) | `1_575n` |
| `"٢٠٠٠٠.٥"` (Arabic digits, Western decimal) | `2_000_050n` |
| `"1234٫5"` (Western digits, Arabic decimal) | `123_450n` |
| `"0"`, `"0.00"` | `0n` |
| `"007"` | `700n` |
| `"90071992547409.91"` | `9_007_199_254_740_991n` |
| `"90071992547409.92"` | `9_007_199_254_740_992n` (above JS safe integer, still valid) |
| `"92233720368547758.07"` | `9_223_372_036_854_775_807n` (max PostgreSQL `bigint`) |
| `""`, `"   "` | `empty` |
| `".5"`, `"5."` | `invalid_format` |
| `"1,00"`, `"1234,567"`, `"1,2345"` | `invalid_format` |
| `"1e3"`, `"NaN"`, `"Infinity"` | `invalid_format` |
| `"1٬234.5"` (mixed separator families) | `invalid_format` |
| `"1٢3"` (mixed digit systems) | `invalid_format` |
| `"1 000"` (internal space) | `invalid_format` |
| `"100 ج.م"`, `"EGP 100"` | `invalid_format` |
| `"15\u200F.75"` (internal direction mark) | `invalid_format` |
| `"12.345"` | `too_many_decimals` |
| `"-5"`, `"+5"` | `signed` |
| `"-12.345"`, `"-1e3"` (precedence) | `signed` |
| `"99999999999999999.999"` (precedence) | `too_many_decimals` |
| `"92233720368547758.08"` | `out_of_range` |

## Formatting rules

- Section 11: `formatMoney(toPiasters(2_000_000n))` → `20,000.00 ج.م` (U+0020 space);
  `formatMoney(toPiasters(0n))` → `0.00 ج.م`; `formatMoney(toPiasters(5n))` → `0.05 ج.م`.
- `digits: "arab"` (approved D-B0-05) → `٢٠٬٠٠٠٫٠٠ ج.م`.
- Negative (approved D-B0-02) → `\u2066-20,000.00\u2069 ج.م`.
- Negative with Arabic-Indic digits (approved D-B0-10) → `\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م` (ASCII hyphen-minus).
- Signed-64-bit maximum → `92,233,720,368,547,758.07 ج.م`; minimum → `\u2066-92,233,720,368,547,758.08\u2069 ج.م`.

## Arabic messages (confirmed together with D-B0-01)

| Code | Message |
|------|---------|
| `empty` | أدخل المبلغ |
| `invalid_format` | صيغة المبلغ غير صحيحة |
| `too_many_decimals` | المبلغ يقبل رقمين فقط بعد العلامة العشرية |
| `signed` | أدخل المبلغ بدون علامة موجب أو سالب |
| `out_of_range` | المبلغ أكبر من الحد المسموح |

## Required exact test vectors

| Call | Expected | Source |
|------|----------|--------|
| `parseMoney("20000")` | `2_000_000n` | US1-1 |
| `parseMoney("1,234.5")` | `123_450n` | US1-2 |
| `formatMoney(toPiasters(2_000_000n))` | `20,000.00 ج.م` | Section 11 |
| `formatMoney(toPiasters(-2_000_000n))` | `"\u2066-20,000.00\u2069 ج.م"` | D-B0-02 |
| `formatMoney(toPiasters(-2_000_000n), { digits: "arab" })` | `"\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م"` | D-B0-10 |
| `formatMoney(MAX_PIASTERS)` / `formatMoney(MIN_PIASTERS)` | `"92,233,720,368,547,758.07 ج.م"` / `"\u2066-92,233,720,368,547,758.08\u2069 ج.م"` | Signed-64-bit bounds |
| `mulDivRoundHalfUp(1_500_000n, 4000n, 10000n)` | `600_000n` | Section 8.6 |
| `divCeilToStep(2_100_000n, 10n, 100n)` | `210_000n` | Section 8.6 |
| `mulDivFloor(1_500_000n, 210_000n, 2_100_000n)` | `150_000n` | Section 8.6 principal |
| `mulDivRoundHalfUp(1_034_500n, 3000n, 10000n)` | `310_350n` | Section 8.6 awkward |
| `divCeilToStep(1_344_850n, 7n, 500n)` | `192_500n` | Section 8.6 awkward |
| `mulDivFloor(100_000n, 60_000n, 210_000n)` | `28_571n` | Section 14 T05 (margin 285.71) |
| `mulDivRoundHalfUp(5n, 1n, 2n)` / `(1n, 1n, 3n)` | `3n` / `0n` | half-up tie / below-half |
| `piastersFromWire(piastersToWire(toPiasters(9_007_199_254_740_993n)))` | `9_007_199_254_740_993n` | Exact JSON-boundary contract, above JS safe integer |
| `piastersFromWire("9223372036854775807")` | `MAX_PIASTERS` | PostgreSQL upper bound |
| `piastersFromWire("-9223372036854775808")` | `MIN_PIASTERS` | PostgreSQL lower bound |
| `piastersFromWire("9223372036854775808")` | `MoneyError` | Reject overflow before DB |
| `piastersFromWire("-9223372036854775809")` | `MoneyError` | Reject underflow before DB |
| `piastersFromWire(12345 as unknown as string)` | `MoneyError` | Wrong runtime type (JSON number) |
