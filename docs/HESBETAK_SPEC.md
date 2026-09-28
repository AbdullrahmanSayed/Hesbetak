# Hesbetak (حسبتك) — Master Build Specification

> **Audience:** coding agents (Claude Code, Codex) and the human reviewer (Abdullrahman).
> **Status:** Source of truth. If code and this document disagree, this document wins until it is explicitly amended.
> **Product name:** Hesbetak — حسبتك. It lives in ONE place: `src/config/app.ts → APP_NAME = { en: "Hesbetak", ar: "حسبتك" }`. Never hardcode the name anywhere else (UI, prints, emails, metadata all read from this constant).

---

## 0. How agents must use this document

1. Read this file fully before writing any code. Re-read the relevant section before each batch.
2. Work **batch by batch** (Section 17). Do not start a batch before the previous batch's Definition of Done passes and is reviewed.
3. Never invent features, tables, or accounting rules not in this spec. If something is ambiguous, stop, write the question and your proposed answer in `docs/DECISIONS.md`, and implement only after it is confirmed.
4. **Financial correctness beats everything** — speed, UI polish, and cleverness come after. The previous version of this product failed because reports were wrong and inconsistent. That must never happen again.
5. `CLAUDE.md` and `AGENTS.md` at the repo root must both contain Section 18 (Agent Rules) verbatim, so both agents follow identical rules.

---

## 1. Product overview

### 1.1 What it is
A multi-tenant SaaS web app for **Egyptian electrical-appliance showrooms** (معارض الأجهزة الكهربائية) that sell **cash (كاش)** and **deferred/installment (آجل / تقسيط)**. It replaces the paper notebook (الدفتر) with a system that tracks sales, installments, collections, inventory, purchases, suppliers, cash, expenses, and partners' capital — with **accounting that is always correct**.

### 1.2 Target customer (ICP)
- Small/medium, single-branch showrooms in Egypt (fridges, washing machines, TVs, ACs, water heaters, small appliances).
- Owner-operated or 1–5 staff. The owner is **not an accountant**.
- Uses mostly cash, some mobile wallets (Vodafone Cash, InstaPay), sometimes a bank account.
- Biggest pains: losing track of who owes what, late installments, not knowing real profit, cash drawer mismatches.

### 1.3 Product principles
- **Simple on the surface, correct underneath.** The owner sees "بيع كاش / بيع قسط / تحصيل / مصروف". The system silently posts correct double-entry journal entries.
- **Every number traces back to the ledger.** Every report can be drilled down to the journal entries that produced it.
- **Nothing is ever deleted or edited in place.** Corrections happen by reversal.
- **Arabic-first, RTL, mobile-friendly.** Collectors use phones in the field; the cashier uses a desktop with a thermal printer.

### 1.4 Legal framing of installments (non-negotiable)
The showroom sells goods at a **fixed deferred sale price (سعر آجل)** — it is a merchant deferred sale, **not a loan**.
- The UI, printed contract, receipts, and customer messages **never** show an interest rate, "فائدة", APR, or percentage on the customer side.
- Internally the markup is stored as a *plan factor* used only to compute the deferred price.
- The printed installment contract must clearly state: cash price, total deferred price, down payment, number of installments, each installment amount and due date, and the early-settlement terms (Consumer Protection Law 181/2018 requires clear installment disclosures and gives the buyer an early-repayment right). The contract template text must be reviewed by a lawyer before production use; the system provides the fields and layout.

---

## 2. Non-negotiable engineering principles

| # | Principle | Enforcement |
|---|-----------|-------------|
| P1 | **Double-entry ledger is the single source of truth** for every financial number | Reports query `journal_lines` only. No report recomputes money from documents. |
| P2 | **Every journal entry balances** (Σ debit = Σ credit) | Deferred constraint trigger on `journal_lines` per entry; posting function asserts before commit. |
| P3 | **Append-only financial data** | No `UPDATE`/`DELETE` on posted documents or journal rows. Revoked at the DB privilege level + trigger guard. Corrections = reversal entry + new entry. |
| P4 | **Money is integer piasters (`bigint`)** | 1 EGP = 100 piasters. No `float`, no `numeric` arithmetic in JS. Formatting only at the UI edge. |
| P5 | **All financial writes go through Postgres functions (RPC)** in a single transaction | Client never inserts into financial tables directly. RLS denies direct writes. |
| P6 | **Idempotent posting** | Every posting RPC takes `p_request_id uuid`; unique per tenant; a retry returns the original result. |
| P7 | **Tenant isolation** | Every tenant-scoped table has `tenant_id` + RLS. Tested with automated cross-tenant tests. |
| P8 | **Subledger ↔ GL reconciliation** | Installment, inventory, customer, supplier subledgers must equal their control accounts. A reconciliation report flags any difference; a difference is a P0 bug. |
| P9 | **Period locking** | Postings dated on or before the tenant's `lock_date` are rejected. |
| P10 | **Business dates are Cairo dates** | Stored as `date`; timestamps as `timestamptz`; business day computed in `Africa/Cairo`. |
| P11 | **Gapless document numbers** per tenant, per document type, per year | Counter table with row lock inside the posting transaction. |
| P12 | **Full audit trail** | Every posting stores `created_by`, `created_at`, `request_id`; audit log for master-data changes. |

---

## 3. Tech stack

| Layer | Choice |
|-------|--------|
| Framework | Next.js 14 (App Router, Server Components, Server Actions) |
| Language | TypeScript `strict: true`, `noUncheckedIndexedAccess: true` |
| UI | Tailwind CSS + shadcn/ui, RTL via `dir="rtl"` on `<html>`, font: IBM Plex Sans Arabic (Google Fonts) |
| Forms / validation | React Hook Form + Zod (same Zod schemas shared by client and server) |
| Tables | TanStack Table |
| Data fetching | Server Components + Server Actions; TanStack Query only for interactive client screens (POS, collections) |
| Database / Auth / Storage | Supabase (Postgres 15+, Supabase Auth, RLS, Storage for logos/attachments) |
| Business logic | PL/pgSQL functions (`SECURITY DEFINER`, fixed `search_path`) for all posting |
| Types | `supabase gen types typescript` → `src/types/database.ts` (never hand-edited) |
| Dates | `date-fns` + `date-fns-tz`, zone `Africa/Cairo` |
| Excel export | `exceljs` |
| PDF / print | HTML print templates with print CSS (80mm thermal + A4) |
| Testing | Vitest (unit), pgTAP (database functions), Playwright (E2E) |
| Hosting | Vercel (app) + Supabase (DB) |
| CI | GitHub Actions: typecheck, lint, unit, pgTAP against local Supabase, Playwright smoke |
| Later phases | n8n + WhatsApp Business API + Claude API (Section 16) |

### 3.1 Repository structure
```
/
├─ CLAUDE.md                 # = Section 18
├─ AGENTS.md                 # = Section 18 (identical)
├─ docs/
│  ├─ HESBETAK_SPEC.md       # this file
│  ├─ DECISIONS.md           # questions + confirmed decisions, dated
│  └─ ACCOUNTING.md          # generated from Sections 7–8, kept in sync
├─ supabase/
│  ├─ migrations/            # timestamped, never edited after applied
│  ├─ seed.sql               # dev seed: demo tenant, products, customers
│  └─ tests/                 # pgTAP tests (*.test.sql)
├─ src/
│  ├─ app/
│  │  ├─ (auth)/login, (auth)/signup
│  │  └─ (app)/[tenant]/     # dashboard, pos, sales, installments, collections,
│  │                         # customers, suppliers, purchases, inventory,
│  │                         # treasury, expenses, partners, reports, settings, audit
│  ├─ components/ui/         # shadcn
│  ├─ components/            # feature components
│  ├─ config/app.ts          # APP_NAME, defaults
│  ├─ lib/money.ts           # piaster helpers (parse/format), no floats
│  ├─ lib/dates.ts           # Cairo business date helpers
│  ├─ lib/supabase/          # server/client factories
│  ├─ lib/rpc/               # typed wrappers around posting RPCs
│  ├─ schemas/               # Zod schemas
│  └─ types/database.ts      # generated
└─ tests/e2e/                # Playwright
```

---

## 4. Glossary (Arabic UI term → meaning → internal name)

| UI (Arabic) | Meaning | Internal |
|-------------|---------|----------|
| سعر الكاش | Cash price of an item | `cash_price` |
| سعر الآجل | Total deferred price the customer pays under an installment plan | `deferred_price` |
| المقدم | Down payment | `down_payment` |
| القسط | One scheduled installment | `installment` |
| نظام التقسيط | Installment plan template (months + factor) | `installment_plan_template` |
| فرق الآجل | Deferred margin = deferred price − cash price | `deferred_margin` |
| تحصيل | Collection of money from a customer | `receipt` |
| مرتجع | Return | `sales_return` / `purchase_return` |
| فسخ عقد | Cancellation of an installment contract | `contract_cancellation` |
| سداد مبكر | Early settlement | `early_settlement` |
| إعادة جدولة | Rescheduling | `reschedule` |
| إعدام دين | Bad-debt write-off | `write_off` |
| خزنة | Cash box / cash account | `cash_account` |
| وردية | Cash shift | `cash_shift` |
| جاري الشريك | Partner current account | `partner_current` |
| مسحوبات | Owner/partner drawings | `drawings` |
| بضاعة مستعملة / استبدال | Used / trade-in unit bought from a customer | `trade_in` |
| متأخرات | Overdue amounts | `overdue` |

---

## 5. Tenancy, users, roles

### 5.1 Tenancy
- `tenants`: one showroom = one tenant. Fields: name, legal name, phone(s), address, logo, tax number (optional), settings JSON (validated by Zod), `lock_date`, `created_at`.
- `memberships`: `(tenant_id, user_id, role, is_active)`. A user may belong to multiple tenants; the URL segment `[tenant]` selects the active one (slug).
- RLS helper: `app.is_member(tenant_id)` and `app.has_role(tenant_id, roles[])` — `STABLE`, `SECURITY DEFINER`.
- Signup flow: user signs up → creates tenant → becomes `owner` → chart of accounts, default cash account, default expense categories, and default installment plan templates are seeded by `app.bootstrap_tenant(...)`.
- Subscription billing is **out of scope for MVP** (handled manually); keep `tenants.plan` and `tenants.status` (`trial | active | suspended`) columns. Suspended tenants are read-only.

### 5.2 Roles and permissions

| Capability | owner | manager | cashier | collector | accountant |
|------------|:-:|:-:|:-:|:-:|:-:|
| POS: cash sale | ✓ | ✓ | ✓ | – | – |
| Installment sale | ✓ | ✓ | ✓ | – | – |
| Record collection | ✓ | ✓ | ✓ | ✓ (assigned customers only) | – |
| See cost prices / profit | ✓ | ✓ | – | – | ✓ |
| Returns, cancellations | ✓ | ✓ | – | – | – |
| Early settlement rebate beyond default | ✓ | – | – | – | – |
| Reschedule, write-off | ✓ | – | – | – | – |
| Purchases, supplier payments | ✓ | ✓ | – | – | – |
| Expenses | ✓ | ✓ | ✓ (up to limit in settings) | – | – |
| Partners capital / drawings | ✓ | – | – | – | – |
| Reports | ✓ | ✓ | daily closing only | own collections only | ✓ (read-only) |
| Settings, users, lock date | ✓ | – | – | – | – |
| Reverse any document | ✓ | ✓ (same business day only) | – | – | – |

Permissions are enforced **in the RPC functions** (authoritative) and mirrored in the UI (convenience).

---

## 6. Functional modules

### 6.1 Master data
- **Categories** (ثلاجات، غسالات، شاشات، تكييفات، سخانات، أجهزة صغيرة…) — seeded defaults, editable.
- **Brands** (Sharp, Toshiba, Samsung, LG, Fresh, Tornado, Kiriazi, Zanussi, Unionaire… — seeded list, editable).
- **Products**: name (Arabic), category, brand, model, barcode (optional, unique per tenant), `tracking` = `serial | quantity`, default cash price, min-stock alert, warranty months, active flag. Cost is **never** entered on the product; it comes from purchases.
- **Customers**: full name, phone 1 (required, Egyptian format `01[0125]XXXXXXXX`), phone 2, national ID (optional, 14 digits, validated), address, area, work/place, guarantor name/phone/national ID (optional — common in Egyptian installment practice), notes, assigned collector, `risk_flag`, ID card images for customer and guarantor (Section 6.15). Customers are never hard-deleted (archive only).
- **Suppliers**: name, phone, address, notes.
- **Cash accounts (خزن)**: name, type `cash | bank | wallet`, linked GL account (auto-created sub-account under 1100), active flag.
- **Expense categories**: linked to 6xxx GL accounts; seeded defaults.
- **Partners**: name, share % (sum must equal 100% for profit distribution), linked capital/current/drawings sub-accounts (auto-created).
- **Installment plan templates**: name, months, `factor_bp` (basis points; e.g. 4000 = 40%), `min_down_payment_bp`, active. The factor is applied to the **financed base** (cash price − down payment). Owner may override the total deferred price manually per contract (the system then back-computes the margin).

### 6.2 Inventory
- **Serial-tracked products** (all large appliances): every unit is a row in `inventory_units` with serial number, product, condition (`new | used | open_box`), status (`in_stock | sold | returned_to_supplier | written_off`), `unit_cost` (piasters), purchase document reference. A sale line must reference a specific unit. **Costing: specific identification.**
- **Quantity-tracked products** (accessories, small items): `stock_balances` per product with quantity and **moving weighted average cost**. Recalculated on every purchase receipt. Sales cannot drive quantity below zero.
- **Stock movements** table: every in/out with document reference, quantity, unit cost, reason.
- **Stock adjustments** (count differences, damage): posted via RPC, produce journal entries (Dr/Cr 5200 Inventory adjustments vs 13xx).
- Inventory subledger value must equal GL accounts 1310 + 1320 at all times (reconciliation, P8).

### 6.3 Purchases & suppliers
- Purchase invoice: supplier, date, supplier's invoice number, lines (product, qty or serials, unit cost), discount, paid now (from which cash account), remaining on supplier, supplier invoice images (Section 6.15).
- Purchase return: specific units / quantities, reduces inventory at their cost, reduces payable or receives cash.
- Supplier payment: amount, cash account, optional allocation to invoices (FIFO default).
- Supplier statement from ledger (2100 filtered by supplier dimension).

### 6.4 Sales — POS (cash sale)
- Fast screen: search by name/model/barcode/serial; add lines; per-line and invoice discount (discount permission-limited by settings); pick serial for serial products.
- Payment: one or more cash accounts (split payment, e.g. part cash, part InstaPay). Must equal net total — a cash sale is fully paid.
- Optional customer (walk-in allowed for cash sales).
- On post: document number, journal entry, stock out, COGS, print 80mm receipt and/or A4 invoice.

### 6.5 Installment sale (بيع بالتقسيط)
Flow:
1. Select customer (required; phone + address required for installment sales; guarantor optional per settings).
2. Add items at **cash price** (discount allowed).
3. Choose plan template (months + factor) or manual deferred price.
4. Enter down payment (≥ template minimum) and cash account receiving it.
5. Choose first due date (default: same day next month) and due-day rule.
6. System shows: cash price total, deferred price, down payment, remaining, number of installments, installment amount, full schedule. **No percentage is shown to the customer-facing screen or printouts.**
7. Post → contract number, journal entries, stock out, schedule rows, print contract (A4) + down-payment receipt.

Calculation rules (all integers, piasters) — see Section 8 for full math and rounding.

### 6.6 Collections (التحصيل)
- Search customer by name/phone/contract number; show open contracts, overdue amount, next due.
- Record receipt: amount, cash account, date, collector, optional note. The system **allocates automatically** (Section 8.4). The user may target a specific contract; default = oldest overdue first across the customer's contracts.
- Overpayment beyond all open installments → customer credit (2300), shown on the profile, usable in later receipts or refunded.
- Print receipt (80mm) showing: amount paid, installments covered, remaining balance, next due date.
- **Collector mode (mobile):** list of today's / overdue customers assigned to the collector, tap to call, WhatsApp reminder link, record receipt. Collector receipts go into the collector's own cash account ("عهدة المندوب") and are later transferred to the main cash box (treasury transfer).

### 6.7 Early settlement, reschedule, write-off, cancellation
- **Early settlement:** customer pays all remaining installments now. Owner applies a rebate on the **remaining unearned margin** (default rebate % from settings; above default requires owner role). See 7.3-E.
- **Reschedule:** the current open schedule is **frozen** (status `rescheduled`), and a new schedule for the outstanding balance is created with new count/dates. An optional additional margin may be added (owner only, posted as additional deferred margin). History is kept; nothing is edited.
- **Write-off:** owner writes off the remaining balance of a contract (customer unreachable). See 7.3-G. Customer gets `risk_flag = true`. Later recoveries are posted as other income (4900).
- **Cancellation / return of an installment sale (فسخ):** item comes back; owner enters the refund amount to the customer (may be zero). See 7.3-H.

### 6.8 Trade-in / buying used units from customers
- Purchase from customer: item description, product (optional), serial, condition `used`, agreed price, paid now / remaining owed to customer (2200).
- Can be applied as payment toward a sale or installment (offset): posts Dr 2200 / Cr receivable or cash-sale settlement.
- Unit enters inventory as `used` at the agreed price (1320).

### 6.9 Treasury (الخزنة)
- Cash accounts with running balances **from the ledger**.
- **Shifts (optional per settings):** open with counted balance → all movements → close with counted balance; difference is posted to 6900/4900 as cash over/short with mandatory note.
- **Transfers** between cash accounts (e.g., collector custody → main box, box → bank).
- **Expenses:** category, amount, cash account, date, note, receipt image via the attachment system (Section 6.15).
- **Daily closing report:** opening balance, all in/out by type, closing balance, per cash account.

### 6.10 Partners & capital
- Capital injection, capital withdrawal, drawings, and **profit distribution** by share %, each posted to the partner's own sub-accounts (capital / current / drawings).
- Year-end (or on-demand period) close: net profit → partners' current accounts by share %; drawings closed into current accounts. Negative current balance is allowed and shown clearly (partner overdrawn).
- Opening balances wizard for onboarding (Section 6.13).

### 6.11 Reports (all from the ledger — P1)
Every report: date range filter, cash-account/customer/supplier/category filters where relevant, Excel export, print view, drill-down to journal entries.

| Report | Source |
|--------|--------|
| Dashboard KPIs: today's sales (cash / installment), today's collections, overdue total, cash on hand, low stock | ledger + installment subledger for due dates |
| Daily closing (per cash account) | ledger 1100 lines |
| Sales report (cash vs installment, by product/category/brand/user) | ledger 4100/4150/4160 lines with document dimensions |
| Gross profit (by period/product/category) | 4100 − 4150 − 4160 − 5100 (+ 4200 shown separately as "أرباح الآجل المحققة") |
| Income statement (P&L) | 4xxx, 5xxx, 6xxx |
| Balance sheet | 1xxx, 2xxx, 3xxx + current-period profit |
| Trial balance | all accounts, must show Σ debit = Σ credit |
| Customer statement (كشف حساب عميل) | 1210 + 2300 + 2200 lines for customer |
| Supplier statement | 2100 lines for supplier |
| Installment aging (current, 1–30, 31–60, 61–90, 90+ days overdue) | installment subledger, reconciled total = 1210 |
| PAR30 (portfolio at risk: outstanding balance of contracts with any installment > 30 days overdue ÷ total outstanding) | installment subledger |
| Expected collections (next 7/30/90 days) | installment schedule |
| Collector performance | receipts by collector |
| Inventory valuation (by product, serial list with cost) | inventory subledger, reconciled total = 1310 + 1320 |
| Unearned margin balance (فرق آجل غير محقق) | 1215 |
| Expenses by category | 6xxx |
| Partners' equity statement | 3xxx sub-accounts |
| **Reconciliation report** | each subledger vs control account; difference must be 0 |

### 6.12 Settings
Business info, logo, receipt footer, default plan templates, minimum down payment, rounding step for installment amounts (1 / 5 / 10 EGP), default early-settlement rebate %, max cashier discount %, cashier expense limit, guarantor required toggle, attachment requirements (`require_customer_id_images`, `require_guarantor_id_images`, `require_signed_contract_upload`, `require_purchase_invoice_image`, `require_expense_receipt`), shifts toggle, lock date, users and roles, collector assignments.

### 6.13 Onboarding & opening balances
Wizard for existing showrooms moving from paper:
1. Opening inventory (serial units with cost; quantity items with qty + avg cost).
2. Existing customers with **open installment contracts**: remaining installments with amounts and due dates; the wizard splits each remaining installment into principal and margin using the contract's known cash price, or treats the full remaining balance as principal if margin is unknown (owner choice, recorded in the contract).
3. Supplier balances, cash balances, partners' capital.
All opening entries post against **3999 Opening Balance Equity** dated the go-live date; the wizard must end with 3999 reclassified to partners' capital by share %.
**Parallel run:** for the first client, run paper and system in parallel for at least 2 weeks and reconcile daily before switching off paper.

### 6.14 Audit
- Audit log UI: who did what, when, on which document; filter by user/date/type.
- Every document page shows its journal entry and any reversal.
- Every view or download of a sensitive attachment (Section 6.15) is logged.

### 6.15 Attachments & documents (unified system)
One attachment system serves every document type. Build it once (B2) and reuse it everywhere; no module implements its own upload logic.

**What can be attached**

| Owner type (`owner_type`) | Attachment kinds (`kind`) | Required? | View roles | Upload roles |
|---|---|---|---|---|
| `customer` | `national_id_front`, `national_id_back`, `other` | Setting `require_customer_id_images` (default ON for installment sales) | owner, manager | owner, manager, cashier |
| `guarantor` (stored on customer / contract snapshot) | `national_id_front`, `national_id_back` | Setting `require_guarantor_id_images` (default OFF) | owner, manager | owner, manager, cashier |
| `installment_contract` | `signed_contract`, `other` | Setting `require_signed_contract_upload` (default OFF; when ON, contract shows "pending signature upload" until attached) | owner, manager | owner, manager, cashier |
| `purchase_invoice` | `supplier_invoice` (multiple pages allowed), `other` | Setting `require_purchase_invoice_image` (default OFF) | owner, manager, accountant | owner, manager |
| `purchase_return` | `supplier_credit_note`, `other` | No | owner, manager, accountant | owner, manager |
| `supplier_payment` | `payment_proof` (receipt / transfer screenshot) | No | owner, manager, accountant | owner, manager |
| `expense` | `receipt` | Setting `require_expense_receipt` (default OFF) | owner, manager, accountant | owner, manager, cashier |
| `trade_in` | `unit_photo`, `seller_national_id_front`, `seller_national_id_back` | Seller ID ON by default (buying used goods requires identifying the seller) | owner, manager | owner, manager, cashier |

A cashier can upload a customer or guarantor ID image but **cannot view it after saving** (only a "uploaded ✓" indicator).

**Enforcement of "required"**: when a setting makes an attachment required, the posting RPC (`post_installment_sale`, `post_purchase_invoice`, `post_expense`, `post_trade_in`) rejects the posting unless the required attachments already exist in `attachments` with `status = 'active'` and are linked to the draft via `upload_session_id` (see flow below). The check happens in SQL, not only in the UI.

**Upload flow (draft → post)**
1. The form generates a `upload_session_id` (uuid) when it opens.
2. Files upload to Storage under `{tenant_id}/pending/{upload_session_id}/{uuid}.{ext}` and a row is inserted in `attachments` with `owner_type`, `kind`, `owner_id = null`, `upload_session_id`, `status = 'pending'` via RPC `register_attachment`.
3. The posting RPC receives `p_upload_session_id`, validates required kinds, sets `owner_id` to the created document id and `status = 'active'` in the same transaction.
4. The file is moved server-side to its final path `{tenant_id}/{owner_type}/{owner_id}/{uuid}.{ext}` by an Edge Function triggered after commit (path is stored on the row; the move is idempotent).
5. A scheduled cleanup deletes `pending` attachments older than 24 hours (row + object).
6. Attachments on already-posted documents (e.g., uploading the signed contract later, a missing supplier invoice page) use `attach_to_document(owner_type, owner_id, kind, file)` directly with `status = 'active'`.

**Storage buckets** (all **private**, no public URLs ever)

| Bucket | Contents |
|---|---|
| `tenant-branding` | Logo, receipt header image. Readable by any member of the tenant. |
| `customer-documents` | Customer, guarantor, trade-in seller ID images; signed contracts. |
| `business-documents` | Supplier invoices, credit notes, payment proofs, expense receipts, trade-in unit photos. |

- Storage RLS policies check that the first path segment equals a tenant the user is a member of **and** that the user's role is allowed for the `owner_type` segment (via `app.can_view_attachment(tenant_id, owner_type)` / `app.can_upload_attachment(...)`).
- Viewing: the app requests a **signed URL valid for 300 seconds** through RPC `get_attachment_url(attachment_id)`, which checks permission and writes an `audit_log` row (`action = 'attachment_viewed'`). The client never builds storage paths itself.

**File rules**
- Allowed: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`. Anything else rejected (checked by MIME sniffing in the Edge Function, not only by extension).
- Max 10 MB per file before processing. Images are resized client-side to max 2000 px on the long edge and re-encoded as WebP (quality 0.8) before upload; EXIF metadata (including GPS) is stripped.
- Mobile: the upload control opens the camera directly (`capture="environment"`) so the cashier/collector can photograph the ID card or invoice on the spot.
- Max 10 files per document.

**Deletion & retention**
- Attachments on posted documents are **never hard-deleted by users**. "Remove" sets `status = 'superseded'` with a reason and who did it (owner/manager only); the object remains for audit.
- When a document is reversed, its attachments stay linked to it.
- Tenant data export (Section 12) includes all attachments in a ZIP organized by document type.

**Schema**
```
attachments (
  id uuid pk,
  tenant_id uuid not null,
  owner_type text not null,          -- enum values from the table above
  owner_id uuid null,                -- null while pending
  kind text not null,
  upload_session_id uuid null,
  bucket text not null,
  object_path text not null,
  mime_type text not null,
  size_bytes int not null,
  original_filename text null,
  status text not null,              -- pending | active | superseded
  superseded_reason text null,
  superseded_by uuid null,
  created_by uuid not null,
  created_at timestamptz not null default now()
)
index (tenant_id, owner_type, owner_id)
index (tenant_id, upload_session_id) where status = 'pending'
```
Direct INSERT/UPDATE/DELETE on `attachments` is revoked from `authenticated`; only the RPCs above write to it.

### 6.16 Secrets (Supabase Vault)
- Not used by MVP features, but the structure is created in B1 so later phases do not change the security model.
- Per-tenant secrets (WhatsApp Business API token, n8n webhook secrets, optional per-tenant LLM keys) are stored in **Supabase Vault**; the tenant row stores only the Vault secret id.
- Secrets are read only inside `SECURITY DEFINER` functions or Edge Functions using the service role. They are never returned to the browser, never logged, and never stored in `tenants.settings`.
- Platform-level secrets (Supabase service role key, Claude API key) live in Vercel / Supabase environment variables, not in the database.

---

## 7. Accounting design

### 7.1 Chart of accounts (seeded per tenant; `system_key` used by code, never the code number)

| Code | Name (AR) | Name (EN) | Type | Normal | system_key |
|------|-----------|-----------|------|--------|-----------|
| 1100 | النقدية وما في حكمها | Cash & equivalents (header) | asset | Dr | — |
| 1110 | الخزنة الرئيسية | Main cash box | asset | Dr | `cash_main` |
| 11xx | خزن/بنوك/محافظ إضافية | Additional cash accounts (auto sub-accounts) | asset | Dr | — |
| 1210 | أقساط مستحقة على العملاء | Installment receivable (gross) | asset | Dr | `installment_receivable` |
| 1215 | فرق آجل غير محقق | Unearned deferred margin (contra-asset) | asset (contra) | Cr | `unearned_margin` |
| 1300 | المخزون | Inventory (header) | asset | Dr | — |
| 1310 | مخزون بضاعة جديدة | Inventory — new | asset | Dr | `inventory_new` |
| 1320 | مخزون بضاعة مستعملة | Inventory — used/trade-in | asset | Dr | `inventory_used` |
| 1400 | دفعات مقدمة للموردين | Supplier advances | asset | Dr | `supplier_advances` |
| 1500 | أصول ثابتة | Fixed assets (manual, out of MVP depreciation) | asset | Dr | `fixed_assets` |
| 2100 | الموردون | Accounts payable — suppliers | liability | Cr | `accounts_payable` |
| 2200 | مستحق لعملاء (استبدال) | Payable to customers (trade-in) | liability | Cr | `payable_customers` |
| 2300 | أرصدة دائنة للعملاء | Customer credit balances / advances | liability | Cr | `customer_credit` |
| 3100 | رأس مال الشركاء | Partners' capital (sub-account per partner) | equity | Cr | `partner_capital` |
| 3200 | جاري الشركاء | Partners' current (sub-account per partner) | equity | Cr | `partner_current` |
| 3300 | مسحوبات الشركاء | Partners' drawings (sub-account per partner) | equity | Dr | `partner_drawings` |
| 3900 | أرباح مرحلة | Retained earnings | equity | Cr | `retained_earnings` |
| 3999 | أرصدة افتتاحية | Opening balance equity | equity | Cr | `opening_equity` |
| 4100 | المبيعات | Sales revenue (at cash price) | revenue | Cr | `sales` |
| 4150 | مردودات المبيعات | Sales returns (contra) | revenue | Dr | `sales_returns` |
| 4160 | خصم مسموح به | Sales discounts (contra) | revenue | Dr | `sales_discounts` |
| 4200 | أرباح الآجل المحققة | Earned deferred margin | revenue | Cr | `earned_margin` |
| 4300 | غرامات تأخير | Late fees (disabled by default) | revenue | Cr | `late_fees` |
| 4900 | إيرادات أخرى | Other income (cancellation retention, recoveries, cash over) | revenue | Cr | `other_income` |
| 5100 | تكلفة البضاعة المباعة | Cost of goods sold | expense | Dr | `cogs` |
| 5200 | فروقات مخزون | Inventory adjustments / shrinkage | expense | Dr | `inventory_adjustments` |
| 6100 | إيجار | Rent | expense | Dr | — |
| 6200 | مرتبات | Salaries | expense | Dr | — |
| 6300 | كهرباء ومياه | Utilities | expense | Dr | — |
| 6400 | نقل وتوصيل | Transport & delivery | expense | Dr | — |
| 6500 | دعاية وإعلان | Marketing | expense | Dr | — |
| 6600 | ديون معدومة | Bad debt expense | expense | Dr | `bad_debt` |
| 6900 | مصروفات متنوعة | Miscellaneous (incl. cash short) | expense | Dr | `misc_expense` |
| 6950 | خسائر فسخ عقود | Contract cancellation losses | expense | Dr | `cancellation_loss` |

**Dimensions on every journal line** (nullable columns): `customer_id`, `supplier_id`, `partner_id`, `contract_id`, `product_id`, `category_id`, `cash_account_id`, `user_id`. Reports filter by dimensions; balances are always sums of lines.

VAT is **out of scope for MVP** (most target showrooms are not VAT-registered). The schema keeps room for a `2500 VAT payable` account; do not implement VAT logic until specified.

### 7.2 Journal structure
- `journal_entries`: id, tenant_id, entry_no (gapless), entry_date (Cairo business date), source_type, source_id, description, reverses_entry_id (nullable), reversed_by_entry_id (nullable), request_id, created_by, created_at.
- `journal_lines`: id, entry_id, tenant_id, account_id, debit bigint ≥ 0, credit bigint ≥ 0, exactly one of them > 0, dimensions…, memo.
- A **reversal** entry mirrors every line (debit ↔ credit), same dimensions, dated the reversal date (not the original date, unless the original is still in an open period and the owner chooses same-date).

### 7.3 Posting rules per event

Notation: amounts in EGP for readability; stored in piasters.
Running example: fridge, unit cost **16,000**, cash price **20,000**, plan 10 months, factor 40%, down payment **5,000**.
Financed base = 20,000 − 5,000 = 15,000 → margin = 15,000 × 40% = **6,000** → deferred price = **26,000** → receivable after down payment = **21,000** → 10 installments of **2,100** (principal 1,500 + margin 600 each).

**A. Cash sale** (cash price 20,000, cost 16,000, paid to main box)
```
Dr 1110 Cash                      20,000
   Cr 4100 Sales                          20,000
Dr 5100 COGS                      16,000
   Cr 1310 Inventory — new                16,000
```
With a discount of 500: Dr 1110 19,500, Dr 4160 500, Cr 4100 20,000 (sales always at gross cash price; discount separate).

**B. Installment sale** (at contract posting)
```
Dr 1110 Cash (down payment)        5,000
Dr 1210 Installment receivable    21,000
   Cr 4100 Sales (cash price)             20,000
   Cr 1215 Unearned margin                 6,000
Dr 5100 COGS                      16,000
   Cr 1310 Inventory — new                16,000
```
Net receivable shown on balance sheet = 1210 − 1215 = 15,000 (= unpaid cash-price principal).

**C. Installment collection** (one full installment 2,100)
```
Dr 1110 Cash                       2,100
   Cr 1210 Installment receivable          2,100
Dr 1215 Unearned margin              600
   Cr 4200 Earned deferred margin            600
```
Margin is recognized **as collected**, per the principal/margin split fixed on each schedule row (Section 8.4). This is conservative and keeps 4200 exactly equal to margin actually received in cash.

**D. Overpayment beyond all open installments** → excess: Dr cash / Cr 2300 customer credit. Later use: Dr 2300 / Cr 1210 (+ margin recognition as in C).

**E. Early settlement** (after 4 installments paid; remaining 6 × 2,100 = 12,600 = principal 9,000 + margin 3,600; rebate 50% of remaining margin = 1,800; customer pays 10,800)
```
Dr 1110 Cash                      10,800
   Cr 1210 Installment receivable         10,800
Dr 1215 Unearned margin            1,800
   Cr 4200 Earned deferred margin          1,800
Dr 1215 Unearned margin            1,800
   Cr 1210 Installment receivable          1,800
```
After: 1210 and 1215 for this contract = 0.

**F. Reschedule** — no journal entry unless additional margin is added. Additional margin M: Dr 1210 M / Cr 1215 M. Old schedule rows are frozen; new rows carry the outstanding principal and margin (plus M).

**G. Write-off** (after 4 installments paid: receivable 12,600, unearned 3,600)
```
Dr 6600 Bad debt expense           9,000
Dr 1215 Unearned margin            3,600
   Cr 1210 Installment receivable         12,600
```
Later recovery of X: Dr cash X / Cr 4900 X.

**H. Installment contract cancellation (فسخ)** with item returned
Let C = cash price (after discount) = 20,000, P = total paid by customer so far, Mr = margin already recognized, B = outstanding receivable, U = outstanding unearned margin, R = refund to customer (entered by owner, 0 ≤ R ≤ P).
Balancing amount **X = P − R − Mr**. If X > 0 → Cr 4900 (retained). If X < 0 → Dr 6950 (loss).
Example: down 5,000 + 2 installments (4,200) → P = 9,200, Mr = 1,200, B = 16,800, U = 4,800, refund R = 7,000 → X = 1,000.
```
Dr 4150 Sales returns             20,000
Dr 1215 Unearned margin            4,800
   Cr 1210 Installment receivable         16,800
   Cr 1110 Cash (refund)                   7,000
   Cr 4900 Other income                    1,000
Dr 1310 Inventory (restock at original cost)  16,000
   Cr 5100 COGS                           16,000
```
If the unit returns damaged, the owner enters restock value V < cost: Dr 13xx V, Dr 5200 (cost − V), Cr 5100 cost. Restocked unit condition becomes `used` or `open_box` (→ 1320 when `used`).

**I. Cash sale return** (full): Dr 4150 20,000 / Cr cash 20,000; Dr 1310 16,000 / Cr 5100 16,000. Partial returns by line/unit. Discounts are reversed proportionally (Dr 4150 at gross, Cr 4160 for the discount part).

**J. Purchase from supplier on credit** (2 units at 16,000, paid 10,000 now)
```
Dr 1310 Inventory — new           32,000
   Cr 1110 Cash                           10,000
   Cr 2100 Accounts payable               22,000
```
**K. Supplier payment**: Dr 2100 / Cr cash. Payment before invoice: Dr 1400 / Cr cash, later offset.
**L. Purchase return**: Dr 2100 (or cash) / Cr 1310 at the unit's cost.

**M. Trade-in purchase from customer** (used unit agreed 3,000, paid 1,000)
```
Dr 1320 Inventory — used           3,000
   Cr 1110 Cash                            1,000
   Cr 2200 Payable to customers            2,000
```
Offset against their installment: Dr 2200 / Cr 1210 (+ margin recognition as in C).

**N. Expense**: Dr 6xxx / Cr cash.
**O. Cash transfer**: Dr destination cash / Cr source cash.
**P. Shift difference**: short → Dr 6900 / Cr cash; over → Dr cash / Cr 4900.
**Q. Capital injection**: Dr cash / Cr 3100-partner. **Capital withdrawal**: Dr 3100-partner / Cr cash.
**R. Drawings**: Dr 3300-partner / Cr cash.
**S. Period profit close**: close 4xxx/5xxx/6xxx to 3900, then Dr 3900 / Cr 3200-partner by share %; close 3300-partner into 3200-partner.
**T. Inventory adjustment**: shortage Dr 5200 / Cr 13xx; surplus Dr 13xx / Cr 5200.
**U. Late fees** (feature flag, off by default): Dr 1210 / Cr 4300 when charged. Must be legally reviewed before enabling.

---

## 8. Installment math (exact, integer piasters)

### 8.1 Inputs
`cash_total` (after discount), `down_payment`, `months n`, `factor_bp` (or manual `deferred_price`), `rounding_step` (piasters: 100, 500, or 1000), `first_due_date`.

### 8.2 Computation
```
financed_base   = cash_total − down_payment                        (must be > 0)
margin_total    = round_half_up(financed_base × factor_bp / 10000)
   — if manual deferred_price: margin_total = deferred_price − cash_total (must be ≥ 0)
receivable      = financed_base + margin_total
base_amount     = ceil_to_step(receivable / n, rounding_step)
installments 1..n−1 = base_amount
installment n   = receivable − base_amount × (n − 1)               (must be > 0; if ≤ 0, reduce n or step — validation error)

principal_i     = floor(financed_base × amount_i / receivable)      for i = 1..n−1
margin_i        = amount_i − principal_i
principal_n     = financed_base − Σ principal_1..n−1
margin_n        = margin_total − Σ margin_1..n−1
```
Invariants (asserted in the RPC and pgTAP):
- Σ amount_i = receivable
- Σ principal_i = financed_base
- Σ margin_i = margin_total
- every amount_i, principal_i, margin_i ≥ 0

### 8.3 Due dates
Installment k due on `first_due_date + (k−1) months`. If the day does not exist in a month (e.g., 31), use the last day of that month. Stored per row; never recomputed.

### 8.4 Payment allocation (deterministic)
1. Order open installments: contract selection (targeted contract or all of the customer's contracts), then `due_date ASC`, then `installment_no ASC`.
2. For each installment, apply `min(remaining_payment, installment_outstanding)`.
3. Split the applied amount into margin/principal:
   - If the application **fully settles** the installment → margin part = the installment's outstanding margin exactly.
   - Else → `margin_part = floor(applied × margin_outstanding / installment_outstanding)`, principal part = applied − margin_part.
4. Record each application in `receipt_allocations` (receipt_id, installment_id, amount, principal_part, margin_part).
5. Excess after all open installments → customer credit (7.3-D).
6. Journal entry for the receipt: one Dr cash line, one Cr 1210 line (total applied), one Dr 1215 / Cr 4200 pair (Σ margin_part), and a Cr 2300 line for any excess.

### 8.5 Status & overdue
- Installment status: `pending | partially_paid | paid | frozen (rescheduled) | written_off | cancelled`.
- Overdue days = Cairo today − due_date, for rows with outstanding > 0 and due_date < today.
- Contract status: `active | settled | early_settled | rescheduled | written_off | cancelled`.

### 8.6 Worked test vector (must pass exactly)
cash_total = 2,000,000 pt (20,000 EGP), down = 500,000, n = 10, factor_bp = 4000, step = 100 pt
→ financed_base 1,500,000; margin_total 600,000; receivable 2,100,000; each amount 210,000; principal 150,000; margin 60,000.

Awkward vector: cash_total = 1,234,500, down = 200,000, n = 7, factor_bp = 3000, step = 500
→ financed_base 1,034,500; margin_total round_half_up(310,350) = 310,350; receivable 1,344,850; receivable/7 = 192,121.43 → base_amount 192,500; installments 1–6 = 192,500 (Σ 1,155,000); installment 7 = 189,850. Principal/margin per the formula; invariants in 8.2 must hold.

---

## 9. Database schema (core tables)

All tables: `id uuid pk default gen_random_uuid()`, `tenant_id uuid not null references tenants`, `created_at timestamptz default now()`, `created_by uuid`. Money columns `bigint`. Composite indexes start with `tenant_id`.

**Platform:** `tenants`, `memberships`, `tenant_settings` (or JSON on tenants), `document_counters (tenant_id, doc_type, year, last_no)`, `audit_log`.

**Master data:** `categories`, `brands`, `products`, `customers`, `suppliers`, `partners`, `cash_accounts`, `expense_categories`, `installment_plan_templates`, `accounts` (chart of accounts: code, name_ar, name_en, type, normal_side, parent_id, system_key, partner_id, cash_account_id, is_header, is_active).

**Inventory:** `inventory_units` (serial, product_id, condition, status, unit_cost, source_type/source_id), `stock_balances` (product_id, qty, avg_cost), `stock_movements`.

**Documents (immutable after posting; `status` = `posted | reversed`):**
- `sales_invoices` (doc_no, date, customer_id nullable, kind `cash | installment`, gross, discount, net, created_by) + `sales_invoice_lines` (product_id, unit_id nullable, qty, cash_price, discount, cost_snapshot)
- `sales_payments` (invoice_id, cash_account_id, amount)
- `installment_contracts` (doc_no, sales_invoice_id, customer_id, guarantor fields snapshot, cash_total, down_payment, financed_base, margin_total, receivable, months, factor_bp nullable, manual_price bool, first_due_date, status, parent_contract_id for reschedules)
- `installments` (contract_id, installment_no, due_date, amount, principal, margin, paid_amount, paid_principal, paid_margin, status)
- `receipts` (doc_no, date, customer_id, cash_account_id, amount, collector_id, targeted_contract_id nullable, note)
- `receipt_allocations`
- `early_settlements`, `reschedules`, `write_offs`, `contract_cancellations`
- `sales_returns` + lines
- `purchase_invoices` + lines, `purchase_returns` + lines, `supplier_payments`
- `trade_ins`
- `expenses`, `cash_transfers`, `cash_shifts`
- `partner_transactions` (type `capital_in | capital_out | drawing | profit_distribution`)
- `inventory_adjustments` + lines
- `reversals` (original doc type/id, reversal entry id, reason, created_by)

**Ledger:** `journal_entries`, `journal_lines` (Section 7.2).

**Idempotency:** `posting_requests (tenant_id, request_id unique, rpc_name, result jsonb)`.

**Attachments:** `attachments` (Section 6.15). **Secrets:** Vault references only (Section 6.16).

### 9.1 Database guards
- `REVOKE INSERT, UPDATE, DELETE` on all document and ledger tables from `authenticated`; only posting functions (owned by a privileged role) write.
- Trigger preventing UPDATE of posted rows except whitelisted status transitions performed by reversal functions (e.g., `posted → reversed`, installment paid counters updated only inside allocation functions).
- Deferred constraint trigger: each `journal_entry` balances and has ≥ 2 lines.
- Check: `entry_date > tenant.lock_date`.
- RLS SELECT policies: `app.is_member(tenant_id)`; role-restricted views for cost/profit data (cashier cannot select cost columns — expose via views without cost for that role).

### 9.2 Posting RPCs (each: one transaction, permission check, idempotency, validation, document number, stock movement, journal entry, return document id + number)
`post_cash_sale`, `post_installment_sale`, `post_receipt`, `post_early_settlement`, `post_reschedule`, `post_write_off`, `post_contract_cancellation`, `post_sales_return`, `post_purchase_invoice`, `post_purchase_return`, `post_supplier_payment`, `post_trade_in`, `post_expense`, `post_cash_transfer`, `open_shift`, `close_shift`, `post_partner_transaction`, `post_inventory_adjustment`, `post_period_close`, `post_opening_balances`, `reverse_document`, `register_attachment`, `attach_to_document`, `supersede_attachment`, `get_attachment_url`, `preview_installment_schedule` (pure, no writes — used by the UI so client and server share one calculation).

---

## 10. Reversal policy
- Any posted document can be reversed by allowed roles (Section 5.2) with a mandatory reason.
- Reversal creates the mirror journal entry, restores/re-removes stock, reverses allocations, and marks the document `reversed`.
- A contract with receipts cannot be reversed directly; reverse receipts first (latest first), or use cancellation (7.3-H).
- Documents in a locked period cannot be reversed; correct in the current period instead.

---

## 11. UI / UX requirements
- Arabic RTL everywhere; English UI toggle is **out of MVP**. Numbers displayed with Western digits by default (setting for Arabic-Indic digits). Currency format: `20,000.00 ج.م`.
- Keyboard-first POS: `/` focuses search, `Enter` adds, `F9` posts, `Esc` clears. Barcode scanner = keyboard wedge (fast input ending with Enter).
- Mobile-first collector screens (≥ 360 px), large tap targets, WhatsApp `wa.me/20XXXXXXXXXX` links with prefilled Arabic reminder text (no percentages, just amount due and date).
- Every destructive or financial action has a confirmation summary showing exactly what will be posted.
- Empty states and inline validation messages in clear Egyptian-friendly Arabic.
- Print templates: 80mm thermal receipt (cash sale, receipt, down payment), A4 invoice, A4 installment contract with schedule table and signature lines (buyer, guarantor, showroom), A4 customer statement.
- Dark mode not required for MVP.
- Premium, clean visual identity: neutral base, one strong accent color, generous spacing, consistent iconography (lucide).

---

## 12. Non-functional requirements
- **Performance:** POS search < 200 ms for 10k products; dashboard < 1.5 s; reports on 100k journal lines < 3 s (use indexes on `(tenant_id, account_id, entry_date)` and dimension columns; materialized summaries only if needed and always rebuildable from lines).
- **Security:** Supabase Auth (email + password; phone OTP later), RLS on every table, `SECURITY DEFINER` functions with `SET search_path = public, pg_temp`, input validation in Zod **and** in SQL, no service-role key in the browser, rate limiting on auth routes.
- **Backups:** Supabase daily backups + tenant-level Excel export of all data (owner only).
- **Observability:** server errors logged with tenant_id, user_id, request_id; posting failures surface a readable Arabic message and a support code.
- **Concurrency:** posting functions lock rows they depend on (`SELECT … FOR UPDATE` on inventory units, stock balances, installments, counters) to prevent double-selling a serial or double-allocating a payment.

---

## 13. Validation rules (highlights)
- Egyptian mobile: `^01[0125][0-9]{8}$`. National ID: 14 digits.
- Sale of a serial unit requires status `in_stock`; after posting → `sold`.
- Down payment ≥ template minimum; financed base > 0; months 1–60.
- Receipt amount > 0; collector can only receive for assigned customers.
- Discounts ≤ role limit.
- Posting date ≤ today (no future-dated postings) and > lock_date.
- Partner shares sum to 10000 bp before any profit distribution.

---

## 14. Acceptance tests (must be automated; pgTAP for DB, Playwright for flows)

Each test asserts: document created, journal balanced, account balances, subledger ↔ GL reconciliation = 0.

| ID | Scenario | Key expected result |
|----|----------|---------------------|
| T01 | Cash sale 20,000, cost 16,000 | 1110 +20,000; 4100 20,000; 5100 16,000; 1310 −16,000; unit `sold` |
| T02 | Cash sale with 500 discount | 4160 500; 1110 +19,500 |
| T03 | Installment sale (example in 7.3-B) | 1210 21,000; 1215 6,000; 10 rows of 2,100 (1,500/600) |
| T04 | Pay one installment 2,100 | 1210 18,900; 1215 5,400; 4200 600 |
| T05 | Partial payment 1,000 on a fresh installment | margin 285.71, principal 714.29; then 1,100 settles it with margin 314.29 |
| T06 | Payment 5,000 across installments | #1 and #2 paid, #3 partial 800 (margin 228.57) |
| T07 | Overpayment beyond all installments | excess in 2300; customer statement shows credit |
| T08 | Early settlement after 4 paid, 50% rebate | pays 10,800; 1210 = 0; 1215 = 0; 4200 total = 2,400 + 1,800 |
| T09 | Reschedule remaining 6 into 12 | old rows `frozen`; new 12 rows; Σ principal 9,000, Σ margin 3,600; no JE |
| T10 | Write-off after 4 paid | 6600 9,000; 1210 = 0; 1215 = 0 |
| T11 | Cancellation (7.3-H example) | 4900 1,000; unit back in stock; all contract balances 0 |
| T12 | Cash sale full return | revenue and COGS reversed; unit `in_stock` |
| T13 | Purchase on credit + supplier payment | 2100 balance correct; supplier statement matches |
| T14 | Weighted average cost (qty item: 10 @ 100, then 10 @ 130 → avg 115; sell 5 → COGS 575) | exact |
| T15 | Trade-in offset against installment | 2200 and 1210 reduced correctly, margin recognized |
| T16 | Posting on/before lock date | rejected with Arabic error |
| T17 | Same request_id posted twice | one document only; second call returns first result |
| T18 | Two cashiers sell the same serial concurrently | exactly one succeeds |
| T19 | Tenant A user queries tenant B data (every table, every RPC) | zero rows / permission error |
| T20 | Cashier requests cost/profit data | denied |
| T21 | Reverse a receipt | allocations undone; installment statuses restored; JE mirrored |
| T22 | Trial balance after full seed scenario | Σ debit = Σ credit; reconciliation report all zeros |
| T23 | Installment awkward vector (8.6) | all invariants hold |
| T24 | Period close with two partners 60/40, profit 10,000, drawings 2,000 for partner A | 3200-A = 6,000 − 2,000 = 4,000; 3200-B = 4,000 |
| T25 | Installment sale with `require_customer_id_images` ON and no ID images uploaded | posting rejected with Arabic error; nothing written |
| T26 | Cashier uploads customer ID image, then requests its URL | upload succeeds; `get_attachment_url` denied |
| T27 | Tenant A user requests signed URL / storage object of tenant B attachment | denied at RPC and Storage RLS level |
| T28 | Owner views a customer ID image | signed URL expires after 300 s; `audit_log` row `attachment_viewed` exists |
| T29 | Upload a `.exe` renamed to `.jpg` | rejected by MIME sniffing |
| T30 | Pending attachments older than 24 h | cleanup removes row and storage object; active ones untouched |

---

## 15. Out of scope for MVP
Any Python/FastAPI or other backend service besides Next.js + Supabase (see 16.6), VAT/e-invoicing (ETA integration), multi-branch, fixed-asset depreciation, payroll, English UI, native mobile apps, subscription billing automation, WhatsApp API sending, AI features, customer self-service portal, credit scoring.

---

## 16. Post-MVP roadmap (do not build now; design must not block it)
1. **WhatsApp reminders** via n8n + WhatsApp Business API: due-tomorrow, overdue, receipt confirmation (templates without any percentages).
2. **AI assistant (Claude API):** "ليه الربح قل الشهر ده؟" style questions answered from ledger queries through read-only, tenant-scoped SQL views; daily owner digest; collection prioritization.
3. **Multi-branch** (branch dimension on lines and inventory).
4. **VAT & ETA e-invoice** integration.
5. **Customer portal** (view schedule, pay via payment link).
6. **AI Service (Python / FastAPI)** — a separate service added only in this phase:
   - **Supplier invoice OCR:** photo of a supplier invoice → suggested purchase-invoice lines (product match, qty, unit cost).
   - **National ID OCR:** photo of an ID card → suggested customer name, national ID, address.
   - **AI assistant backend:** answers owner questions from read-only, tenant-scoped SQL views.
   - **Hard rule: the AI service reads and suggests only.** It returns suggested data to the UI; a human reviews it; posting still happens only through the Postgres posting functions. The service has no write access to any financial or document table (dedicated DB role with SELECT on approved views only).
   - Authentication: the service verifies the Supabase JWT of the calling user and derives `tenant_id` from it; it never trusts a tenant id sent in the request body.
   - Files are read from Storage via short-lived signed URLs issued by `get_attachment_url`, so permissions and audit logging stay in one place.

---

## 17. Build plan — batches with Definition of Done

Each batch ends with: all tests green in CI, `docs/DECISIONS.md` updated, a short `CHANGELOG.md` entry, and human review before the next batch.

| Batch | Scope | Definition of Done |
|-------|-------|-------------------|
| **B0 — Foundation** | Repo, Next.js 14, TS strict, Tailwind + shadcn RTL, Supabase local, CI, `lib/money.ts`, `lib/dates.ts`, CLAUDE.md/AGENTS.md | CI green; money helpers 100% unit-tested (parse/format/rounding) |
| **B1 — Tenancy & Ledger core** | tenants, memberships, roles, RLS helpers, bootstrap_tenant, chart of accounts seed, journal tables, balance trigger, lock date, counters, idempotency, reverse engine, Vault secret-reference structure (6.16) | T16 and T19 pass for B1 objects; idempotency is tested through the B1 journal test helper; a manual JE via test helper balances; unbalanced JE rejected. Full T17 with one posted document is required in B3. |
| **B2 — Master data + Attachments** | categories, brands, products, customers, suppliers, cash accounts, expense categories, partners, plan templates + UI; unified attachment system (6.15): buckets, storage RLS, RPCs, upload component with camera + resize, cleanup job | CRUD with validation; audit log entries; archive instead of delete; T26, T27, T28, T29, T30 pass |
| **B3 — Purchases & inventory** | purchase invoices/returns, supplier payments, serial units, weighted avg, stock movements, adjustments | T13 and full T17 pass; inventory reconciliation = 0; T14 purchase/weighted-average portion passes, and the complete T14 sale/COGS scenario is required in B4. |
| **B4 — Cash sales (POS)** | POS screen, split payments, discounts, receipts printing, cash returns | T01, T02, T12, T14, T18, T20 pass |
| **B5 — Installment sales** | preview_installment_schedule, contract posting with required ID attachments, signed-contract upload, contract print | T03, T23, T25 pass; UI never shows percentages to customer-facing views |
| **B6 — Collections lifecycle** | receipts + allocation, customer credit, collector mode, early settlement, reschedule, write-off, cancellation, trade-in, receipt reversal | T04–T11, T15, T21 pass |
| **B7 — Treasury & partners** | expenses, transfers, shifts, partner transactions, period close, opening balances wizard | T24 pass; daily closing matches ledger |
| **B8 — Reports** | all reports in 6.11 with Excel export + print + drill-down, reconciliation report | T22 pass; every report total equals trial-balance account totals |
| **B9 — Dashboard & polish** | KPIs, overdue lists, WhatsApp links, settings, audit UI, onboarding flow | Playwright E2E: signup → setup → purchase → cash sale → installment sale → collections → reports |
| **B10 — Hardening** | security review of every RPC + RLS policy, performance seed (100k lines), error messages, backup export | perf targets in Section 12 met; security checklist signed off |

**Go-live for the first client:** after B8 minimum, run parallel with paper for ≥ 2 weeks, reconcile daily, then switch.

---

## 18. Agent Rules (copy verbatim into CLAUDE.md and AGENTS.md)

1. This spec (`docs/HESBETAK_SPEC.md`) is the source of truth. Do not add features, tables, accounts, or rules not in it. Put open questions in `docs/DECISIONS.md` and wait for confirmation.
2. Work only on the current batch. Finish its Definition of Done before touching the next.
3. **Money:** integer piasters. SQL and TS money use `bigint` piasters (TS via `lib/money.ts`); financial JSON values are validated decimal strings; database monetary results become text before JSON decoding. Never use floating-point for money. Never do money arithmetic in React components.
4. **All financial writes go through Postgres posting functions.** Never insert/update financial tables from the client or from Server Actions directly.
5. **Never UPDATE or DELETE posted documents or journal rows.** Corrections are reversals.
6. **Reports read only from `journal_lines`** (and subledgers only for schedules/aging, which must reconcile to the GL).
7. Every posting function: permission check → idempotency check → validation → row locks → document number → stock → journal → assert balanced → return result.
8. Every new posting rule needs a pgTAP test with exact numbers before or together with the implementation.
9. Never edit an applied migration; create a new one. Regenerate `src/types/database.ts` after every migration.
10. Every table has `tenant_id` and RLS. Add a cross-tenant test for every new table and RPC.
11. Business dates use `Africa/Cairo`. Never use `new Date()` for business dates in the client; use `lib/dates.ts`.
12. Customer-facing UI, prints, and messages must never show interest, percentages, or "فائدة" for installment sales.
13. Arabic RTL UI; all user-facing strings in Arabic; code, identifiers, and comments in English.
14. TypeScript strict; no `any`; no `// @ts-ignore`; no disabled lint rules without a comment in DECISIONS.md.
15. Production-ready code only: no TODO stubs, no placeholder data in app code, no mock implementations outside tests and `seed.sql`.
16. Small, focused commits with conventional messages (`feat:`, `fix:`, `test:`, `db:`, `docs:`).
17. Before declaring a batch done: run typecheck, lint, unit, pgTAP, Playwright; run the reconciliation check on the seeded scenario; report results.
18. The MVP backend is Next.js + Supabase only (Postgres functions, Edge Functions). Do not add Python, FastAPI, or any other server/service. Image processing happens client-side and in Edge Functions (Section 6.15).
19. If two agents work in parallel, they work on separate branches and separate batches; DB migrations are only created on the branch owning the current DB batch.
