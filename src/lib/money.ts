/**
 * Money helpers — integer piasters only (Section 2 P4, amended Section 18 Rule 3).
 *
 * - Every amount is a `bigint` number of piasters (1 EGP = 100 piasters) within the PostgreSQL
 *   signed-`bigint` range. Values never pass through JavaScript `number` or floating point.
 * - Financial JSON/RPC values are canonical decimal strings (`piastersToWire` / `piastersFromWire`).
 * - The installment schedule is not computed here; only the Section 8.2 rounding primitives are
 *   (the Postgres `preview_installment_schedule` in B5 is authoritative).
 */

export type Piasters = bigint & { readonly __brand: "Piasters" };

export const PIASTERS_PER_EGP = 100n;

/** PostgreSQL signed-`bigint` maximum. */
export const MAX_PIASTERS = 9_223_372_036_854_775_807n as Piasters;

/** PostgreSQL signed-`bigint` minimum. */
export const MIN_PIASTERS = -9_223_372_036_854_775_808n as Piasters;

/** A programming error (wrong type, out-of-range value, invalid operand). Not user-facing. */
export class MoneyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MoneyError";
  }
}

export type MoneyParseError = "empty" | "invalid_format" | "too_many_decimals" | "signed" | "out_of_range";

export type MoneyParseResult = { ok: true; value: Piasters } | { ok: false; error: MoneyParseError };

/** User-facing Arabic messages for parse errors (approved D-B0-01). */
export const MONEY_PARSE_MESSAGES_AR: Readonly<Record<MoneyParseError, string>> = Object.freeze({
  empty: "أدخل المبلغ",
  invalid_format: "صيغة المبلغ غير صحيحة",
  too_many_decimals: "المبلغ يقبل رقمين فقط بعد العلامة العشرية",
  signed: "أدخل المبلغ بدون علامة موجب أو سالب",
  out_of_range: "المبلغ أكبر من الحد المسموح",
});

const CURRENCY_SUFFIX = "ج.م";

const WESTERN_DIGITS = "0123456789";
const ARABIC_INDIC_DIGITS = "٠١٢٣٤٥٦٧٨٩";

// Spaces, tabs, no-break spaces and direction marks that often surround pasted RTL text.
const SURROUNDING_NOISE = /^[ \t\u00A0\u200E\u200F\u061C]+|[ \t\u00A0\u200E\u200F\u061C]+$/g;
const HAS_SIGN = /[+-]/;
const HAS_WESTERN_DIGIT = /[0-9]/;
const HAS_ARABIC_INDIC_DIGIT = /[٠-٩]/;
const HAS_WESTERN_SEPARATOR = /[,.]/;
const HAS_ARABIC_SEPARATOR = /[٬٫]/;
// After normalization: integer part either ungrouped or in valid 3-digit groups; optional fraction.
const AMOUNT_SHAPE = /^(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?$/;
const WIRE_SHAPE = /^(0|[1-9][0-9]*|-[1-9][0-9]*)$/;
const GROUP_THOUSANDS = /\B(?=(\d{3})+(?!\d))/g;

function inRange(value: bigint): boolean {
  return value >= MIN_PIASTERS && value <= MAX_PIASTERS;
}

function assertPiasters(value: unknown, context: string): asserts value is Piasters {
  if (typeof value !== "bigint") {
    throw new MoneyError(`${context}: expected a bigint piaster value, got ${typeof value}`);
  }
  if (!inRange(value)) {
    throw new MoneyError(`${context}: ${value.toString()} is outside the signed-64-bit piaster range`);
  }
}

/** Brands a `bigint` as piasters after checking type and signed-64-bit range. */
export function toPiasters(value: bigint): Piasters {
  assertPiasters(value, "toPiasters");
  return value;
}

/** True for a `bigint` inside the signed-64-bit piaster range. */
export function isPiasters(value: unknown): value is Piasters {
  return typeof value === "bigint" && inRange(value);
}

function toWesternDigits(text: string): string {
  let result = "";
  for (const char of text) {
    const index = ARABIC_INDIC_DIGITS.indexOf(char);
    result += index >= 0 ? WESTERN_DIGITS.charAt(index) : char;
  }
  return result;
}

/**
 * Parses typed EGP text into exact piasters (approved D-B0-01).
 * Never throws; errors follow the precedence empty → signed → invalid_format → too_many_decimals →
 * out_of_range.
 */
export function parseMoney(input: string): MoneyParseResult {
  if (typeof input !== "string") {
    return { ok: false, error: "invalid_format" };
  }
  const text = input.replace(SURROUNDING_NOISE, "");
  if (text === "") {
    return { ok: false, error: "empty" };
  }
  if (HAS_SIGN.test(text)) {
    return { ok: false, error: "signed" };
  }
  if (HAS_WESTERN_DIGIT.test(text) && HAS_ARABIC_INDIC_DIGIT.test(text)) {
    return { ok: false, error: "invalid_format" };
  }
  if (HAS_WESTERN_SEPARATOR.test(text) && HAS_ARABIC_SEPARATOR.test(text)) {
    return { ok: false, error: "invalid_format" };
  }
  const normalized = toWesternDigits(text).replace(/٬/g, ",").replace(/٫/g, ".");
  if (!AMOUNT_SHAPE.test(normalized)) {
    return { ok: false, error: "invalid_format" };
  }
  const dot = normalized.indexOf(".");
  const integerDigits = (dot < 0 ? normalized : normalized.slice(0, dot)).replace(/,/g, "");
  const fractionDigits = dot < 0 ? "" : normalized.slice(dot + 1);
  if (fractionDigits.length > 2) {
    return { ok: false, error: "too_many_decimals" };
  }
  const value = BigInt(integerDigits) * PIASTERS_PER_EGP + BigInt(fractionDigits.padEnd(2, "0"));
  if (value > MAX_PIASTERS) {
    return { ok: false, error: "out_of_range" };
  }
  return { ok: true, value: value as Piasters };
}

export type FormatMoneyOptions = { digits?: "latn" | "arab" };

/**
 * Formats piasters as `20,000.00 ج.م` (Section 11). Negative amounts keep a leading ASCII minus and
 * are wrapped in LTR isolate marks (D-B0-02, D-B0-10); `digits: "arab"` uses Arabic-Indic digits
 * and separators (D-B0-05).
 */
export function formatMoney(value: Piasters, options?: FormatMoneyOptions): string {
  assertPiasters(value, "formatMoney");
  const negative = value < 0n;
  const magnitude = negative ? -value : value;
  const whole = (magnitude / PIASTERS_PER_EGP).toString().replace(GROUP_THOUSANDS, ",");
  const fraction = (magnitude % PIASTERS_PER_EGP).toString().padStart(2, "0");
  let number = `${whole}.${fraction}`;
  if (options?.digits === "arab") {
    let arabic = "";
    for (const char of number) {
      if (char === ",") {
        arabic += "٬";
      } else if (char === ".") {
        arabic += "٫";
      } else {
        arabic += ARABIC_INDIC_DIGITS.charAt(WESTERN_DIGITS.indexOf(char));
      }
    }
    number = arabic;
  }
  const signed = negative ? `\u2066-${number}\u2069` : number;
  return `${signed} ${CURRENCY_SUFFIX}`;
}

/** Canonical decimal string for JSON/RPC transport (D-B0-03). */
export function piastersToWire(value: Piasters): string {
  assertPiasters(value, "piastersToWire");
  return value.toString();
}

/** Parses a canonical decimal string from JSON/RPC transport into piasters (D-B0-03). */
export function piastersFromWire(text: string): Piasters {
  if (typeof text !== "string") {
    throw new MoneyError(`piastersFromWire: expected a decimal string, got ${typeof text}`);
  }
  if (!WIRE_SHAPE.test(text)) {
    throw new MoneyError("piastersFromWire: not a canonical decimal integer string");
  }
  const value = BigInt(text);
  assertPiasters(value, "piastersFromWire");
  return value;
}

function assertOperands(context: string, operands: readonly bigint[]): void {
  for (const operand of operands) {
    if (typeof operand !== "bigint") {
      throw new MoneyError(`${context}: every operand must be a bigint`);
    }
  }
}

function checkedResult(value: bigint, context: string): Piasters {
  assertPiasters(value, context);
  return value;
}

function assertProductOperands(context: string, a: bigint, b: bigint, d: bigint): void {
  assertOperands(context, [a, b, d]);
  if (a < 0n || b < 0n) {
    throw new MoneyError(`${context}: operands must be non-negative`);
  }
  if (d <= 0n) {
    throw new MoneyError(`${context}: divisor must be positive`);
  }
}

/** `round_half_up(a × b / d)` (Section 8.2). The product is exact at any size. */
export function mulDivRoundHalfUp(a: bigint, b: bigint, d: bigint): Piasters {
  assertProductOperands("mulDivRoundHalfUp", a, b, d);
  const product = a * b;
  const quotient = product / d;
  const remainder = product % d;
  return checkedResult(remainder * 2n >= d ? quotient + 1n : quotient, "mulDivRoundHalfUp");
}

/** `floor(a × b / d)` (Section 8.2 principal split, Section 8.4 partial margin). */
export function mulDivFloor(a: bigint, b: bigint, d: bigint): Piasters {
  assertProductOperands("mulDivFloor", a, b, d);
  return checkedResult((a * b) / d, "mulDivFloor");
}

/** `ceil_to_step(n / d, step)`: the smallest multiple of `step` that is ≥ `n / d` (Section 8.2). */
export function divCeilToStep(n: bigint, d: bigint, step: bigint): Piasters {
  assertOperands("divCeilToStep", [n, d, step]);
  if (n < 0n) {
    throw new MoneyError("divCeilToStep: numerator must be non-negative");
  }
  if (d <= 0n || step <= 0n) {
    throw new MoneyError("divCeilToStep: divisor and step must be positive");
  }
  const unit = d * step;
  return checkedResult(((n + unit - 1n) / unit) * step, "divCeilToStep");
}
