# Contract: `src/lib/dates.ts`

The only module allowed to read the clock for business dates (Rule 11; lint-enforced).

## Types and constants

```ts
export const BUSINESS_TIME_ZONE = "Africa/Cairo";
export type BusinessDate = string & { readonly __brand: "BusinessDate" }; // "YYYY-MM-DD", years 0001–9999
export class BusinessDateError extends Error {}
```

## Functions

| Function | Behavior | Errors |
|----------|----------|--------|
| `cairoToday(): BusinessDate` | Current Cairo calendar date from the system clock | — |
| `toBusinessDate(instant: Date): BusinessDate` | Cairo calendar date of an instant | `BusinessDateError` on invalid `Date` |
| `parseBusinessDate(text: string): BusinessDate \| null` | Strict civil Gregorian `YYYY-MM-DD` in `0001-01-01`–`9999-12-31` + real calendar date; year `0000` is invalid | never throws |
| `isBusinessDate(text: string): text is BusinessDate` | Same check as a type guard | — |
| `cairoDayRange(date: BusinessDate): { start: Date; end: Date }` | Half-open range of the Cairo day: `start` = the earliest instant whose Cairo business date is `date`; `end` = `start` of the next day. Must be correct when local midnight does not exist (DST start) and when the day has a repeated hour (DST end) | `BusinessDateError` if `date` invalid |

## Required exact test vectors (must hold under TZ = UTC, America/New_York, Asia/Tokyo)

| Input | Expected |
|-------|----------|
| `toBusinessDate(2026-01-14T21:59:59Z)` | `2026-01-14` |
| `toBusinessDate(2026-01-14T22:00:00Z)` | `2026-01-15` |
| `toBusinessDate(2024-07-10T20:59:59Z)` | `2024-07-10` |
| `toBusinessDate(2024-07-10T21:00:00Z)` | `2024-07-11` |
| `toBusinessDate(2025-12-31T22:00:00Z)` | `2026-01-01` |
| `toBusinessDate(2024-02-28T22:00:00Z)` | `2024-02-29` |
| `toBusinessDate(2024-04-25T21:59:59Z)` (last second before DST start) | `2024-04-25` |
| `toBusinessDate(2024-04-25T22:00:00Z)` (DST start; local 01:00) | `2024-04-26` |
| `toBusinessDate(2024-10-31T20:59:59Z)` (before DST end) | `2024-10-31` |
| `toBusinessDate(2024-10-31T21:00:00Z)` (repeated hour, local 23:00 again) | `2024-10-31` |
| `toBusinessDate(2024-10-31T22:00:00Z)` (after DST end) | `2024-11-01` |
| `parseBusinessDate("2026-02-30")`, `("2026-13-01")`, `("2026-02-29")`, `("2026-04-31")`, `("26-1-1")` | `null` |
| `parseBusinessDate("2024-02-29")` | `2024-02-29` |
| `cairoDayRange("2026-01-15")` | `2026-01-14T22:00:00Z` → `2026-01-15T22:00:00Z` (24 h) |
| `cairoDayRange("2024-04-26")` (DST start) | `2024-04-25T22:00:00Z` → `2024-04-26T21:00:00Z` (23 h) |
| `cairoDayRange("2024-10-31")` (DST end) | `2024-10-30T21:00:00Z` → `2024-10-31T22:00:00Z` (25 h) |
| `parseBusinessDate("0000-01-01")` | `null` |
| `cairoDayRange("0001-01-01")`, `cairoDayRange("9999-12-31")` | Valid millisecond-exact half-open ranges whose final millisecond remains on the requested Cairo date |
| `cairoToday()` with system time `2026-01-14T22:30:00Z` (fake timers) | `2026-01-15` |

Modern Cairo days are 23, 24 or 25 hours around DST transitions. Historical time-zone offsets may include sub-hour changes; `cairoDayRange` remains defined by exact instant-to-Cairo-date boundaries rather than by a fixed duration.
