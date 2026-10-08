import { afterAll, afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  BUSINESS_TIME_ZONE,
  BusinessDateError,
  cairoDayRange,
  cairoToday,
  isBusinessDate,
  parseBusinessDate,
  toBusinessDate,
  type BusinessDate,
} from "@/lib/dates";

// Exact vectors from specs/001-b0-foundation/contracts/dates.md, asserted under several machine time zones.

const MACHINE_TIME_ZONES = [
  { zone: "UTC", offsetMinutesAtEpoch: 0 },
  { zone: "America/New_York", offsetMinutesAtEpoch: 300 },
  { zone: "Asia/Tokyo", offsetMinutesAtEpoch: -540 },
] as const;

const originalTimeZone = process.env.TZ;

function businessDate(text: string): BusinessDate {
  const parsed = parseBusinessDate(text);
  if (parsed === null) {
    throw new Error(`test fixture is not a valid business date: ${text}`);
  }
  return parsed;
}

const INSTANT_VECTORS: ReadonlyArray<[string, string]> = [
  ["2026-01-14T21:59:59Z", "2026-01-14"],
  ["2026-01-14T22:00:00Z", "2026-01-15"],
  ["2024-07-10T20:59:59Z", "2024-07-10"],
  ["2024-07-10T21:00:00Z", "2024-07-11"],
  ["2025-12-31T22:00:00Z", "2026-01-01"],
  ["2024-02-28T22:00:00Z", "2024-02-29"],
  ["2024-04-25T21:59:59Z", "2024-04-25"], // last second before DST start
  ["2024-04-25T22:00:00Z", "2024-04-26"], // DST start; local 01:00
  ["2024-10-31T20:59:59Z", "2024-10-31"], // before DST end
  ["2024-10-31T21:00:00Z", "2024-10-31"], // repeated hour, local 23:00 again
  ["2024-10-31T22:00:00Z", "2024-11-01"], // after DST end
];

const DAY_RANGE_VECTORS: ReadonlyArray<[string, string, string, number]> = [
  ["2026-01-15", "2026-01-14T22:00:00.000Z", "2026-01-15T22:00:00.000Z", 24],
  ["2024-04-26", "2024-04-25T22:00:00.000Z", "2024-04-26T21:00:00.000Z", 23], // DST start
  ["2024-10-31", "2024-10-30T21:00:00.000Z", "2024-10-31T22:00:00.000Z", 25], // DST end
  ["2024-07-10", "2024-07-09T21:00:00.000Z", "2024-07-10T21:00:00.000Z", 24], // summer
  ["2025-12-31", "2025-12-30T22:00:00.000Z", "2025-12-31T22:00:00.000Z", 24], // year end
];

afterAll(() => {
  process.env.TZ = originalTimeZone;
});

describe.each(MACHINE_TIME_ZONES)("with machine time zone $zone", ({ zone, offsetMinutesAtEpoch }) => {
  beforeEach(() => {
    process.env.TZ = zone;
  });

  it("really runs under that machine time zone", () => {
    expect(new Date(0).getTimezoneOffset()).toBe(offsetMinutesAtEpoch);
  });

  it.each(INSTANT_VECTORS)("toBusinessDate(%s) is %s", (instant, expected) => {
    expect(toBusinessDate(new Date(instant))).toBe(expected);
  });

  it.each(DAY_RANGE_VECTORS)("cairoDayRange(%s) is [%s, %s) — %i hours", (date, start, end, hours) => {
    const range = cairoDayRange(businessDate(date));
    expect(range.start.toISOString()).toBe(start);
    expect(range.end.toISOString()).toBe(end);
    expect((range.end.getTime() - range.start.getTime()) / 3_600_000).toBe(hours);
  });

  it("puts the instant before the range start on the previous business date", () => {
    for (const [date] of DAY_RANGE_VECTORS) {
      const { start, end } = cairoDayRange(businessDate(date));
      expect(toBusinessDate(start)).toBe(date);
      expect(toBusinessDate(new Date(start.getTime() - 1))).not.toBe(date);
      expect(toBusinessDate(new Date(end.getTime() - 1))).toBe(date);
      expect(toBusinessDate(end)).not.toBe(date);
    }
  });

  describe("cairoToday", () => {
    afterEach(() => {
      vi.useRealTimers();
    });

    it("returns the Cairo date of the system clock, not the machine date", () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date("2026-01-14T22:30:00Z"));
      expect(cairoToday()).toBe("2026-01-15");
    });
  });
});

describe("parseBusinessDate / isBusinessDate", () => {
  it.each(["0000-01-01", "2026-02-30", "2026-13-01", "2026-02-29", "2026-04-31", "26-1-1", "2026-00-10", "2026-01-00", "2026-1-01", "2026-01-15T00:00", " 2026-01-15", ""])(
    "rejects %j",
    (text) => {
      expect(parseBusinessDate(text)).toBeNull();
      expect(isBusinessDate(text)).toBe(false);
    },
  );

  it.each(["0001-01-01", "2024-02-29", "2026-01-15", "2025-12-31", "2026-04-30", "9999-12-31"])("accepts %j", (text) => {
    expect(parseBusinessDate(text)).toBe(text);
    expect(isBusinessDate(text)).toBe(true);
  });

  it("returns null for non-string runtime values", () => {
    for (const value of [20260115, null, undefined, new Date("2026-01-15T00:00:00Z")]) {
      expect(parseBusinessDate(value as unknown as string)).toBeNull();
    }
  });
});

describe("errors and constants", () => {
  it("uses the Africa/Cairo zone", () => {
    expect(BUSINESS_TIME_ZONE).toBe("Africa/Cairo");
  });

  it("toBusinessDate rejects invalid dates and non-Date values", () => {
    expect(() => toBusinessDate(new Date("invalid"))).toThrow(BusinessDateError);
    expect(() => toBusinessDate("2026-01-15" as unknown as Date)).toThrow(BusinessDateError);
  });

  it("cairoDayRange supports the complete civil four-digit year range", () => {
    for (const date of ["0001-01-01", "9999-12-31"]) {
      const { start, end } = cairoDayRange(businessDate(date));
      expect(start.getTime()).toBeLessThan(end.getTime());
      expect(toBusinessDate(start)).toBe(date);
      expect(toBusinessDate(new Date(start.getTime() - 1))).not.toBe(date);
      expect(toBusinessDate(new Date(end.getTime() - 1))).toBe(date);
    }
  });

  it("cairoDayRange rejects impossible business dates", () => {
    expect(() => cairoDayRange("2026-02-30" as BusinessDate)).toThrow(BusinessDateError);
  });
});
