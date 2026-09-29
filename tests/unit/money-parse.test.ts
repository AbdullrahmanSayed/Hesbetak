import { describe, expect, it } from "vitest";

import { MONEY_PARSE_MESSAGES_AR, parseMoney, type MoneyParseError } from "@/lib/money";

// Exact vectors from specs/001-b0-foundation/contracts/money.md §Parsing edge cases (D-B0-01/D-B0-03).

describe("parseMoney — accepted inputs", () => {
  it.each<[string, bigint]>([
    ["20000", 2_000_000n],
    ["1,234.5", 123_450n],
    ["٢٠٠٠٠", 2_000_000n],
    ["١٬٢٣٤٫٥", 123_450n],
    ["  15.75  ", 1_575n],
    ["\u00A0\u200F15.75\u200E", 1_575n],
    ["٢٠٠٠٠.٥", 2_000_050n],
    ["1234٫5", 123_450n],
    ["0", 0n],
    ["0.00", 0n],
    ["007", 700n],
    ["90071992547409.91", 9_007_199_254_740_991n],
    ["90071992547409.92", 9_007_199_254_740_992n],
    ["92233720368547758.07", 9_223_372_036_854_775_807n],
  ])("parses %j to %s piasters", (input, expected) => {
    expect(parseMoney(input)).toEqual({ ok: true, value: expected });
  });

  it("accepts valid 3-digit grouping of large amounts", () => {
    expect(parseMoney("1,234,567.89")).toEqual({ ok: true, value: 123_456_789n });
    expect(parseMoney("١٬٢٣٤٬٥٦٧")).toEqual({ ok: true, value: 123_456_700n });
  });

  it("accepts Arabic separators with Western digits and Western separators with Arabic digits", () => {
    expect(parseMoney("1٬234٫50")).toEqual({ ok: true, value: 123_450n });
    expect(parseMoney("١,٢٣٤.٥٠")).toEqual({ ok: true, value: 123_450n });
  });

  it("trims tabs and the Arabic letter mark (U+061C) around the amount", () => {
    expect(parseMoney("\t\u061C5\u061C\t")).toEqual({ ok: true, value: 500n });
  });

  it("parses exactly one and two decimal digits", () => {
    expect(parseMoney("0.5")).toEqual({ ok: true, value: 50n });
    expect(parseMoney("0.05")).toEqual({ ok: true, value: 5n });
    expect(parseMoney("0.01")).toEqual({ ok: true, value: 1n });
  });

  it("keeps precision that floating point would lose", () => {
    // 0.1 + 0.2 style errors and 2^53 boundaries must not appear.
    expect(parseMoney("0.29")).toEqual({ ok: true, value: 29n });
    expect(parseMoney("1.005")).toEqual({ ok: false, error: "too_many_decimals" });
    expect(parseMoney("90071992547409.93")).toEqual({ ok: true, value: 9_007_199_254_740_993n });
  });
});

describe("parseMoney — rejected inputs", () => {
  it.each<[string, MoneyParseError]>([
    ["", "empty"],
    ["   ", "empty"],
    ["\u200F\u00A0", "empty"],
    [".5", "invalid_format"],
    ["5.", "invalid_format"],
    ["1,00", "invalid_format"],
    ["1234,567", "invalid_format"],
    ["1,2345", "invalid_format"],
    [",123", "invalid_format"],
    ["1,,234", "invalid_format"],
    ["1.2,3", "invalid_format"],
    ["1.2.3", "invalid_format"],
    ["1e3", "invalid_format"],
    ["NaN", "invalid_format"],
    ["Infinity", "invalid_format"],
    ["1٬234.5", "invalid_format"],
    ["1٢3", "invalid_format"],
    ["1 000", "invalid_format"],
    ["100 ج.م", "invalid_format"],
    ["EGP 100", "invalid_format"],
    ["15\u200F.75", "invalid_format"],
    ["۱۲۳", "invalid_format"],
    ["12.345", "too_many_decimals"],
    ["-5", "signed"],
    ["+5", "signed"],
    ["5-", "signed"],
    ["-12.345", "signed"],
    ["-1e3", "signed"],
    ["99999999999999999.999", "too_many_decimals"],
    ["92233720368547758.08", "out_of_range"],
    ["100000000000000000000", "out_of_range"],
  ])("rejects %j with %s", (input, error) => {
    expect(parseMoney(input)).toEqual({ ok: false, error });
  });

  it("returns invalid_format without throwing for non-string runtime values", () => {
    for (const value of [12345, 12345n, null, undefined, {}, ["1"]]) {
      expect(parseMoney(value as unknown as string)).toEqual({ ok: false, error: "invalid_format" });
    }
  });
});

describe("MONEY_PARSE_MESSAGES_AR", () => {
  it("maps every parse error code to its approved Arabic message", () => {
    expect(MONEY_PARSE_MESSAGES_AR).toEqual({
      empty: "أدخل المبلغ",
      invalid_format: "صيغة المبلغ غير صحيحة",
      too_many_decimals: "المبلغ يقبل رقمين فقط بعد العلامة العشرية",
      signed: "أدخل المبلغ بدون علامة موجب أو سالب",
      out_of_range: "المبلغ أكبر من الحد المسموح",
    });
  });

  it("is frozen", () => {
    expect(Object.isFrozen(MONEY_PARSE_MESSAGES_AR)).toBe(true);
  });
});
