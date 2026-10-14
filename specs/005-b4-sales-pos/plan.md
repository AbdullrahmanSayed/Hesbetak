# B4 — Cash Sales (POS) Implementation Plan

## Phase 1: Database Schema

### 1.1 Migration File
Create `supabase/migrations/20261015000000_b4_sales_pos.sql` with:
- `sale_kind` enum
- `sales_invoices` table with RLS
- `sales_invoice_lines` table with RLS
- `sales_payments` table with RLS
- `sales_returns` table with RLS
- `sales_return_lines` table with RLS
- All indexes (tenant-first)
- REVOKE INSERT/UPDATE/DELETE from authenticated
- Mutation guard triggers

### 1.2 Security Views
- Create `sales_invoice_lines_no_cost` view for cashier (excludes cost_snapshot)
- Grant SELECT on view to authenticated, restrict base table cost column

---

## Phase 2: Posting RPCs

### 2.1 post_cash_sale
**Dependencies**: B1 journal, B3 inventory

**Implementation Order**:
1. Parameter validation (Zod-like checks in SQL)
2. Idempotency via `app.begin_posting_request`
3. Date validation (> lock_date, ≤ today)
4. Product/unit validation
5. Serial unit row locking (`SELECT ... FOR UPDATE`)
6. Discount permission check
7. Payment total validation
8. Document number via `app.next_document_number`
9. Insert invoice, lines, payments
10. Inventory updates:
    - Serial: update `inventory_units.status = 'sold'`
    - Qty: decrement `stock_balances`, use `app.calc_weighted_avg` for cost
11. Stock movements insert
12. Journal entry via `app.create_journal_entry`
13. Finish posting

### 2.2 post_sales_return
**Implementation Order**:
1. Owner/manager permission check
2. Original invoice validation
3. Return quantity validation (track already returned)
4. Proportional refund calculation (handle discount split)
5. Document number
6. Insert return, lines
7. Inventory restoration:
    - Serial: update status to in_stock/open_box/used based on condition
    - Qty: increment balance at original cost
8. Stock movements
9. Journal entry (mirror with sign flip)

---

## Phase 3: pgTAP Tests

### 3.1 Schema Tests (`027_b4_schema.test.sql`)
- Tables exist with correct columns
- Constraints work
- RLS enabled
- Grants correct

### 3.2 Cash Sale Tests (`028_b4_cash_sale.test.sql`)
- T01: Basic cash sale journal entries
- T02: Cash sale with discount
- T14: Weighted average COGS
- T18: Concurrent serial lock

### 3.3 Return Tests (`029_b4_returns.test.sql`)
- T12: Full return reverses everything
- Partial return
- Cannot return more than sold

### 3.4 Security Tests (`030_b4_security.test.sql`)
- T20: Cashier cannot see cost data
- Cross-tenant denial
- Direct DML denied

---

## Phase 4: TypeScript Layer

### 4.1 Types
Regenerate `src/types/database.ts` with new tables

### 4.2 RPC Wrappers
```typescript
// src/lib/rpc/sales.ts
export async function postCashSale(params: PostCashSaleParams): Promise<SaleResult>
export async function postSalesReturn(params: PostSalesReturnParams): Promise<ReturnResult>
```

### 4.3 Zod Schemas
```typescript
// src/schemas/sales.ts
export const cashSaleLineSchema = z.object({...})
export const cashSalePaymentSchema = z.object({...})
export const cashSaleSchema = z.object({...})
```

---

## Phase 5: UI Components

### 5.1 POS Page (`src/app/(app)/[tenant]/pos/page.tsx`)
- Server component wrapper
- Client component for interactive POS

### 5.2 POS Components
- `POSSearch` - product search with keyboard shortcuts
- `POSLineGrid` - editable line items
- `POSPayments` - split payment entry
- `POSActions` - post, clear, print buttons
- `POSReceipt` - print preview/trigger

### 5.3 Keyboard Shortcuts
- `/` → focus search
- Enter → add product
- F9 → post sale
- Esc → clear

---

## Phase 6: Print Templates

### 6.1 Thermal Receipt (80mm)
```
src/components/print/ThermalReceipt.tsx
```
- Business name/logo
- Date, receipt number
- Items (no cost shown)
- Totals
- Footer from settings

---

## Phase 7: Finalization

### 7.1 Quality Gates
- `npm run typecheck`
- `npm run lint`
- `npm run test:unit`
- `npm run test:db` (all pgTAP including new)
- `npm run test:e2e`

### 7.2 Documentation
- Update CHANGELOG.md
- Update DECISIONS.md if needed

### 7.3 PR
- Commit with conventional messages
- Push branch
- Open PR
- CI green
- Review

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Concurrent serial sale race | Row-level locking with FOR UPDATE |
| Discount abuse | Permission check in RPC |
| Floating point money | All bigint piasters |
| Cost leak to cashier | View without cost column |

---

## Dependencies

- B1: Journal, idempotency, counters
- B3: Inventory tables, stock functions
- Supabase local running
