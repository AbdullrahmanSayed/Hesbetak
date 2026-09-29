import { existsSync, readdirSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

// FR-026 / SC-008: B0 creates no database migrations (Rule 2; the ledger starts in B1).

const MIGRATIONS_DIR = path.resolve(process.cwd(), "supabase", "migrations");

describe("no-migrations guard", () => {
  it("finds no file in supabase/migrations/", () => {
    const files = existsSync(MIGRATIONS_DIR)
      ? readdirSync(MIGRATIONS_DIR, { recursive: true, withFileTypes: true })
          .filter((entry) => entry.isFile())
          .map((entry) => entry.name)
      : [];
    expect(files).toEqual([]);
  });
});
