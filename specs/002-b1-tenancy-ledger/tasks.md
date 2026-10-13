---

description: "Task list for B1 — Tenancy & Ledger Core"
---

# Tasks: B1 — Tenancy & Ledger Core

**Input**: Design documents from `/specs/002-b1-tenancy-ledger/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md; approved `checklists/ledger-security.md`

**Tests**: REQUIRED. Every schema/security/posting rule is written as a failing pgTAP assertion before its migration implementation. B0 regression checks remain mandatory.

**Organization**: Tasks are grouped by user story. One builder owns the B1 migration; no parallel agent may create or edit migrations.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel only when files are independent and no migration ordering dependency exists
- **[Story]**: US1–US5 from spec.md
- Every task names its output path and objective evidence

---

## Phase 1: Setup and Gates

**Purpose**: Establish the B1 branch, approved requirements, restored local database, and carried obligations before schema work

- [X] T001 Create branch `002-b1-tenancy-ledger` from approved `origin/main`, preserve untracked root HESBETAK_SPEC.md unchanged, and point `.specify/feature.json` to `specs/002-b1-tenancy-ledger`
- [X] T002 Run Specify and Clarify for B1 in `specs/002-b1-tenancy-ledger/spec.md`; record founder decisions for bootstrap scope, internal-only reversal, and typed Vault-reference rows
- [X] T003 Generate `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, and `contracts/` under `specs/002-b1-tenancy-ledger/`; pass the built-in 16/16 requirements checklist
- [X] T004 Generate and obtain founder approval for all 37 items in `specs/002-b1-tenancy-ledger/checklists/ledger-security.md`
- [X] T005 Restore local Docker/WSL2, start database-only Supabase with the documented exclusion list, run `npm run test:db` successfully, and record actual disk/Docker findings without using the B0 CI-only fallback
- [X] T006 Update `docs/DECISIONS.md` with B1 clarifications R1–R16, the root-tenant identity interpretation, database-only local mode, and the no-production-manual-JE boundary
- [X] T007 Create `docs/ACCOUNTING.md` for the delivered B1 account chart, ledger invariants, lock/counter/idempotency/reversal contracts, and later-batch reconciliation boundaries
- [X] T008 Run `$speckit-analyze`, resolve every CRITICAL/HIGH inconsistency across B1 artifacts, and commit the approved planning set with a focused `docs:` commit

---

## Phase 2: Foundational Database Tests and Migration Skeleton

**Purpose**: Write failing security/schema tests first, then create the shared B1 database foundation

**⚠️ CRITICAL**: No story implementation begins until these tests fail for the expected missing objects and the migration skeleton exists.

- [X] T009 [P] Add reusable pgTAP Auth/JWT, tenant, role, privilege, and exception helpers in `supabase/tests/helpers/b1.inc`; every `*.test.sql` suite that needs them MUST load them with psql `\ir`, and helpers MUST create no persistent production fixtures
- [X] T010 [P] Add failing schema/constraint/index/grant assertions for every B1 enum, table, column, FK, check, unique key, tenant-first index, RLS flag, and forbidden B2 object in `supabase/tests/002_b1_schema.test.sql`
- [X] T011 [P] Add failing T16 privilege assertions for default function execute revocation, internal primitive denial, direct ledger/audit DML denial, fixed search paths, and append-only guards in `supabase/tests/003_b1_security.test.sql`
- [X] T012 Run `npm run test:db`; save the expected missing-object failures for T009–T011 before migration implementation
- [X] T013 Create one forward-only migration `supabase/migrations/<timestamp>_b1_tenancy_ledger_core.sql` with required extensions, `app` schema, B1 enums, table skeletons, checks, FKs, tenant-first indexes, default privilege revocations, RLS enablement, and no B2+ tables
- [X] T014 Implement immutable audit/journal guard triggers and deferred journal balance/line-count constraint trigger in the B1 migration; keep journal lines permanently immutable
- [X] T015 Implement fixed-context `app.current_user_id`, `app.is_member`, `app.has_role`, tenant-state, same-tenant account, audit sanitization, and balance assertion helpers in the B1 migration with no browser grants
- [X] T016 Run schema/security pgTAP and `npx supabase db reset`; confirm migration applies from zero and T010–T011 pass before story work

**Checkpoint**: Shared schema, grants, RLS foundations, and deferred ledger invariant exist.

---

## Phase 3: User Story 1 — Bootstrap an Isolated Tenant (Priority: P1) 🎯 MVP

**Goal**: Atomic tenant + active owner + exact account chart, with complete tenant isolation and suspension behavior

**Independent Test**: Bootstrap two owners/tenants and prove exact seeds plus same-tenant access and cross-tenant/non-member/inactive denial.

### Tests first

- [X] T017 [P] [US1] Add failing bootstrap and exact Section 7.1 chart seed assertions, including no B2 defaults and system-key/code/hierarchy checks, in `supabase/tests/004_b1_bootstrap.test.sql`
- [X] T018 [P] [US1] Add failing progressive T19 RLS matrix for `tenants`, `memberships`, and `accounts` across owner/manager/cashier/collector/accountant/non-member/inactive/cross-tenant/suspended contexts in `supabase/tests/005_b1_tenancy_rls.test.sql`
- [X] T019 [P] [US1] Add failing owner membership-management, final-owner protection, lock-date-management, and sanitized audit assertions in `supabase/tests/006_b1_management.test.sql`
- [X] T020 [US1] Run T017–T019 and confirm expected missing-function/policy failures

### Implementation

- [X] T021 [US1] Implement atomic public tenant bootstrap wrapper plus internal `app.bootstrap_tenant` in the B1 migration, seeding only tenant, owner membership, and the complete chart exactly once
- [X] T022 [US1] Implement minimal table SELECT policies, explicit grants, active membership helpers, tenant suspension write checks, and cross-tenant ownership validation for US1 objects
- [X] T023 [US1] Implement owner-only membership and lock-date operations with tenant row locks, final-active-owner protection, and immutable sanitized audit rows
- [X] T024 [US1] Run `npm run test:db`; confirm T017–T019 and all prior tests pass

**Checkpoint**: US1 independently bootstraps and isolates two tenants with exact chart data.

---

## Phase 4: User Story 2 — Balanced Append-Only Journal (Priority: P1)

**Goal**: Exact-piaster, same-tenant, at-least-two-line balanced entries that cannot be mutated directly

**Independent Test**: A rollback-scoped test helper posts an exact balanced entry and rejects every invalid/unbalanced/mixed-tenant variant atomically.

### Tests first

- [X] T025 [P] [US2] Add failing transaction-local manual-JE helper and exact vectors (`2_000_000`, `9_007_199_254_740_993`) with decimal-string JSON results in `supabase/tests/007_b1_ledger.test.sql`
- [X] T026 [P] [US2] Add failing cases for imbalance, fewer than two lines, zero/both-positive/negative/overflow sides, malformed money JSON, header/inactive/wrong-tenant accounts, and residual-row absence in `supabase/tests/007_b1_ledger.test.sql`
- [X] T027 [P] [US2] Add failing append-only and RLS/T19 matrix assertions for `journal_entries` and `journal_lines` in `supabase/tests/008_b1_ledger_security.test.sql`
- [X] T028 [US2] Run T025–T027 and confirm expected failures precede implementation

### Implementation

- [X] T029 [US2] Implement ungranted internal journal validation/creation primitives in the B1 migration with exact text-to-`bigint` parsing, account/tenant checks, dimension preservation, and canonical text-money result JSON
- [X] T030 [US2] Complete deferred balance trigger integration and guarded entry-link update context so valid multi-line transactions commit and every invalid entry rolls back
- [X] T031 [US2] Apply ledger SELECT policies and deny all direct browser DML/function execution per `contracts/database-security.md`
- [X] T032 [US2] Run `npm run test:db`; confirm all exact-number, balance, residual-row, immutability, and T19 assertions pass

**Checkpoint**: US2 independently proves exact balanced append-only ledger behavior.

---

## Phase 5: User Story 3 — Idempotency and Gapless Numbering (Priority: P1)

**Goal**: Identical retries create one effect/result; mismatches fail; committed numbers remain unique and gapless per partition

**Independent Test**: Repeat and race identical/distinct requests and verify exact effects, rollback safety, and tenant/type/year partitioning.

### Tests first

- [X] T033 [P] [US3] Add failing identical-retry, mismatched RPC/payload, failed-transaction retry, and canonical stored-result assertions in `supabase/tests/009_b1_idempotency.test.sql`
- [X] T034 [P] [US3] Add failing counter partition, rollback, first-number, year rollover, and distinct tenant/type assertions in `supabase/tests/010_b1_counters.test.sql`
- [ ] T035 [P] [US3] Add a deterministic concurrency harness in `supabase/tests/011_b1_concurrency.test.sql` using test-only `dblink` sessions, advisory synchronization, and bounded statement/lock timeouts; prove identical-request replay and distinct number allocation without enabling `dblink` in the production migration
- [ ] T036 [US3] Run T033–T035 and confirm expected failures precede implementation

### Implementation

- [ ] T037 [US3] Implement internal begin/finish posting-request primitives with row locks, RPC/payload fingerprint enforcement, completed-result replay, and rollback-safe state in the B1 migration
- [ ] T038 [US3] Implement rollback-safe counter allocation with row locking/upsert per `(tenant_id, doc_type, year)` and integrate it into the pgTAP posting helper order
- [ ] T039 [US3] Run idempotency/counter/concurrency suites repeatedly; confirm no duplicate effects, duplicate numbers, or committed gaps

**Checkpoint**: US3 independently proves safe retries and numbering under concurrency.

---

## Phase 6: User Story 4 — Period Locks and Auditable Reversals (Priority: P2)

**Goal**: Locked dates reject changes; eligible entries are corrected only by exact internal reversal

**Independent Test**: Lock a period, test boundary dates, reverse one eligible entry, and prove exact mirrored lines/net zero/original immutability and second-reversal denial.

### Tests first

- [X] T040 [P] [US4] Add failing lock-date before/on/after and concurrent lock-change assertions in `supabase/tests/012_b1_lock_date.test.sql`
- [X] T041 [P] [US4] Add failing reversal vectors for exact mirror, all dimensions/memo, original immutability, bidirectional links, reason audit, retry, second reversal, reversal-of-reversal, wrong tenant/role, suspended tenant, and locked date in `supabase/tests/013_b1_reversal.test.sql`
- [X] T042 [US4] Run T040–T041 and confirm expected failures precede implementation

### Implementation

- [X] T043 [US4] Enforce tenant-row lock ordering and `entry_date > lock_date` inside journal posting, reversal, and lock-date updates in the B1 migration
- [X] T044 [US4] Implement the ungranted internal reversal primitive in the B1 migration, composing idempotency, validation, locks, number, exact mirrored lines, balance, guarded links, and sanitized reason audit
- [X] T045 [US4] Run lock/reversal pgTAP; calculate journal-only reversal reconciliation from `journal_lines` and confirm exact net zero

**Checkpoint**: US4 independently protects closed periods and produces auditable append-only corrections.

---

## Phase 7: User Story 5 — Roles, Audit, and Secret References (Priority: P2)

**Goal**: Complete B1 role matrix, immutable sanitized audit, and isolated typed Vault identifiers without secret-value disclosure

**Independent Test**: Exercise every B1 table/operation as every role and tenant context; prove one reference per kind and zero plaintext exposure.

### Tests first

- [X] T046 [P] [US5] Add failing complete role/privilege matrix and fixed-search-path shadowing assertions for every B1 function in `supabase/tests/014_b1_roles.test.sql`
- [X] T047 [P] [US5] Add failing `audit_log` attribution/immutability/sanitization and T19 assertions in `supabase/tests/015_b1_audit.test.sql`
- [X] T048 [P] [US5] Add failing typed Vault-reference uniqueness, owner management, same/cross-tenant RLS, stale/missing identifier, and no-plaintext-channel assertions in `supabase/tests/016_b1_vault_refs.test.sql`
- [X] T049 [US5] Run T046–T048 and confirm expected failures precede implementation

### Implementation

- [X] T050 [US5] Complete explicit role grants/checks and fixed-context security-definer definitions for all B1 operations in the migration
- [X] T051 [US5] Implement owner-only typed Vault-reference metadata management and audit behavior without any plaintext resolver or settings storage
- [X] T052 [US5] Run the complete progressive T19 matrix and produce a table/RPC evidence map in `docs/DECISIONS.md`

**Checkpoint**: US5 independently proves the B1 security model and no secret disclosure.

---

## Phase 8: Types, Documentation, Validation, and Review

**Purpose**: Prove migration reproducibility, generated contracts, all regression gates, CI, and human review

- [ ] T053 Run `npx supabase db reset` from committed migrations; fix only with a new migration if the first B1 migration has already been applied outside disposable local development
- [ ] T054 Generate `src/types/database.ts` from local schemas using the pinned CLI, add `tests/unit/guard-database-types.test.ts`, and prove the generated file is unedited/current
- [ ] T055 Update `supabase/config.toml`/README scripts only as needed for repeatable database-only startup and type generation; do not weaken the existing five quality commands
- [ ] T056 Update `CHANGELOG.md`, `docs/ACCOUNTING.md`, and `docs/DECISIONS.md` with delivered B1 objects, exact security model, test evidence, known risks, and B2 entry obligations
- [ ] T057 Run exact local gates: `npm run typecheck`, `npm run lint`, `npm run test:unit`, `npm run test:db`, `npm run test:e2e`, reset/type drift, and B1 journal/reversal reconciliation; report full document/subledger T17 as not applicable until B3
- [ ] T058 Verify root HESBETAK_SPEC.md remains untracked/unmodified, no secret/env file is committed, no B2+ table/flow exists, and every checklist/task/review line is satisfied
- [ ] T059 Run `$speckit-converge`; append and implement every remaining task until convergence reports no unbuilt B1 requirement
- [ ] T060 Commit focused conventional changes, push only `002-b1-tenancy-ledger`, open the B1 PR, request `@codex review`, address every confirmed finding, and rerun affected/local/CI gates
- [ ] T061 Confirm five CI jobs green, record the CI/PR/Codex evidence, present the exact B1 batch report, and obtain Abdullrahman's explicit B1 approval before B2

---

## Dependencies & Execution Order

- Phase 1 blocks all database work.
- Phase 2 blocks every user story and is owned by the single migration builder.
- P1 stories run sequentially US1 → US2 → US3 because they share one migration and each establishes primitives used by the next.
- P2 stories run sequentially US4 → US5 on the same migration.
- Tests in separate files marked `[P]` may be authored in parallel only when no second agent edits the migration.
- Phase 8 begins only after every story checkpoint passes.

## Implementation Strategy

1. Preserve one forward-only B1 migration while it remains unapplied outside disposable local development.
2. For each story, write exact pgTAP failures first, implement the minimum production behavior, then pass the story and all prior suites.
3. Never expose the test helper or internal ledger primitives to browser roles.
4. Keep B2 entities out even when bootstrap references their future defaults.
5. Treat local database success as mandatory; no B0-style CI fallback.
