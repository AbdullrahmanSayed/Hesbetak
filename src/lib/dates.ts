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

/** Validates a civil Gregorian date in the four-digit range `0001-01-01`–`9999-12-31`; never throws. */
export function parseBusinessDate(text: string): BusinessDate | null {
  if (typeof text !== "string" || !BUSINESS_DATE_SHAPE.test(text) || text.startsWith("0000-")) {
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
 * Finds the first instant inside or outside `date` around one of its UTC-midnight boundaries.
 * Equality, rather than lexical year ordering, keeps the search correct at the `0001` boundary.
 */
function businessDayBoundary(date: BusinessDate, utcBoundary: number, findStart: boolean): number {
  let before = utcBoundary - SEARCH_WINDOW_MS;
  let atOrAfter = utcBoundary + SEARCH_WINDOW_MS;
  while (atOrAfter - before > 1) {
    const middle = Math.floor((before + atOrAfter) / 2);
    const isInsideDate = formatInTimeZone(new Date(middle), BUSINESS_TIME_ZONE, "yyyy-MM-dd") === date;
    if (isInsideDate === findStart) {
      atOrAfter = middle;
    } else {
      before = middle;
    }
  }
  return atOrAfter;
}

/** Half-open instant range `[start, end)` of a Cairo business day. */
export function cairoDayRange(date: BusinessDate): { start: Date; end: Date } {
  if (!isBusinessDate(date)) {
    throw new BusinessDateError("cairoDayRange: expected a valid YYYY-MM-DD business date");
  }
  const utcMidnight = Date.parse(`${date}T00:00:00.000Z`);
  return {
    start: new Date(businessDayBoundary(date, utcMidnight, true)),
    end: new Date(businessDayBoundary(date, utcMidnight + MS_PER_DAY, false)),
  };
}
