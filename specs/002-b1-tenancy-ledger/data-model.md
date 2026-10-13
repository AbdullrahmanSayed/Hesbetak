# Data Model: B1 — Tenancy & Ledger Core

**Date**: 2026-10-12 | **Plan**: [plan.md](./plan.md)

All tenant-owned tables use UUID primary keys, carry `tenant_id`, enforce RLS, and index tenant first. The root `tenants.id` is itself the tenant boundary. Timestamps are `timestamptz`; business dates are SQL `date`; money is signed PostgreSQL `bigint` piasters and never crosses JSON as a number.

## Enumerated values

| Type | Values |
|---|---|
| `membership_role` | `owner`, `manager`, `cashier`, `collector`, `accountant` |
| `tenant_status` | `trial`, `active`, `suspended` |
| `account_type` | `asset`, `liability`, `equity`, `revenue`, `expense` |
| `normal_side` | `debit`, `credit` |
| `secret_kind` | `whatsapp`, `n8n`, `llm` |
| `posting_request_status` | `processing`, `completed` |

## Tenant

**Table**: `tenants`

| Field | Rules |
|---|---|
| `id` | UUID primary key; tenant identity |
| `slug` | non-empty normalized slug, globally unique, immutable after bootstrap in B1 |
| `name` | required display name |
| `legal_name` | nullable |
| `phones` | text array, default empty |
| `address` | nullable |
| `logo_path` | nullable reference only; B1 creates no Storage object |
| `tax_number` | nullable |
| `settings` | JSON object only, default `{}`; no secret values or references |
| `plan` | required text, default `trial`; billing behavior out of scope |
| `status` | `trial` by default |
| `lock_date` | nullable Cairo business date; postings/reversals require entry date greater than it |
| `created_at` | immutable creation instant |
| `created_by` | required authenticated user UUID |

**RLS**: active members may select; owner-only update occurs through explicit operation. Suspended tenants remain readable but ordinary writes fail.

**State transitions in B1**: `trial ↔ active` and suspension management are platform/manual concerns outside browser operations. Lock date may move only through the owner operation and is audited.

## Membership

**Table**: `memberships`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK |
| `user_id` | required Auth user UUID |
| `role` | required `membership_role` |
| `is_active` | default true |
| `created_at` | immutable |
| `created_by` | required actor UUID |

**Uniqueness**: one membership per `(tenant_id, user_id)`.

**Invariants**: at least one active owner remains per tenant; non-owner users cannot manage memberships; inactive membership grants no access.

## Account

**Table**: `accounts`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK |
| `code` | required, unique per tenant |
| `name_ar` / `name_en` | required |
| `type` | required `account_type` |
| `normal_side` | required `normal_side` |
| `parent_id` | nullable account FK; parent must share tenant |
| `system_key` | nullable stable identifier, unique per tenant when present |
| `partner_id` | nullable UUID dimension placeholder; no B1 FK |
| `cash_account_id` | nullable UUID dimension placeholder; no B1 FK |
| `is_header` | default false; header accounts cannot receive lines |
| `is_active` | default true; inactive accounts cannot receive lines |
| `created_at` / `created_by` | immutable attribution |

**Seed**: exactly the Section 7.1 rows. Header rows have no `system_key`. Parent-child hierarchy follows the code families. System behavior never resolves an account by code.

## Journal Entry

**Table**: `journal_entries`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK |
| `entry_no` | positive `bigint`, gapless within tenant/year |
| `entry_date` | required Cairo business date |
| `source_type` | required non-empty identifier |
| `source_id` | required UUID |
| `description` | required non-empty text |
| `reverses_entry_id` | nullable self FK; unique when present |
| `reversed_by_entry_id` | nullable self FK; unique when present |
| `request_id` | required UUID |
| `created_by` | required actor UUID |
| `created_at` | immutable instant |

**Uniqueness**: `(tenant_id, request_id)` and `(tenant_id, year(entry_date), entry_no)`. A reversal cannot reverse another reversal. Bidirectional reversal links must agree.

**State**: no mutable posted status. Original → reversed is represented only by an internal guarded write of `reversed_by_entry_id`; a reversal entry is identified by `reverses_entry_id`.

## Journal Line

**Table**: `journal_lines`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK and must equal entry/account tenant |
| `entry_id` | required journal-entry FK |
| `account_id` | required active non-header account FK |
| `debit` / `credit` | `bigint` piasters, each ≥ 0, exactly one > 0 |
| dimensions | nullable UUID columns: `customer_id`, `supplier_id`, `partner_id`, `contract_id`, `product_id`, `category_id`, `cash_account_id`, `user_id` |
| `memo` | nullable text |
| `created_at` / `created_by` | immutable attribution |

**Entry invariant**: at least two lines and exact `sum(debit) = sum(credit)` at deferred constraint time. All mutation after insertion is forbidden.

## Document Counter

**Table**: `document_counters`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK |
| `doc_type` | required non-empty identifier |
| `year` | four-digit civil year 1–9999 |
| `last_no` | non-negative `bigint`; incremented only under row lock |
| `created_at` / `created_by` | attribution |

**Uniqueness**: `(tenant_id, doc_type, year)`.

## Posting Request

**Table**: `posting_requests`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK |
| `request_id` | caller UUID |
| `rpc_name` | required canonical operation name |
| `payload_hash` | lowercase SHA-256 hex of canonical request material |
| `status` | `processing` or `completed` |
| `result` | nullable JSON object; financial values must already be decimal strings |
| `created_at` / `created_by` | immutable attribution |
| `completed_at` | set only with completed result |

**Uniqueness**: `(tenant_id, request_id)`. A match on request id but mismatch on operation/hash is an error. Failed transactions leave no row.

## Audit Record

**Table**: `audit_log`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK |
| `actor_id` | required authenticated user UUID |
| `action` | required stable action identifier |
| `target_type` / `target_id` | required target identity |
| `before_data` / `after_data` | nullable sanitized JSON objects; no secret values |
| `request_id` | nullable UUID correlation |
| `created_at` | immutable instant |

Audit rows are append-only and readable only by roles allowed to inspect tenant administration (`owner`, `accountant`), with owner required for membership and lock changes.

## Tenant Secret Reference

**Table**: `tenant_secret_refs`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `tenant_id` | required tenant FK |
| `kind` | required `secret_kind` |
| `vault_secret_id` | required UUID reference identifier only |
| `created_at` / `created_by` | immutable attribution |

**Uniqueness**: `(tenant_id, kind)`. B1 exposes no secret-value resolver to browser roles. Reference management is owner-only and audited; browser reads must not expose the Vault value.

## Relationships

```text
tenants
├── memberships (user memberships)
├── accounts (self-parent hierarchy)
├── journal_entries
│   └── journal_lines ──> accounts
├── document_counters
├── posting_requests
├── audit_log
└── tenant_secret_refs ──> Vault identifier only

journal_entries <──reverses/reversed_by──> journal_entries
```

## Internal operations

| Operation | Contract |
|---|---|
| membership/role helpers | Stable, fixed-context checks against active memberships and tenant status |
| bootstrap tenant | authenticated user; one atomic tenant + owner + chart creation |
| set membership | owner-only; preserve final active owner; audit |
| set lock date | owner-only; tenant row lock; audit |
| begin/finish posting request | internal; operation/hash validation; row lock; canonical result |
| next document number | internal; row lock per tenant/type/year; rollback-safe |
| create journal entry | internal; validated tenant/accounts/date/lines; deferred balance |
| reverse journal entry | internal; permission supplied by orchestrator; lock original; mirror lines; guarded link update; audit |

## Money transport

Database monetary columns remain `bigint`. Any JSON result containing `debit`, `credit`, totals, or other money MUST build those values from SQL `::text`; generated TypeScript mappings do not authorize decoding financial JSON as `number`.
