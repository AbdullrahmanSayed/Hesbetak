import { existsSync, readdirSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

// B2: Verify exactly the expected migration files exist

const MIGRATIONS_DIR = path.resolve(process.cwd(), "supabase", "migrations");

const EXPECTED_MIGRATIONS = [
  "20261012000000_b1_tenancy_ledger_core.sql",
  "20261013000000_b2_master_data_attachments.sql",
  "20261014000000_b3_purchases_inventory.sql",
  "20261015000000_b4_sales_pos.sql",
  "20261016000000_b5_installment_sales.sql",
];

describe("migrations guard", () => {
  it("has exactly the expected migrations", () => {
    const files = existsSync(MIGRATIONS_DIR)
      ? readdirSync(MIGRATIONS_DIR, { recursive: true, withFileTypes: true })
          .filter((entry) => entry.isFile())
          .map((entry) => entry.name)
          .sort()
      : [];
    expect(files).toEqual(EXPECTED_MIGRATIONS);
  });
});
