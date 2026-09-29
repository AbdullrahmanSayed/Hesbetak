import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

// FR-012 / Section 0: the product name exists only in src/config/app.ts.

const SRC_DIR = path.resolve(process.cwd(), "src");
const ALLOWED_FILE = path.join(SRC_DIR, "config", "app.ts");
const PRODUCT_NAME = /hesbetak|حسبتك/i;

function listFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(dir, entry.name);
    return entry.isDirectory() ? listFiles(fullPath) : [fullPath];
  });
}

describe("product-name guard", () => {
  it("finds the product name in src/config/app.ts", () => {
    expect(readFileSync(ALLOWED_FILE, "utf8")).toMatch(PRODUCT_NAME);
  });

  it("finds the product name in no other file under src/", () => {
    const offenders = listFiles(SRC_DIR)
      .filter((file) => file !== ALLOWED_FILE)
      .filter((file) => PRODUCT_NAME.test(readFileSync(file, "utf8")))
      .map((file) => path.relative(process.cwd(), file));
    expect(offenders).toEqual([]);
  });
});
