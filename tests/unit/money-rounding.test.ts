import { describe, expect, it } from "vitest";

import { MAX_PIASTERS, MoneyError, divCeilToStep, mulDivFloor, mulDivRoundHalfUp } from "@/lib/money";

// Section 8.2 primitives with Section 8.6 / Section 14 T05 exact vectors (D-B0-04).

describe("mulDivRoundHalfUp — round_half_up(a × b / d)", () => {
  it("reproduces Section 8.6 margin_total vectors", () => {
    expect(mulDivRoundHalfUp(1_500_000n, 4000n, 10000n)).toBe(600_000n);
    expect(mulDivRoundHalfUp(1_034_500n, 3000n, 10000n)).toBe(310_350n);
  });

  it("rounds an exact half up and a below-half value down", () => {
    expect(mulDivRoundHalfUp(5n, 1n, 2n)).toBe(3n); // 2.5 → 3
    expect(mulDivRoundHalfUp(1n, 1n, 3n)).toBe(0n); // 0.333… → 0
    expect(mulDivRoundHalfUp(2n, 1n, 3n)).toBe(1n); // 0.666… → 1
    expect(mulDivRoundHalfUp(1n, 1n, 2n)).toBe(1n); // 0.5 → 1
    expect(mulDivRoundHalfUp(3n, 1n, 2n)).toBe(2n); // 1.5 → 2 (not banker's rounding)
    expect(mulDivRoundHalfUp(7n, 1n, 2n)).toBe(4n); // 3.5 → 4
    expect(mulDivRoundHalfUp(149n, 1n, 100n)).toBe(1n); // 1.49 → 1
  });

  it("returns exact quotients unchanged and handles zero numerators", () => {
    expect(mulDivRoundHalfUp(10n, 10n, 4n)).toBe(25n);
    expect(mulDivRoundHalfUp(0n, 4000n, 10000n)).toBe(0n);
  });

  it("computes a product above signed-64-bit exactly when the quotient fits", () => {
    expect(mulDivRoundHalfUp(MAX_PIASTERS, 10n, 20n)).toBe(4_611_686_018_427_387_904n); // …903.5 → …904
  });
});

describe("mulDivFloor — floor(a × b / d)", () => {
  it("reproduces the Section 8.6 principal split", () => {
    expect(mulDivFloor(1_500_000n, 210_000n, 2_100_000n)).toBe(150_000n);
  });

  it("reproduces the Section 14 T05 partial-payment margin 285.71", () => {
    expect(mulDivFloor(100_000n, 60_000n, 210_000n)).toBe(28_571n);
  });

  it("floors instead of rounding", () => {
    expect(mulDivFloor(5n, 1n, 2n)).toBe(2n);
    expect(mulDivFloor(99n, 1n, 100n)).toBe(0n);
  });

  it("computes a product above signed-64-bit exactly when the quotient fits", () => {
    expect(mulDivFloor(MAX_PIASTERS, 10n, 20n)).toBe(4_611_686_018_427_387_903n);
  });
});

describe("divCeilToStep — ceil_to_step(n / d, step)", () => {
  it("reproduces Section 8.6 base_amount vectors", () => {
    expect(divCeilToStep(2_100_000n, 10n, 100n)).toBe(210_000n);
    expect(divCeilToStep(1_344_850n, 7n, 500n)).toBe(192_500n);
  });

  it("keeps exact multiples and rounds anything above up to the next step", () => {
    expect(divCeilToStep(1_000n, 1n, 1_000n)).toBe(1_000n);
    expect(divCeilToStep(1_001n, 1n, 1_000n)).toBe(2_000n);
    expect(divCeilToStep(0n, 3n, 500n)).toBe(0n);
    expect(divCeilToStep(1n, 3n, 1n)).toBe(1n);
  });
});

describe("rounding primitives — domain errors", () => {
  const fns = [
    ["mulDivRoundHalfUp", mulDivRoundHalfUp],
    ["mulDivFloor", mulDivFloor],
    ["divCeilToStep", divCeilToStep],
  ] as const;

  it.each(fns)("%s rejects non-bigint arguments in every position", (_name, fn) => {
    const bad = 1 as unknown as bigint;
    expect(() => fn(bad, 1n, 1n)).toThrow(MoneyError);
    expect(() => fn(1n, bad, 1n)).toThrow(MoneyError);
    expect(() => fn(1n, 1n, bad)).toThrow(MoneyError);
  });

  it("mulDivRoundHalfUp and mulDivFloor reject negative operands and non-positive divisors", () => {
    for (const fn of [mulDivRoundHalfUp, mulDivFloor]) {
      expect(() => fn(-1n, 1n, 1n)).toThrow(MoneyError);
      expect(() => fn(1n, -1n, 1n)).toThrow(MoneyError);
      expect(() => fn(1n, 1n, 0n)).toThrow(MoneyError);
      expect(() => fn(1n, 1n, -1n)).toThrow(MoneyError);
    }
  });

  it("divCeilToStep rejects a negative numerator and non-positive divisor or step", () => {
    expect(() => divCeilToStep(-1n, 1n, 100n)).toThrow(MoneyError);
    expect(() => divCeilToStep(1n, 0n, 100n)).toThrow(MoneyError);
    expect(() => divCeilToStep(1n, -1n, 100n)).toThrow(MoneyError);
    expect(() => divCeilToStep(1n, 1n, 0n)).toThrow(MoneyError);
    expect(() => divCeilToStep(1n, 1n, -100n)).toThrow(MoneyError);
  });

  it("rejects monetary results outside the signed-64-bit range", () => {
    expect(() => mulDivRoundHalfUp(MAX_PIASTERS, 2n, 1n)).toThrow(MoneyError);
    expect(() => mulDivFloor(MAX_PIASTERS, 2n, 1n)).toThrow(MoneyError);
    expect(() => divCeilToStep(MAX_PIASTERS, 1n, 10n)).toThrow(MoneyError);
  });
});
