# B3 Tasks

## Phase 1: Inventory Tables & Enums

- [x] T001: Create migration file `20261014000000_b3_purchases_inventory.sql`
- [x] T002: Create enums: unit_condition, unit_status, movement_type
- [x] T003: Create inventory_units table with RLS
- [x] T004: Create stock_balances table with RLS
- [x] T005: Create stock_movements table with RLS

## Phase 2: Purchase Documents

- [x] T006: Create purchase_invoices table (REVOKE direct writes)
- [x] T007: Create purchase_invoice_lines table
- [x] T008: Create purchase_returns table
- [x] T009: Create purchase_return_lines table
- [x] T010: Create supplier_payments table

## Phase 3: Inventory Adjustments

- [x] T011: Create inventory_adjustments table
- [x] T012: Create inventory_adjustment_lines table

## Phase 4: Helper Functions

- [x] T013: Create app.calc_weighted_avg function
- [x] T014: Create app.get_inventory_account_id helper (returns 1310 for new, 1320 for used)
- [x] T015: Create app.update_stock_balance function

## Phase 5: Posting RPCs

- [x] T016: Create post_purchase_invoice RPC
- [x] T017: Create post_purchase_return RPC
- [x] T018: Create post_supplier_payment RPC
- [x] T019: Create post_inventory_adjustment RPC

## Phase 6: Grants & Security

- [x] T020: REVOKE INSERT/UPDATE/DELETE on all document tables from authenticated
- [x] T021: GRANT EXECUTE on posting RPCs to authenticated
- [x] T022: Add mutation guard triggers on document tables

## Phase 7: Tests

- [x] T023: Create 023_b3_schema.test.sql (tables, enums, RLS)
- [x] T024: Create 024_b3_purchases.test.sql (T13 + purchase flows)
- [x] T025: Create 025_b3_inventory.test.sql (T14 weighted avg, T17 balance)
- [x] T026: Create 026_b3_reconciliation.test.sql (subledger = GL)

## Phase 8: Finalization

- [x] T027: Update guard-no-migrations.test.ts for B3 migration
- [x] T028: Regenerate src/types/database.ts
- [x] T029: Update CHANGELOG.md
- [x] T030: Run all local gates (typecheck, lint, unit, pgTAP)
- [x] T031: Push and create PR
