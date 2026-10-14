# B4 Tasks — Cash Sales (POS)

## Phase 1: Setup & Schema

- [ ] T001: Create branch verification and update `.specify/feature.json`
- [ ] T002: Create migration `20261015000000_b4_sales_pos.sql` skeleton
- [ ] T003: Add `sale_kind` enum
- [ ] T004: Create `sales_invoices` table with constraints and RLS
- [ ] T005: Create `sales_invoice_lines` table with constraints and RLS
- [ ] T006: Create `sales_payments` table with RLS
- [ ] T007: Create `sales_returns` table with constraints and RLS
- [ ] T008: Create `sales_return_lines` table with RLS
- [ ] T009: Create `sales_invoice_lines_no_cost` view for cashier
- [ ] T010: REVOKE direct writes and add mutation guard triggers

## Phase 2: pgTAP Tests (Write First)

- [ ] T011: Create `027_b4_schema.test.sql` with failing table/RLS assertions
- [ ] T012: Create `028_b4_cash_sale.test.sql` with T01, T02, T14 assertions
- [ ] T013: Create `029_b4_returns.test.sql` with T12 assertions
- [ ] T014: Create `030_b4_security.test.sql` with T18, T20 assertions
- [ ] T015: Run `npm run test:db` and confirm expected failures

## Phase 3: Posting RPCs

- [ ] T016: Implement `post_cash_sale` parameter validation
- [ ] T017: Implement inventory locking and status updates in `post_cash_sale`
- [ ] T018: Implement journal entry creation in `post_cash_sale`
- [ ] T019: Implement complete `post_cash_sale` RPC
- [ ] T020: Implement `post_sales_return` RPC
- [ ] T021: GRANT EXECUTE on RPCs to authenticated
- [ ] T022: Run `npm run test:db` and fix until all pass

## Phase 4: TypeScript Integration

- [ ] T023: Regenerate `src/types/database.ts`
- [ ] T024: Create `src/schemas/sales.ts` Zod schemas
- [ ] T025: Create `src/lib/rpc/sales.ts` typed wrappers
- [ ] T026: Update `tests/unit/guard-database-types.test.ts`
- [ ] T027: Run `npm run typecheck` and `npm run test:unit`

## Phase 5: UI Components

- [ ] T028: Create POS page structure `src/app/(app)/[tenant]/pos/`
- [ ] T029: Create `POSSearch` component with keyboard shortcuts
- [ ] T030: Create `POSLineGrid` component
- [ ] T031: Create `POSPayments` component
- [ ] T032: Create `POSActions` component (post, clear)
- [ ] T033: Create `ThermalReceipt` print component
- [ ] T034: Wire up complete POS flow

## Phase 6: Returns UI (Optional for B4)

- [ ] T035: Create returns page if time permits (can defer to B6)

## Phase 7: Finalization

- [ ] T036: Run all quality gates (typecheck, lint, unit, pgTAP, e2e)
- [ ] T037: Update CHANGELOG.md
- [ ] T038: Commit with conventional messages
- [ ] T039: Push branch and open PR
- [ ] T040: CI green, request review
- [ ] T041: Address review feedback
- [ ] T042: Merge after approval

---

## Test Mapping

| Spec Test | pgTAP File | Status |
|-----------|------------|--------|
| T01: Cash sale 20k | 028_b4_cash_sale.test.sql | Pending |
| T02: Discount 500 | 028_b4_cash_sale.test.sql | Pending |
| T12: Full return | 029_b4_returns.test.sql | Pending |
| T14: Weighted avg | 028_b4_cash_sale.test.sql | Pending |
| T18: Concurrent | 030_b4_security.test.sql | Pending |
| T20: Cost denied | 030_b4_security.test.sql | Pending |

---

## Execution Notes

1. Database work first (T002-T022)
2. Types must regenerate before TS work
3. UI depends on working RPCs
4. All tests must pass before PR
