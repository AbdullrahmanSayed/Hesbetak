# B4 — Cash Sales (POS) Specification

**Batch**: B4  
**Branch**: `005-b4-sales-contracts`  
**Dependencies**: B0, B1, B2, B3 merged to main

---

## 1. Overview

B4 delivers the Point of Sale (POS) screen for **cash sales only** (بيع كاش). Installment sales are deferred to B5. The POS must be fast, keyboard-first, and support split payments across multiple cash accounts.

---

## 2. User Stories

### US1: Quick Cash Sale
**As a** cashier or manager  
**I want to** search products by name/model/barcode/serial, add lines, apply discounts, and post a cash sale  
**So that** the sale is recorded, inventory updated, and a receipt printed

**Acceptance Criteria:**
- Search returns results < 200 ms for 10k products
- Serial products require selecting a specific `in_stock` unit
- Per-line and invoice-level discounts (within role limits)
- Payment must exactly equal net total (no credit)
- Journal entry: Dr Cash / Cr Sales, Dr COGS / Cr Inventory
- Serial unit status changes to `sold`
- Document number is gapless

### US2: Split Payment
**As a** cashier  
**I want to** split payment across multiple cash accounts (e.g., part cash, part InstaPay)  
**So that** the sale total is covered by multiple payment methods

**Acceptance Criteria:**
- Sum of all payments = net total
- Each payment line references a cash account
- Journal Dr lines: one per cash account

### US3: Walk-in Sale (No Customer)
**As a** cashier  
**I want to** complete a cash sale without selecting a customer  
**So that** quick walk-in transactions are not blocked

**Acceptance Criteria:**
- `customer_id` is nullable on `sales_invoices` for cash sales
- Installment sales (B5) will require a customer

### US4: Cash Sale Return
**As a** manager or owner  
**I want to** process a full or partial return of a cash sale  
**So that** inventory is restored and the customer refunded

**Acceptance Criteria:**
- Returns are posted via `post_sales_return` RPC
- Journal: reverse sales, reverse COGS
- Serial units return to `in_stock` (or `open_box`/`used` if damaged)
- Partial returns by line/unit
- Returns cannot exceed original quantities

### US5: Concurrent Serial Protection
**As the** system  
**I want to** prevent two users from selling the same serial unit simultaneously  
**So that** inventory integrity is maintained

**Acceptance Criteria:**
- Row lock on `inventory_units` during posting
- Second concurrent transaction fails cleanly

### US6: Cost Data Protection
**As** the system  
**I want to** hide cost and profit data from cashiers  
**So that** sensitive margin information is protected

**Acceptance Criteria:**
- Cashier role cannot SELECT cost columns or COGS accounts
- Owner/manager/accountant can see cost data

---

## 3. Database Schema (additions to B3)

### 3.1 Enums
```sql
-- Already exists from B3: unit_condition, unit_status
CREATE TYPE public.sale_kind AS ENUM ('cash', 'installment');
```

### 3.2 Tables

**sales_invoices** (document, immutable after posting)
```sql
CREATE TABLE public.sales_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants,
  doc_no text NOT NULL,
  doc_date date NOT NULL,
  customer_id uuid REFERENCES customers,  -- nullable for walk-in
  kind public.sale_kind NOT NULL DEFAULT 'cash',
  gross_total bigint NOT NULL,      -- sum of line cash_price * qty
  discount_total bigint NOT NULL,   -- sum of all discounts
  net_total bigint NOT NULL,        -- gross - discount
  status public.document_status NOT NULL DEFAULT 'posted',
  request_id uuid NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sales_invoices_tenant_doc_unique UNIQUE (tenant_id, doc_no),
  CONSTRAINT sales_invoices_net_check CHECK (net_total >= 0),
  CONSTRAINT sales_invoices_gross_discount_check CHECK (gross_total >= discount_total)
);
```

**sales_invoice_lines**
```sql
CREATE TABLE public.sales_invoice_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants,
  invoice_id uuid NOT NULL REFERENCES sales_invoices,
  line_no smallint NOT NULL,
  product_id uuid NOT NULL REFERENCES products,
  unit_id uuid REFERENCES inventory_units,  -- required for serial tracking
  qty smallint NOT NULL DEFAULT 1,
  unit_cash_price bigint NOT NULL,
  line_discount bigint NOT NULL DEFAULT 0,
  line_total bigint NOT NULL,  -- (unit_cash_price * qty) - line_discount
  cost_snapshot bigint NOT NULL,  -- unit cost at time of sale
  CONSTRAINT sales_invoice_lines_qty_check CHECK (qty > 0),
  CONSTRAINT sales_invoice_lines_unique UNIQUE (invoice_id, line_no)
);
```

**sales_payments** (split payments for a sale)
```sql
CREATE TABLE public.sales_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants,
  invoice_id uuid NOT NULL REFERENCES sales_invoices,
  cash_account_id uuid NOT NULL REFERENCES cash_accounts,
  amount bigint NOT NULL,
  CONSTRAINT sales_payments_amount_check CHECK (amount > 0)
);
```

**sales_returns** (document)
```sql
CREATE TABLE public.sales_returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants,
  doc_no text NOT NULL,
  doc_date date NOT NULL,
  original_invoice_id uuid NOT NULL REFERENCES sales_invoices,
  customer_id uuid REFERENCES customers,
  total_refund bigint NOT NULL,  -- amount returned to customer
  refund_cash_account_id uuid NOT NULL REFERENCES cash_accounts,
  reason text,
  status public.document_status NOT NULL DEFAULT 'posted',
  request_id uuid NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sales_returns_tenant_doc_unique UNIQUE (tenant_id, doc_no)
);
```

**sales_return_lines**
```sql
CREATE TABLE public.sales_return_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants,
  return_id uuid NOT NULL REFERENCES sales_returns,
  original_line_id uuid NOT NULL REFERENCES sales_invoice_lines,
  unit_id uuid REFERENCES inventory_units,
  qty smallint NOT NULL DEFAULT 1,
  refund_amount bigint NOT NULL,  -- proportional to original
  cost_snapshot bigint NOT NULL,
  return_condition public.unit_condition NOT NULL DEFAULT 'new'
);
```

---

## 4. RPCs

### 4.1 post_cash_sale
```sql
CREATE FUNCTION public.post_cash_sale(
  p_request_id uuid,
  p_doc_date date,
  p_customer_id uuid DEFAULT NULL,
  p_lines jsonb,        -- [{product_id, unit_id?, qty, unit_cash_price, line_discount}]
  p_payments jsonb,     -- [{cash_account_id, amount}]
  p_invoice_discount bigint DEFAULT 0
) RETURNS jsonb
```

**Flow:**
1. Permission check: owner, manager, or cashier
2. Idempotency check
3. Validate date > lock_date, ≤ today
4. Validate products exist, active, same tenant
5. For serial items: validate unit exists, status = 'in_stock', lock row
6. Validate discount within role limit
7. Validate Σ payments = net_total
8. Get next doc_no for 'SALE'
9. Insert sales_invoice
10. Insert sales_invoice_lines with cost_snapshot
11. Insert sales_payments
12. Update inventory: serial → sold, qty → decrement balance
13. Create stock_movements
14. Create journal entry:
    - Dr Cash accounts (multiple if split)
    - Dr 4160 Sales discounts (if any)
    - Cr 4100 Sales (gross)
    - Dr 5100 COGS
    - Cr 1310/1320 Inventory
15. Finish posting request
16. Return {id, doc_no}

### 4.2 post_sales_return
```sql
CREATE FUNCTION public.post_sales_return(
  p_request_id uuid,
  p_original_invoice_id uuid,
  p_doc_date date,
  p_lines jsonb,        -- [{original_line_id, unit_id?, qty, return_condition}]
  p_refund_cash_account_id uuid,
  p_reason text DEFAULT NULL
) RETURNS jsonb
```

**Flow:**
1. Permission check: owner or manager only
2. Idempotency check
3. Validate original invoice exists, same tenant, status = 'posted'
4. Validate return quantities ≤ original - already_returned
5. Calculate proportional refund (including discount ratio)
6. Get next doc_no for 'SRET'
7. Insert sales_return and lines
8. Update inventory: serial → in_stock (or condition), qty → increment
9. Create stock_movements
10. Create journal entry:
    - Dr 4150 Sales Returns (proportional gross)
    - Cr 4160 Sales Discounts (proportional discount)
    - Cr Cash (refund)
    - Dr 1310/1320 Inventory
    - Cr 5100 COGS
11. Return {id, doc_no}

---

## 5. Test Scenarios (from HESBETAK_SPEC.md)

| ID | Scenario | Expected |
|----|----------|----------|
| T01 | Cash sale 20,000, cost 16,000 | 1110 +20,000; 4100 20,000; 5100 16,000; 1310 −16,000; unit `sold` |
| T02 | Cash sale with 500 discount | 4160 500; 1110 +19,500 |
| T12 | Cash sale full return | Revenue and COGS reversed; unit `in_stock` |
| T14 | Weighted avg sale (B3 purchased 10@100+10@130=avg 115; sell 5) | COGS = 575 (5 × 115) |
| T18 | Two cashiers sell same serial concurrently | Exactly one succeeds |
| T20 | Cashier requests cost/profit data | Denied |

---

## 6. UI Requirements (B4 scope)

### 6.1 POS Screen `/[tenant]/pos`
- Keyboard-first: `/` focuses search, Enter adds, F9 posts, Esc clears
- Search by name/model/barcode/serial
- Line grid: product, qty, price, discount, total
- Invoice discount field
- Payment section: add payment lines (cash account + amount)
- Balance indicator: must equal zero to post
- Print receipt button (80mm thermal)

### 6.2 Print Templates
- 80mm thermal receipt: date, doc_no, lines, totals, business info from settings
- A4 invoice (optional for B4, required by B5)

---

## 7. Security

- `sales_invoices`, `sales_invoice_lines`, `sales_payments`, `sales_returns`, `sales_return_lines`: REVOKE INSERT/UPDATE/DELETE from authenticated
- Only RPCs write to these tables
- Mutation guard triggers
- RLS: tenant isolation
- Cost columns: create view without cost for cashier role

---

## 8. Definition of Done

- [ ] Migration applied, all tables created
- [ ] `post_cash_sale` RPC works with split payments
- [ ] `post_sales_return` RPC works with partial returns
- [ ] T01, T02, T12, T14, T18, T20 pgTAP tests pass
- [ ] Inventory correctly updated (serial status, qty balance)
- [ ] Journal entries balance
- [ ] POS UI functional (search, add, discount, pay, post)
- [ ] 80mm receipt prints correctly
- [ ] All existing tests still pass
- [ ] TypeScript types regenerated
- [ ] CHANGELOG updated
