import { describe, expect, it } from "vitest";

import {
  MAX_PIASTERS,
  MIN_PIASTERS,
  MoneyError,
  PIASTERS_PER_EGP,
  formatMoney,
  isPiasters,
  toPiasters,
  type Piasters,
} from "@/lib/money";

// Section 11 format and approved D-B0-02 / D-B0-05 / D-B0-10 vectors.

describe("formatMoney", () => {
  it.each<[bigint, string]>([
    [2_000_000n, "20,000.00 ج.م"],
    [0n, "0.00 ج.م"],
    [5n, "0.05 ج.م"],
    [50n, "0.50 ج.م"],
    [100n, "1.00 ج.م"],
    [99_999n, "999.99 ج.م"],
    [100_000n, "1,000.00 ج.م"],
    [123_456_789n, "1,234,567.89 ج.م"],
  ])("formats %s piasters as %j", (value, expected) => {
    expect(formatMoney(toPiasters(value))).toBe(expected);
  });

  it("formats negatives with an LTR-isolated leading minus (D-B0-02)", () => {
    expect(formatMoney(toPiasters(-2_000_000n))).toBe("\u2066-20,000.00\u2069 ج.م");
    expect(formatMoney(toPiasters(-5n))).toBe("\u2066-0.05\u2069 ج.م");
  });

  it("formats with Arabic-Indic digits and separators when asked (D-B0-05)", () => {
    expect(formatMoney(toPiasters(2_000_000n), { digits: "arab" })).toBe("٢٠٬٠٠٠٫٠٠ ج.م");
    expect(formatMoney(toPiasters(123_456_789n), { digits: "arab" })).toBe("١٬٢٣٤٬٥٦٧٫٨٩ ج.م");
  });

  it("formats a negative with Arabic-Indic digits exactly (D-B0-10)", () => {
    expect(formatMoney(toPiasters(-2_000_000n), { digits: "arab" })).toBe("\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م");
  });

  it("uses Western digits by default and for digits: latn", () => {
    expect(formatMoney(toPiasters(2_000_000n), {})).toBe("20,000.00 ج.م");
    expect(formatMoney(toPiasters(2_000_000n), { digits: "latn" })).toBe("20,000.00 ج.م");
  });

  it("formats the signed-64-bit bounds exactly", () => {
    expect(formatMoney(MAX_PIASTERS)).toBe("92,233,720,368,547,758.07 ج.م");
    expect(formatMoney(MIN_PIASTERS)).toBe("\u2066-92,233,720,368,547,758.08\u2069 ج.م");
  });

  it("formats values above Number.MAX_SAFE_INTEGER without precision loss", () => {
    expect(formatMoney(toPiasters(9_007_199_254_740_993n))).toBe("90,071,992,547,409.93 ج.م");
  });

  it("throws MoneyError for out-of-range or non-bigint runtime values", () => {
    expect(() => formatMoney((MAX_PIASTERS + 1n) as Piasters)).toThrow(MoneyError);
    expect(() => formatMoney((MIN_PIASTERS - 1n) as Piasters)).toThrow(MoneyError);
    expect(() => formatMoney(2_000_000 as unknown as Piasters)).toThrow(MoneyError);
  });
});

describe("toPiasters / isPiasters", () => {
  it("defines 100 piasters per EGP", () => {
    expect(PIASTERS_PER_EGP).toBe(100n);
  });

  it("brands values inside the signed-64-bit range, including both bounds", () => {
    expect(toPiasters(0n)).toBe(0n);
    expect(toPiasters(9_223_372_036_854_775_807n)).toBe(MAX_PIASTERS);
    expect(toPiasters(-9_223_372_036_854_775_808n)).toBe(MIN_PIASTERS);
  });

  it("rejects values outside the signed-64-bit range", () => {
    expect(() => toPiasters(9_223_372_036_854_775_808n)).toThrow(MoneyError);
    expect(() => toPiasters(-9_223_372_036_854_775_809n)).toThrow(MoneyError);
  });

  it("recognizes only in-range bigint values", () => {
    expect(isPiasters(0n)).toBe(true);
    expect(isPiasters(MAX_PIASTERS)).toBe(true);
    expect(isPiasters(MIN_PIASTERS)).toBe(true);
    expect(isPiasters(MAX_PIASTERS + 1n)).toBe(false);
    expect(isPiasters(MIN_PIASTERS - 1n)).toBe(false);
    expect(isPiasters(100)).toBe(false);
    expect(isPiasters("100")).toBe(false);
    expect(isPiasters(null)).toBe(false);
  });
});
