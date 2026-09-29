import { describe, expect, it } from "vitest";

import {
  MAX_PIASTERS,
  MIN_PIASTERS,
  MoneyError,
  formatMoney,
  piastersFromWire,
  piastersToWire,
  toPiasters,
} from "@/lib/money";

// JSON/RPC boundary contract (D-B0-03, amended Rule 3): canonical decimal strings, never JS number.

describe("piastersToWire / piastersFromWire", () => {
  it.each<[bigint, string]>([
    [0n, "0"],
    [1n, "1"],
    [-1n, "-1"],
    [2_000_000n, "2000000"],
    [9_007_199_254_740_991n, "9007199254740991"],
    [9_007_199_254_740_993n, "9007199254740993"],
    [9_223_372_036_854_775_807n, "9223372036854775807"],
    [-9_223_372_036_854_775_808n, "-9223372036854775808"],
  ])("round-trips %s exactly through %j", (value, wire) => {
    const piasters = toPiasters(value);
    expect(piastersToWire(piasters)).toBe(wire);
    expect(piastersFromWire(wire)).toBe(value);
    expect(piastersFromWire(piastersToWire(piasters))).toBe(value);
  });

  it("round-trips a value above Number.MAX_SAFE_INTEGER without a number step", () => {
    const value = toPiasters(9_007_199_254_740_993n);
    // A JS number cannot represent this value; the string path must keep it exact.
    expect(piastersFromWire(piastersToWire(value))).toBe(9_007_199_254_740_993n);
  });

  it("accepts the PostgreSQL signed-bigint bounds", () => {
    expect(piastersFromWire("9223372036854775807")).toBe(MAX_PIASTERS);
    expect(piastersFromWire("-9223372036854775808")).toBe(MIN_PIASTERS);
  });

  it.each(["9223372036854775808", "-9223372036854775809", "99999999999999999999999"])(
    "rejects out-of-range wire value %j",
    (text) => {
      expect(() => piastersFromWire(text)).toThrow(MoneyError);
    },
  );

  it.each(["", " 1", "1 ", "+1", "01", "-0", "00", "1.0", "1,000", "1e3", "0x10", "١٢", "--1", "-", "NaN"])(
    "rejects noncanonical wire text %j",
    (text) => {
      expect(() => piastersFromWire(text)).toThrow(MoneyError);
    },
  );

  it("rejects a JSON number or other non-string runtime value", () => {
    for (const value of [12345, 12345n, null, undefined, {}]) {
      expect(() => piastersFromWire(value as unknown as string)).toThrow(MoneyError);
    }
  });
});

describe("runtime type checks on bigint entry points", () => {
  it("rejects non-bigint values passed to toPiasters, formatMoney and piastersToWire", () => {
    for (const value of [1, "1", null, undefined, 1.5]) {
      expect(() => toPiasters(value as unknown as bigint)).toThrow(MoneyError);
      expect(() => formatMoney(value as unknown as ReturnType<typeof toPiasters>)).toThrow(MoneyError);
      expect(() => piastersToWire(value as unknown as ReturnType<typeof toPiasters>)).toThrow(MoneyError);
    }
  });

  it("rejects out-of-range bigint values passed to piastersToWire", () => {
    expect(() => piastersToWire((MAX_PIASTERS + 1n) as ReturnType<typeof toPiasters>)).toThrow(MoneyError);
    expect(() => piastersToWire((MIN_PIASTERS - 1n) as ReturnType<typeof toPiasters>)).toThrow(MoneyError);
  });
});
