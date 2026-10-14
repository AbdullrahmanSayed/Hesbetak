# Changelog

## B4 — Cash Sales / POS (branch `005-b4-sales-contracts`)

Delivered:

- Sales documents: `sales_invoices` (cash/installment kind enum), `sales_invoice_lines` with cost snapshot,
  `sales_payments` (split payments across multiple cash accounts), `sales_returns`, `sales_return_lines`.
- Posting RPCs: `post_cash_sale` (inventory out, COGS, sales revenue, split payments),
  `post_sales_return` (inventory back in, COGS reversal, refund).
- Cost isolation: cashier cannot read cost data (purchase prices, COGS, unit costs). Safe views
  (`pos_products`, `pos_inventory_units`, `pos_cash_accounts`, `sales_invoice_lines_no_cost`,
  `sales_return_lines_no_cost`) expose only what POS needs.
- Journal entries: full double-entry for cash sales (Dr Cash, Cr Sales, Dr COGS, Cr Inventory)
  and returns (reversed).
- Money helpers: `app.money_from_json` and `app.money_from_text` for safe decimal-string parsing in SQL.
- Concurrency: advisory locks + row locks prevent double-selling serials and overselling quantities.
- TypeScript: Zod schemas (`src/schemas/sales.ts`), typed RPC wrappers (`src/lib/rpc/sales.ts`),
  POS cart logic (`src/lib/pos.ts`).
- UI: Full POS page with product search (keyboard `/`), serial picker modal, cart with quantity/discount
  editing, split payments, confirmation dialog, thermal receipt print component. Keyboard shortcuts
  (`/` search, `Enter` add, `F9` post, `Esc` clear).
- Tests: 116 pgTAP tests (schema 35, cash_sale 31, returns 21, security 25, concurrency 4),
  210 unit tests, full typecheck and lint passing.

Checks: typecheck ✓, lint ✓, unit ✓ (210), pgTAP ✓ (116 B4 + prior batches).

Deferred to B5+: installment sales, collections, customer selection in POS, returns UI page.

## B3 — Purchases & Inventory (branch `004-b3-purchases-inventory`, merged to `main`)

Delivered:

- Inventory tracking: `inventory_units` (serial tracking with specific identification costing),
  `stock_balances` (quantity tracking with moving weighted average), `stock_movements` (audit trail).
- Purchase documents: `purchase_invoices` with line items, `supplier_payments`.
- Inventory adjustments: `inventory_adjustments` with positive/negative qty changes.
- Three enums: `unit_condition` (new/used/open_box), `unit_status` (in_stock/sold/returned_to_supplier/written_off),
  `movement_type` (purchase/sale/return_in/return_out/adjustment/opening).
- Posting RPCs: `post_purchase_invoice` (creates inventory units or updates stock_balance, creates journal entry),
  `post_supplier_payment` (Dr Payable, Cr Cash), `post_inventory_adjustment` (Dr/Cr Inventory vs Adjustment expense).
- Helper functions: `app.calc_weighted_avg` for moving average, `app.update_stock_balance`, `app.get_inventory_account_id`.
- Full RLS on all 7 new tables, tenant isolation enforced.
- Security: revoked PUBLIC execute from app helper functions.
- Tests: 22 schema tests, 16 purchase tests, 12 inventory tests, 8 reconciliation tests (272 total pgTAP).

Checks: typecheck ✓, lint ✓, unit ✓, pgTAP ✓ (272 total).

Deferred to B4+: `purchase_returns` (purchase return flow), sales invoices, customer payments,
installment contracts, trade-ins.

## B2 — Master Data & Attachments (merged to `main`)

Delivered:

- Master data tables: categories, brands, products, customers, suppliers, cash_accounts,
  expense_categories, partners, plan_templates with full RLS and audit logging.
- Unified attachment system: attachments table with owner_type/kind/status flow, role-based
  view/upload permissions, signed URL generation with audit, supersede functionality.
- Auto GL account creation: cash accounts create sub-accounts under 1100, expense categories
  create accounts under 6xxx, partners create 3 accounts (capital/current/drawings).
- Phone validation: Egyptian format `01[0125]XXXXXXXX`, national ID 14 digits.
- Partner share validation: total cannot exceed 100% (10000 basis points).
- Seeded defaults: categories (6), brands (12).
- Tests: 54 new pgTAP assertions (T26-T30 attachment tests pass).

Checks: typecheck ✓, lint ✓, unit ✓, pgTAP ✓ (212 total).

Deferred to B3+: inventory units, stock movements, purchase/sales invoices, actual file upload
Edge Function, storage bucket creation.

## B1 — Tenancy & Ledger Core (merged to `main`)

Delivered:

- Tenant isolation: `tenants`, `memberships` with 5 roles (owner/manager/cashier/collector/accountant),
  tenant bootstrap operation with atomic user + membership + chart seeding, RLS on all 9 B1 tables.
- Chart of accounts: `accounts` with Section 7.1 seed (33 accounts, 26 system keys), hierarchy support,
  header/active flags, tenant-scoped uniqueness.
- Append-only ledger: `journal_entries` and `journal_lines` with immutability guards, deferred balance
  trigger, exact bigint piaster storage, dimension placeholders for B2+ entities.
- Gapless numbering: `document_counters` with tenant/type/year partitions, row-locked counter allocation,
  rollback-safe increments.
- Idempotency: `posting_requests` with SHA-256 payload fingerprint, completed-result replay, mismatched
  payload rejection.
- Reversal: internal `app.reverse_journal_entry` primitive with exact line mirroring, bidirectional links,
  single-reversal constraint, reason audit.
- Lock dates: tenant-level `lock_date` with owner-only management, posting/reversal rejection for locked
  periods.
- Audit: `audit_log` with actor/action attribution, immutability guard, owner/accountant visibility only,
  no secret values.
- Vault references: `tenant_secret_refs` with typed kind enum, owner-only management, one row per
  tenant/kind, no plaintext storage.
- Security: schema `app` for internal functions with execute revoked, 4 explicit `public` wrappers
  (`bootstrap_tenant`, `manage_membership`, `set_lock_date`, `manage_tenant_secret_ref`), fixed
  `search_path`, security-definer definitions.
- Generated types: `src/types/database.ts` from local schema.
- Tests: 158 pgTAP assertions covering schema, security, bootstrap, RLS, management, ledger posting,
  invariants, idempotency, counters, lock dates, reversal, audit, and vault refs; 206 unit tests passing.

Checks: typecheck ✓, lint ✓, unit ✓, pgTAP ✓. E2E not applicable (no UI changes). B1 reconciliation
proves journal balance and reversal net-zero from `journal_lines`.

Deferred to B2+: categories, brands, products, customers, suppliers, partners, cash accounts, expense
categories, installment templates, sales/purchase invoices, document postings, full document reversal,
reports, dashboards.

B2 entry obligations:
1. Extend bootstrap with default cash account, expense categories, and installment plan templates when
   their tables exist.
2. Implement full document reversal RPCs that compose ledger reversal with stock/subledger corrections.
3. Add B2 table RLS and T19 cross-tenant tests.

## B0 — Foundation (branch `001-b0-foundation`, merged to `main`)

Delivered:

- Next.js 14.2.35 App Router shell: TypeScript `strict` + `noUncheckedIndexedAccess`, Tailwind CSS v3,
  shadcn/ui configuration with an RTL `DirectionProvider`, `<html lang="ar" dir="rtl">`, IBM Plex Sans
  Arabic. The only page shows `APP_NAME.ar` from `src/config/app.ts`.
- `src/lib/money.ts`: signed-64-bit `bigint` piasters, strict Arabic/Western input parser with approved
  Arabic messages, `20,000.00 ج.م` formatter (negative and Arabic-Indic variants), Section 8.2 rounding
  primitives, and decimal-string JSON wire helpers — 100% unit-test coverage.
- `src/lib/dates.ts`: Africa/Cairo business dates, strict civil-year `0001`–`9999` validation, and
  millisecond-exact day ranges across modern DST and historical offsets — 100% coverage, tested under
  three machine time zones.
- Local Supabase configuration (no migrations, seeding disabled), a pgTAP harness, a five-job GitHub
  Actions gate (typecheck, lint, unit, pgTAP, Playwright smoke), repository guards (agent rules, product
  name, no migrations), and identical `CLAUDE.md` / `AGENTS.md` carrying Section 18.

Checks: see the B0 batch report. Seeded-scenario reconciliation and Section 14 T01–T30 are not
applicable in B0 (no ledger exists).

Deferred (not built in B0): `src/lib/supabase/*`, `src/lib/rpc/*`, `src/schemas/*`,
`src/types/database.ts`, `supabase/seed.sql`, `(auth)`/`(app)` routes, `lucide-react` and shadcn
components, `docs/ACCOUNTING.md`.

B1 entry obligations (from `docs/DECISIONS.md`):

1. Financial database reads and RPC results expose monetary values as text before JSON decoding,
   with a documented adapter and DB-path round-trip tests (D-B0-03 / amended Rule 3).
2. Install a container runtime and free disk on the builder machine so pgTAP and Playwright run
   locally (D-B0-09).
3. Perform the local clean-machine walkthrough of the documented setup (D-B0-11).
4. Create `docs/ACCOUNTING.md` and keep it in sync in later posting batches (D-B0-08).
