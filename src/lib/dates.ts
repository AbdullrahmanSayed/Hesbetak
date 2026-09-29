/**
 * Cairo business-date helpers (Section 2 P10, Section 18 Rule 11).
 *
 * A business date is the calendar date in Africa/Cairo, independent of the device or server time
 * zone. This is the only module allowed to read the clock for business dates (lint-enforced).
 */
import { formatInTimeZone } from "date-fns-tz";

export const BUSINESS_TIME_ZONE = "Africa/Cairo";

/** A Cairo calendar date formatted `YYYY-MM-DD`. */
export type BusinessDate = string & { readonly __brand: "BusinessDate" };

export class BusinessDateError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "BusinessDateError";
  }
}

const BUSINESS_DATE_SHAPE = /^\d{4}-\d{2}-\d{2}$/;
const MS_PER_HOUR = 3_600_000;
const MS_PER_DAY = 24 * MS_PER_HOUR;
// No real time zone is more than 14 hours from UTC, so a Cairo day starts within this window
// around the UTC midnight of the same calendar date.
const SEARCH_WINDOW_MS = 14 * MS_PER_HOUR;

/** The Cairo calendar date of an instant. */
export function toBusinessDate(instant: Date): BusinessDate {
  if (!(instant instanceof Date) || Number.isNaN(instant.getTime())) {
    throw new BusinessDateError("toBusinessDate: expected a valid Date instant");
  }
  return formatInTimeZone(instant, BUSINESS_TIME_ZONE, "yyyy-MM-dd") as BusinessDate;
}

/** Today's Cairo business date from the system clock. */
export function cairoToday(): BusinessDate {
  return toBusinessDate(new Date());
}

/** Validates strict `YYYY-MM-DD` text that names a real calendar date; never throws. */
export function parseBusinessDate(text: string): BusinessDate | null {
  if (typeof text !== "string" || !BUSINESS_DATE_SHAPE.test(text)) {
    return null;
  }
  const utcMidnight = Date.parse(`${text}T00:00:00.000Z`);
  if (Number.isNaN(utcMidnight) || new Date(utcMidnight).toISOString().slice(0, 10) !== text) {
    return null;
  }
  return text as BusinessDate;
}

export function isBusinessDate(text: string): text is BusinessDate {
  return parseBusinessDate(text) !== null;
}

/**
 * The earliest instant whose Cairo business date is `date`, found by binary search over
 * milliseconds. Correct when local midnight does not exist (DST start) and when the day has a
 * repeated hour (DST end), because it relies only on the instant → business-date mapping.
 */
function startOfBusinessDay(date: BusinessDate): number {
  const utcMidnight = Date.parse(`${date}T00:00:00.000Z`);
  // Invariant: business date at `before` < date <= business date at `atOrAfter`.
  let before = utcMidnight - SEARCH_WINDOW_MS;
  let atOrAfter = utcMidnight + SEARCH_WINDOW_MS;
  while (atOrAfter - before > 1) {
    const middle = Math.floor((before + atOrAfter) / 2);
    if (toBusinessDate(new Date(middle)) < date) {
      before = middle;
    } else {
      atOrAfter = middle;
    }
  }
  return atOrAfter;
}

/** Half-open instant range `[start, end)` of a Cairo business day (23, 24 or 25 hours long). */
export function cairoDayRange(date: BusinessDate): { start: Date; end: Date } {
  if (!isBusinessDate(date)) {
    throw new BusinessDateError("cairoDayRange: expected a valid YYYY-MM-DD business date");
  }
  const nextDate = new Date(Date.parse(`${date}T00:00:00.000Z`) + MS_PER_DAY).toISOString().slice(0, 10) as BusinessDate;
  return { start: new Date(startOfBusinessDay(date)), end: new Date(startOfBusinessDay(nextDate)) };
}
