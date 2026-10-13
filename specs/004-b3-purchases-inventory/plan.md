# B3 Implementation Plan

## Phase 1: Inventory Tables & Enums

### 1.1 Create Enums
```sql
create type public.unit_condition as enum ('new', 'used', 'open_box');
create type public.unit_status as enum ('in_stock', 'sold', 'returned_to_supplier', 'written_off');
create type public.movement_type as enum ('purchase', 'sale', 'return_in', 'return_out', 'adjustment', 'opening');
```

### 1.2 Create inventory_units Table
- id, tenant_id, product_id, serial_no, condition, status, unit_cost (bigint)
- source_type, source_id (polymorphic reference to purchase/adjustment)
- Unique constraint: (tenant_id, product_id, serial_no)
- RLS: app.is_member(tenant_id)
- Index on status for in_stock queries

### 1.3 Create stock_balances Table
- tenant_id, product_id (PK), qty (integer), avg_cost (bigint piasters)
- Unique per tenant+product
- RLS: app.is_member(tenant_id)

### 1.4 Create stock_movements Table
- id, tenant_id, product_id, unit_id (nullable), movement_type
- qty, unit_cost, document_type, document_id
- created_at, created_by
- RLS: app.is_member(tenant_id)
- Index on document_type + document_id

## Phase 2: Purchase Documents

### 2.1 Create purchase_invoices Table
- id, tenant_id, doc_no (bigint), invoice_date, supplier_id
- supplier_invoice_no (text), subtotal, discount, total (all bigint piasters)
- paid_amount, status (posted|reversed)
- created_at, created_by
- Unique: (tenant_id, doc_no)
- REVOKE INSERT/UPDATE/DELETE from authenticated

### 2.2 Create purchase_invoice_lines Table
- id, invoice_id, product_id, qty, unit_cost, line_total
- FK to products via (tenant_id, product_id)
- REVOKE direct writes

### 2.3 Create purchase_returns Table
- id, tenant_id, doc_no, return_date, supplier_id
- original_invoice_id (nullable), subtotal, credit_amount, cash_refund
- status (posted|reversed)
- REVOKE direct writes

### 2.4 Create purchase_return_lines Table
- id, return_id, product_id, unit_id (nullable for serial), qty, unit_cost
- REVOKE direct writes

### 2.5 Create supplier_payments Table
- id, tenant_id, doc_no, payment_date, supplier_id
- cash_account_id, amount, status
- REVOKE direct writes

## Phase 3: Inventory Adjustments

### 3.1 Create inventory_adjustments Table
- id, tenant_id, doc_no, adjustment_date, reason, total_adjustment
- status (posted|reversed), created_by
- REVOKE direct writes

### 3.2 Create inventory_adjustment_lines Table
- id, adjustment_id, product_id, unit_id (nullable), qty_change, cost
- REVOKE direct writes

## Phase 4: Posting RPCs

### 4.1 post_purchase_invoice
```
Input: tenant_id, idempotency_key, supplier_id, invoice_date, supplier_invoice_no, lines[], paid_amount, cash_account_id
Flow:
1. Permission: owner or manager
2. Idempotency check
3. Validate supplier belongs to tenant
4. Lock supplier row FOR UPDATE
5. Generate doc_no
6. Insert purchase_invoice + lines
7. For each line:
   - If serial product: create inventory_units rows
   - If quantity product: update stock_balances with weighted avg
   - Create stock_movement
8. Journal entry:
   - Dr 1310 Inventory (sum of line totals)
   - Cr 2100 Payable (total - paid_amount) if any
   - Cr 11xx Cash (paid_amount) if any
9. Assert balanced
10. Audit log
11. Return {id, doc_no}
```

### 4.2 post_purchase_return
```
Input: tenant_id, idempotency_key, supplier_id, return_date, lines[], credit_to_payable, cash_refund_account_id
Flow:
1. Permission: owner or manager
2. Idempotency check
3. For serial units: validate status = in_stock, lock FOR UPDATE
4. Generate doc_no
5. Insert purchase_return + lines
6. For each line:
   - Serial: update unit status → returned_to_supplier
   - Quantity: reduce stock_balance at current avg_cost
   - Create stock_movement (return_out)
7. Journal:
   - Dr 2100 Payable (credit_to_payable)
   - Dr 11xx Cash (cash_refund) if any
   - Cr 1310 Inventory (sum at cost)
8. Assert balanced
9. Return {id, doc_no}
```

### 4.3 post_supplier_payment
```
Input: tenant_id, idempotency_key, supplier_id, payment_date, cash_account_id, amount
Flow:
1. Permission: owner or manager
2. Idempotency check
3. Validate cash_account belongs to tenant
4. Generate doc_no
5. Insert supplier_payment
6. Journal:
   - Dr 2100 Payable
   - Cr 11xx Cash
7. Assert balanced
8. Return {id, doc_no}
```

### 4.4 post_inventory_adjustment
```
Input: tenant_id, idempotency_key, adjustment_date, reason, lines[]
Flow:
1. Permission: owner only
2. Idempotency check
3. For serial units: lock FOR UPDATE
4. Generate doc_no
5. Insert adjustment + lines
6. For each line:
   - Serial with qty_change < 0: status → written_off
   - Quantity: update stock_balance qty and recalc if adding
   - Create stock_movement
7. Journal:
   - Positive adjustment: Dr Inventory, Cr 5200
   - Negative adjustment: Dr 5200, Cr Inventory
8. Assert balanced
9. Return {id, doc_no}
```

## Phase 5: Helper Functions

### 5.1 app.calc_weighted_avg
Pure function to calculate new weighted average:
```sql
create function app.calc_weighted_avg(
  old_qty int, old_avg bigint, 
  new_qty int, new_cost bigint
) returns bigint
```

### 5.2 app.get_supplier_balance
Returns supplier's current payable balance from GL (2100 filtered by supplier_id dimension).

### 5.3 Inventory reconciliation query
View or function that compares:
- Sum of inventory_units.unit_cost where status = 'in_stock'
- Sum of stock_balances.qty * avg_cost
- GL balance of 1310 + 1320

## Phase 6: Tests

### 6.1 Schema Tests (023_b3_schema.test.sql)
- All 7 new tables exist with correct columns
- Enums exist
- RLS enabled on all tables
- Authenticated cannot INSERT/UPDATE/DELETE directly

### 6.2 Purchase Tests (024_b3_purchases.test.sql)
- T13: Purchase on credit, supplier payment, balance check
- Purchase with serial products creates units
- Purchase with quantity products updates weighted avg
- Cross-tenant isolation

### 6.3 Inventory Tests (025_b3_inventory.test.sql)
- T17: Full posting sequence balance check
- Stock movement creation
- Adjustment posting
- Serial status transitions
- Weighted average calculation accuracy

### 6.4 Reconciliation Test (026_b3_reconciliation.test.sql)
- Inventory subledger = GL 1310 + 1320
- After multiple purchases and adjustments

## Definition of Done

- [ ] T13 passes (purchase credit + supplier payment)
- [ ] T17 passes (full posting balance)
- [ ] T14 purchase/weighted-average portion passes
- [ ] Inventory reconciliation = 0
- [ ] All local gates green
- [ ] Cross-tenant isolation verified
