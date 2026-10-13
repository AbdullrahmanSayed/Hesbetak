# Changelog

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
