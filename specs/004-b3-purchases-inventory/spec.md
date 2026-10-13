# B3 — Purchases & Inventory

## Overview

B3 implements the inventory system (serial tracking + weighted average), purchase invoices, purchase returns, supplier payments, stock movements, and inventory adjustments. This enables receiving goods into stock with proper costing.

## User Stories

### US1: Serial-Tracked Inventory
As an owner/manager, I can receive serial-tracked products where each unit has its own cost and status.

**Acceptance:**
- `inventory_units` table: serial, product_id, condition (new|used|open_box), status (in_stock|sold|returned_to_supplier|written_off), unit_cost (bigint piasters), source_type, source_id
- Serial uniqueness per tenant+product
- Status transitions enforced
- Costing: specific identification

### US2: Quantity-Tracked Inventory
As an owner/manager, I can receive quantity-tracked products with moving weighted average cost.

**Acceptance:**
- `stock_balances` table: product_id, qty, avg_cost (bigint piasters)
- Weighted average recalculated on every purchase: `new_avg = (old_qty * old_avg + new_qty * new_cost) / (old_qty + new_qty)`
- Cannot sell below zero quantity
- All arithmetic in piasters (bigint)

### US3: Stock Movements
As the system, I track every inventory in/out with document reference.

**Acceptance:**
- `stock_movements` table: product_id, unit_id (nullable), movement_type (purchase|sale|return|adjustment|transfer), qty, unit_cost, document_type, document_id
- Every posting RPC that affects stock creates movement records
- Movement totals reconcile to balances

### US4: Purchase Invoices
As an owner/manager, I can post purchase invoices that receive goods and create supplier payable.

**Acceptance:**
- `purchase_invoices`: doc_no, date, supplier_id, supplier_invoice_no, subtotal, discount, total, paid_amount, remaining, status
- `purchase_invoice_lines`: product_id, qty (for quantity-tracked), unit_cost, line_total
- For serial products: creates `inventory_units` rows
- For quantity products: updates `stock_balances` with weighted avg
- Journal: Dr Inventory (1310/1320), Cr Accounts Payable (2100) or Cr Cash
- Gapless document numbering
- Idempotent posting

### US5: Purchase Returns
As an owner/manager, I can return goods to supplier reducing inventory and payable.

**Acceptance:**
- `purchase_returns`: doc_no, date, supplier_id, original_invoice_id (optional), subtotal, credit_to_payable, cash_refund
- `purchase_return_lines`: product_id, unit_id (for serial), qty (for quantity), unit_cost
- Serial units: status → returned_to_supplier
- Quantity: reduces balance at weighted avg cost
- Journal: Dr Payable/Cash, Cr Inventory
- Idempotent posting

### US6: Supplier Payments
As an owner/manager, I can pay suppliers reducing payable balance.

**Acceptance:**
- `supplier_payments`: doc_no, date, supplier_id, cash_account_id, amount
- Journal: Dr Payable (2100), Cr Cash (11xx)
- Supplier balance from ledger matches sum of unpaid invoices
- Idempotent posting

### US7: Inventory Adjustments
As an owner, I can adjust inventory for count differences or damage.

**Acceptance:**
- `inventory_adjustments`: doc_no, date, reason, total_adjustment
- `inventory_adjustment_lines`: product_id, unit_id (serial), qty_change, cost
- Journal: Dr/Cr Inventory, Dr/Cr Inventory Adjustments (5200)
- Serial units can be written off (status → written_off)
- Idempotent posting

### US8: Inventory Reconciliation
As an accountant, inventory subledger equals GL 1310 + 1320.

**Acceptance:**
- Sum of inventory_units.unit_cost where status in (in_stock) = portion of 1310+1320
- Sum of stock_balances.qty * avg_cost = portion of 1310+1320
- Reconciliation query returns zero difference
- T13, T14 (purchase portion), T17 pass

## Non-Functional Requirements

- All tables have tenant_id + RLS
- Immutable posted documents (status transitions via reversal only)
- Audit log for adjustments
- Cross-tenant isolation tests
- Exact piaster arithmetic (bigint, no rounding errors)

## Out of Scope (B4+)

- Sales invoices and COGS posting
- POS UI
- Trade-in posting (partial in B6)
