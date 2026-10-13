# Implementation Plan: B1 — Tenancy & Ledger Core

**Branch**: `002-b1-tenancy-ledger` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-b1-tenancy-ledger/spec.md`

**Plan input (verbatim, `docs/SPECKIT_WORKFLOW.md` B1)**: "Implement the B1 schema and policies from Sections 5, 7, 9–10: tenants, memberships, RLS helpers and role checks, bootstrap_tenant, chart-of-accounts seed by system_key, journal_entries/journal_lines, deferred balance trigger, document counters with row locks, posting_requests, lock date, reversal engine, Vault secret references. SQL SECURITY DEFINER functions with fixed search_path; transaction-scoped permission/idempotency/locks and audit. Regenerate DB types after migration. Use pgTAP exact-number manual JE test helper, unbalanced rejection, locked-date rejection, idempotency harness, and per-existing-table/RPC cross-tenant tests. Do not add production manual financial-write endpoints."

## Summary

B1 creates the tenant and role security boundary and the append-only double-entry ledger used by every later financial batch. One forward-only migration adds tenant, membership, account, journal, counter, idempotency, audit, and typed Vault-reference structures; fixed-context functions enforce membership, role, suspension, lock dates, row-locked numbering, idempotency, balancing, and internal reversals. Browser roles receive no direct financial write privilege. pgTAP defines a transaction-local posting helper to prove exact piaster values, balance, isolation, concurrency-safe primitives, retries, locks, and reversals without introducing a production manual-journal endpoint. Database types are generated from the resulting local schema.

## Technical Context

**Language/Version**: PostgreSQL 17 SQL/PLpgSQL; TypeScript 5.9 with `strict` and `noUncheckedIndexedAccess`; Node.js 22 reference runtime

**Primary Dependencies**: Supabase CLI 2.118.0 and local Supabase Postgres; built-in Supabase Auth/JWT helpers; pgTAP; Supabase Vault; existing Next.js 14 application (no new runtime dependency required in B1)

**Storage**: Supabase PostgreSQL 17; one new forward-only migration; no seed file because B1 pgTAP creates isolated fixtures transactionally and production tenant bootstrap seeds per tenant

**Testing**: pgTAP through `npm run test:db`; existing Vitest regression suite; Playwright B0 smoke; TypeScript typecheck and ESLint; database reset/type-generation drift checks

**Target Platform**: Supabase-hosted PostgreSQL and local Docker-compatible Supabase; Next.js/Vercel remains the application platform but B1 adds no feature UI

**Project Type**: Single Next.js web application with Supabase as the only backend

**Performance Goals**: Permission helpers are index-backed; tenant bootstrap seeds one chart in one transaction; counter allocation serializes only one tenant/type/year row; ledger indexes support later `(tenant_id, account_id, entry_date)` reporting

**Constraints**: Integer `bigint` piasters only; database financial outputs cast to text before JSON; every tenant-scoped table has `tenant_id` and RLS; ledger is append-only; all privileged functions are `SECURITY DEFINER` with fixed `search_path = public, pg_temp`; no production manual-journal RPC; no B2+ entity or flow; Cairo dates and period locks; all new tables/RPCs require cross-tenant tests

**Scale/Scope**: 8 tenant-owned tables plus the root `tenants` boundary table, supporting indexes, internal helpers, four explicitly named browser-callable operations (`public.bootstrap_tenant`, `public.manage_membership`, `public.set_lock_date`, `public.manage_tenant_secret_ref`), internal ledger/counter/idempotency/reversal primitives, one generated database type file, and pgTAP suites for B1 T16/T19 coverage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Rule / principle | B1 design | Status |
|---|---|---|
| P1 ledger source of truth | All financial values originate in immutable `journal_lines`; no reports are added | PASS |
| P2 balanced entries | Deferred constraint trigger requires at least two lines and exact debit=credit before commit | PASS |
| P3 append-only | Browser DML revoked; guard triggers reject journal mutation; corrections are internal reversals | PASS |
| P4 integer piasters | `bigint` checks and text-before-JSON contract; no JS arithmetic | PASS |
| P5 RPC-only writes | Financial primitives are internal; test helper exists only inside pgTAP transactions | PASS |
| P6 idempotency | Tenant/request unique record, operation and payload fingerprint checks, original result on retry | PASS |
| P7 tenant isolation | Tenant identity, RLS, membership helpers, and T19 tests on every B1 object | PASS |
| P8 reconciliation | B1 verifies journal balance/reversal net zero; document/subledger reconciliation begins in B3 as approved | PASS |
| P9 period locking | Tenant row is locked and `entry_date > lock_date` is asserted inside posting/reversal transaction | PASS |
| P10 Cairo dates | Journal and lock dates are SQL `date`; test vectors use Cairo business dates | PASS |
| P11 gapless numbers | Counter row lock and transactional increment per tenant/type/year | PASS |
| P12 audit trail | Actor/time/request on postings; immutable audit rows for B1 master-data changes | PASS |
| Rules 1–2 scope | Only canonical B1 entities/rules; B2 master-data defaults explicitly deferred | PASS |
| Rules 3–8 posting order | Test posting orchestration follows permission → idempotency → validation → locks → number → journal → balance → result | PASS |
| Rule 9 migrations/types | One new migration; generated `src/types/database.ts` committed unedited | PASS |
| Rule 10 table/RPC isolation | Every tenant-owned table/RPC gets same-tenant and cross-tenant pgTAP coverage | PASS |
| Rules 11–15 dates/UI/strict/no stubs | No new UI; SQL behavior is complete and tested; existing strict gates remain | PASS |
| Rules 16–17 delivery | Focused conventional commits; all exact gates and B1 reconciliation applicability reported | PASS |
| Rules 18–19 architecture/agents | Next.js + Supabase only; one builder branch owns the migration | PASS |

**Pre-research gate**: PASS. No constitution exception is required. The root `tenants` table is the tenant boundary itself, so its primary key is the tenant identity; all child tables carry `tenant_id`. This is not a cross-tenant exception.

## Project Structure

### Documentation (this feature)

```text
specs/002-b1-tenancy-ledger/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── database-security.md
│   ├── ledger-posting.md
│   └── quality-gates.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
/
├── CHANGELOG.md
├── README.md
├── docs/
│   ├── ACCOUNTING.md
│   └── DECISIONS.md
├── src/
│   └── types/
│       └── database.ts
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   │   └── <timestamp>_b1_tenancy_ledger_core.sql
│   └── tests/
│       ├── 000_harness.test.sql
│       ├── 001_b1_tenancy_rls.test.sql
│       ├── 002_b1_ledger.test.sql
│       └── 003_b1_security.test.sql
└── tests/
    └── unit/
        └── guard-database-types.test.ts
```

**Structure Decision**: Keep the existing single Next.js/Supabase project. B1 is database-first: one migration owns all mutually dependent B1 schema, grants, policies, triggers, and functions so it is atomic and reviewable. pgTAP files split isolation, ledger behavior, and privilege/security concerns while rolling back fixtures. `docs/ACCOUNTING.md` begins now per the carried B1 obligation and documents the delivered ledger contract only.

## Phase 0 Research Decisions

1. Keep root tables in `public` for generated types and RLS; keep privileged helpers/functions in non-exposed `app`, with only explicit public wrappers where a browser operation is required.
2. Revoke PostgreSQL's default public function execution and grant the minimum operations explicitly.
3. Use a deferred constraint trigger with transaction-local entry tracking so multi-line inserts can complete before balance validation.
4. Store idempotency payload fingerprints to distinguish identical retries from request-id misuse; return canonical JSON with monetary values already represented as strings.
5. Allocate counters with one upsert/row lock per `(tenant_id, doc_type, year)` inside the caller transaction; rollback restores the counter on failure.
6. Implement internal journal/reversal primitives with no `anon`/`authenticated` execute grant; pgTAP creates a test-only orchestrator inside its rollback transaction.
7. Store Vault identifiers in typed tenant-owned rows; never resolve or return secret values in B1 browser operations.
8. Generate types from the local database after reset and guard against hand edits/drift.

See [research.md](./research.md) for rationale and rejected alternatives.

## Implementation Phases

1. **Environment and records**: prove database-only Supabase startup, complete the B1 clean-machine setup evidence, create `docs/ACCOUNTING.md`, and record clarified decisions.
2. **Tests first**: add pgTAP fixtures and failing tests for schema, bootstrap, RLS, roles, suspension, lock date, exact ledger values, balance, immutability, counters, retries, reversal, audit, and secret references.
3. **Schema migration**: create enums, tables, checks, indexes, RLS, grants, audit and immutability guards.
4. **Security helpers/bootstrap**: implement fixed-context membership/role/tenant-state helpers and atomic tenant bootstrap with chart seed only.
5. **Ledger primitives**: implement idempotency, counters, journal creation/balance assertion, and internal reversal in the mandated order.
6. **Types and documentation**: reset locally, regenerate `src/types/database.ts`, document accounting/security contracts, update README/CHANGELOG/DECISIONS.
7. **Validation**: run typecheck, lint, unit, pgTAP, Playwright, database reset/type drift, B1 journal/reversal reconciliation, full T16/T19 B1 matrix, CI, Codex PR review, and founder approval.

## Post-Design Constitution Check

PASS. The data model and contracts preserve every pre-research gate. No financial client write, report, B2 master-data table, business document, inventory object, or production manual-journal endpoint is introduced. Every database object has an owner, privilege plan, RLS/role test, and explicit B1 acceptance evidence.

## Complexity Tracking

No constitution violation requires justification.
