import { existsSync, readdirSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

// B1: Verify exactly the expected migration files exist

const MIGRATIONS_DIR = path.resolve(process.cwd(), "supabase", "migrations");

const EXPECTED_MIGRATIONS = ["20261012000000_b1_tenancy_ledger_core.sql"];

describe("migrations guard", () => {
  it("has exactly the expected B1 migrations", () => {
    const files = existsSync(MIGRATIONS_DIR)
      ? readdirSync(MIGRATIONS_DIR, { recursive: true, withFileTypes: true })
          .filter((entry) => entry.isFile())
          .map((entry) => entry.name)
          .sort()
      : [];
    expect(files).toEqual(EXPECTED_MIGRATIONS);
  });
});
