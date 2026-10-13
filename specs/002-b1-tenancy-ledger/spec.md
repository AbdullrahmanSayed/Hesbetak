# Feature Specification: B1 — Tenancy & Ledger Core

**Feature Branch**: `002-b1-tenancy-ledger`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "Enable isolated showroom tenants and membership roles, with a trustworthy balanced append-only ledger foundation, period locking, auditable reversals, gapless numbering, and safe retry behavior. No purchase or sale flows yet. Scope: Sections 2, 5, 6.16, 7.1–7.2, 9–10, 17 B1, 18."

## Clarifications

### Session 2026-10-12

- Q: What should `bootstrap_tenant` create in B1 before B2 master-data tables exist? → A: Create the tenant, active owner membership, and complete chart of accounts only; B2 extends bootstrap with cash-account, expense-category, and installment-plan defaults.
- Q: How should B1 provide reversal without allowing browser users to reverse raw journal entries? → A: Provide an internal ledger reversal primitive with no browser grant; the B1 test helper exercises it, and later document reversal transactions compose it with stock and subledger corrections.
- Q: How should each tenant store Supabase Vault references without storing secret values? → A: Use tenant-scoped typed reference rows containing only a secret kind and Vault UUID, unique per tenant and kind; do not place references or values in tenant settings.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bootstrap an isolated showroom tenant (Priority: P1)

A newly authenticated owner creates a showroom tenant and immediately receives an active owner membership and the accounting foundation required for later business operations. A user may belong to more than one tenant, but selecting one tenant never exposes another tenant's data.

**Why this priority**: Every later financial feature depends on a correctly initialized tenant and strict tenant isolation.

**Independent Test**: Create two owners and two tenants, bootstrap each tenant, and verify each owner sees only the tenant and accounting records belonging to memberships they hold.

**Acceptance Scenarios**:

1. **Given** an authenticated user with no tenant, **When** the user creates a valid tenant, **Then** one tenant and one active owner membership are created together and the tenant's required accounting foundation is seeded exactly once.
2. **Given** a user who belongs to two tenants, **When** the user selects either tenant, **Then** only that tenant's records are visible and actionable.
3. **Given** an authenticated non-member, **When** the user attempts to read or act on another tenant, **Then** access is denied without revealing that tenant's data.
4. **Given** a suspended tenant, **When** any member attempts a write, **Then** the write is rejected while authorized reads remain available.

---

### User Story 2 - Record a trustworthy balanced journal entry (Priority: P1)

Authorized accounting code can post an immutable journal entry whose lines use exact integer piasters, belong to one tenant, reference valid accounts from that tenant, and balance exactly.

**Why this priority**: The ledger is the financial source of truth for every later document and report.

**Independent Test**: Through the B1-only journal test helper, submit exact debit and credit lines, verify the balanced entry is accepted, and verify unbalanced, single-line, mixed-tenant, invalid-side, and out-of-range attempts are rejected atomically.

**Acceptance Scenarios**:

1. **Given** an authorized member, valid unlocked business date, and two or more valid lines whose debits equal credits, **When** the test helper posts the entry, **Then** exactly one immutable journal entry with the exact lines is recorded.
2. **Given** lines whose total debits do not equal total credits, **When** posting is attempted, **Then** the whole operation is rejected and no journal row remains.
3. **Given** a line with both debit and credit positive, both zero, a negative amount, or an account from another tenant, **When** posting is attempted, **Then** the whole operation is rejected.
4. **Given** a posted journal entry or line, **When** a client attempts to update or delete it directly, **Then** the operation is denied.

---

### User Story 3 - Retry safely with gapless tenant numbering (Priority: P1)

A posting operation can be retried with the same request identifier without creating duplicate financial effects or consuming an extra entry number. Concurrent requests receive unique, gapless numbers within the tenant, document type, and year.

**Why this priority**: Network retries and concurrent posting are unavoidable; duplicates or number gaps undermine financial trust.

**Independent Test**: Post the same request twice and concurrently, then post distinct requests concurrently, and verify one result per request, one journal effect per request, and a gapless number sequence.

**Acceptance Scenarios**:

1. **Given** a successfully processed request, **When** the same operation and request identifier are submitted again, **Then** the original result is returned without new journal lines or a new number.
2. **Given** the same request identifier is reused for a different operation or materially different payload, **When** it is submitted, **Then** it is rejected rather than returning or creating an unrelated result.
3. **Given** multiple distinct valid requests for the same tenant, type, and year, **When** they execute concurrently, **Then** each receives a unique consecutive number with no duplicates or gaps.
4. **Given** a failed posting attempt, **When** the failure completes, **Then** it leaves no successful idempotency record and consumes no permanent document number.

---

### User Story 4 - Enforce period locks and auditable corrections (Priority: P2)

An owner can set a tenant lock date. Entries on or before that date cannot be posted or reversed. Corrections to eligible entries are made only through an authorized reversal that mirrors every original line and preserves the original entry.

**Why this priority**: Locked periods and append-only corrections protect historical financial statements.

**Independent Test**: Set a lock date, attempt entries before/on/after it, reverse an eligible entry, and verify the original remains unchanged while the reversal mirrors all values and dimensions.

**Acceptance Scenarios**:

1. **Given** a tenant lock date, **When** posting is attempted on or before it, **Then** the operation is rejected atomically.
2. **Given** an unlocked posted entry and an authorized role with a non-empty reason, **When** reversal is requested, **Then** a new entry is created with debit and credit swapped on every line, the same dimensions, and links between original and reversal.
3. **Given** an entry in a locked period, an already reversed entry, a reversal entry, or an unauthorized role, **When** reversal is requested, **Then** it is rejected with no changes.
4. **Given** a posted entry, **When** it is reversed, **Then** the original entry and lines remain unchanged and the actor, reason, request identifier, and timestamps remain auditable.

---

### User Story 5 - Protect roles, audit, and secret references (Priority: P2)

Tenant owners manage memberships and lock dates; all security-sensitive changes are attributable to an authenticated actor. Tenant configuration may reference secrets, but secret values never appear in tenant records, browser responses, logs, or audit details.

**Why this priority**: Later batches rely on one stable security model and must not retrofit tenant or secret boundaries.

**Independent Test**: Exercise every B1 table and operation as owner, manager, accountant, cashier, collector, non-member, inactive member, and cross-tenant user; verify only permitted actions succeed and no secret value is exposed.

**Acceptance Scenarios**:

1. **Given** each supported membership role, **When** a B1 operation is attempted, **Then** the authoritative role rules allow or deny it consistently.
2. **Given** an inactive membership, **When** the user attempts tenant access, **Then** access is denied.
3. **Given** a tenant-level secret reference, **When** tenant or audit data is read by a browser user, **Then** no secret value is returned.
4. **Given** a membership, lock-date, or other B1 master-data change, **When** it succeeds, **Then** an immutable audit record identifies tenant, actor, time, target, action, and before/after values without secrets.

### Edge Cases

- A tenant name or slug is empty, invalid, or conflicts with an existing tenant.
- The same bootstrap request is retried after success or after a transaction failure.
- A user attempts to deactivate the tenant's last active owner or remove their own final owner membership.
- A tenant is suspended between permission validation and the financial write.
- The lock date changes while a posting or reversal is in progress.
- A request uses a future or malformed business date, a non-canonical request identifier, or an amount outside signed 64-bit piaster bounds. A valid future Cairo date is accepted in B1 because no current-period upper lock exists; malformed or out-of-range dates are rejected.
- Journal lines contain accounts from different tenants or reference inactive/header accounts.
- Concurrent posting requests race for the first number of a new year.
- A reversal is retried, raced concurrently, or requested for an entry that already reverses another entry.
- A secret reference is missing, stale, cross-tenant, or points to an unavailable secret; the secret value must still never be disclosed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST represent each showroom as an isolated tenant with a unique stable identifier, unique selectable slug, business profile, plan, status, lock date, validated settings, creation actor, and creation time.
- **FR-002**: The system MUST support active or inactive memberships linking users to tenants with exactly one role from `owner`, `manager`, `cashier`, `collector`, or `accountant`; a user MAY belong to multiple tenants.
- **FR-003**: Membership and role checks MUST be authoritative for every B1 read and operation, and an inactive membership MUST grant no access.
- **FR-004**: Every B1 tenant-scoped record and operation MUST be isolated by tenant, including direct reads, helper operations, retries, numbering, journal activity, reversals, audit data, and secret references.
- **FR-005**: Suspended tenants MUST be read-only for browser users and ordinary tenant operations; reactivation and platform administration are outside B1.
- **FR-006**: Browser operation `public.bootstrap_tenant` MUST delegate to internal `app.bootstrap_tenant` and atomically create the tenant, active owner membership, and complete chart of accounts exactly once. Default cash accounts, expense categories, and installment plan templates remain B2 scope; B2 MUST extend bootstrap when their tables exist.
- **FR-007**: Tenant bootstrap MUST seed the complete Section 7.1 chart of accounts with the specified Arabic name, English name, account type, normal side, hierarchy, active/header status, and unique tenant-scoped `system_key` where specified.
- **FR-008**: Application behavior MUST resolve system accounts by `system_key`, never by account code; codes remain display and bookkeeping identifiers.
- **FR-009**: The system MUST prevent deletion of accounts used by journal lines and MUST prevent posting to inactive or header accounts.
- **FR-010**: Journal entries MUST include tenant, gapless entry number, Cairo business date, source type and identifier, description, reversal links, request identifier, actor, and creation time.
- **FR-011**: Journal lines MUST include tenant, entry, account, exact signed-64-bit integer-piaster debit and credit values, memo, and all nullable dimensions listed in Section 7.1; each line MUST have exactly one positive side and one zero side.
- **FR-012**: Every completed journal entry MUST contain at least two lines and have total debits exactly equal to total credits; invalid entries MUST fail atomically before becoming visible.
- **FR-013**: Posted journal entries and lines MUST be append-only. Direct insert, update, and delete access by browser roles MUST be denied; corrections MUST use reversal.
- **FR-014**: All financial writes MUST execute through authorized transactional operations that apply permission, idempotency, validation, row locking, numbering, journal creation, balance assertion, and result return in that order.
- **FR-015**: The B1 journal test helper MUST be unavailable as a production browser financial-write endpoint and MUST exist only to prove ledger guarantees until real document posting begins in later batches.
- **FR-016**: A tenant lock date MUST reject postings and reversals dated on or before the lock date, including when the lock date changes concurrently with an operation.
- **FR-017**: Gapless counters MUST be independent per tenant, document type, and calendar year and MUST allocate numbers under concurrency without duplicate or permanently skipped committed numbers.
- **FR-018**: Every posting operation MUST accept a caller-generated request identifier unique per tenant, record the operation identity and canonical result, and return the original result for an identical retry without repeating effects.
- **FR-019**: Reusing a request identifier for a different operation or materially different request MUST be rejected.
- **FR-020**: Failed operations MUST leave no partial journal data, permanent counter increment, or successful idempotency record.
- **FR-021**: Reversal MUST create a new balanced entry that mirrors every original line by swapping debit and credit while preserving account, memo, and dimensions; the original entry and lines MUST remain unchanged.
- **FR-022**: B1 MUST provide an internal ledger reversal primitive with no browser-role execution grant. The B1 test helper MUST exercise it, and later document reversal transactions MAY compose it only together with their required stock and subledger corrections. The primitive MUST require an authorized initiating role, an unlocked Cairo business date, a non-empty reason, and safe retry behavior, and MUST reject already reversed entries and entries that are themselves reversals.
- **FR-023**: The system MUST retain bidirectional links between an original entry and its reversal and MUST audit the actor, reason, date, and request identifier.
- **FR-024**: Owner-only operations MUST manage memberships and lock date, and MUST prevent a tenant from losing its last active owner.
- **FR-025**: B1 master-data changes MUST produce immutable tenant-scoped audit records containing actor, timestamp, target type/id, action, and before/after values, with secret values excluded.
- **FR-026**: B1 MUST store tenant secret references as tenant-scoped typed rows containing only a secret kind and Vault UUID, with at most one reference row per tenant and kind. Owners MAY create, replace, or remove reference metadata through an explicitly granted operation; neither references nor values belong in tenant settings. Secret values MUST be readable only by trusted server-side execution and MUST never be returned to browser users or written to logs, idempotency results, or audit details.
- **FR-027**: Every privileged operation MUST use a fixed trusted execution context and MUST not inherit caller-controlled object resolution.
- **FR-028**: Every B1 table MUST carry tenant identity and access controls appropriate to its ownership; platform bootstrap data MUST not create an isolation bypass.
- **FR-029**: Automated acceptance coverage MUST include the B1 portions of T16 and T19, exact-number balanced posting, unbalanced rejection, lock-date rejection, idempotent retry, concurrent numbering, reversal, inactive membership, suspended tenant, and cross-tenant denial for every B1 table and operation.
- **FR-030**: B1 MUST regenerate the application's database type contract after its schema migration and MUST provide exact decimal-string transport for every monetary database result before application decoding.
- **FR-031**: B1 MUST NOT add purchase, sale, inventory, customer, supplier, partner, installment, receipt, expense, attachment, reporting, dashboard, or production manual-journal flows.
- **FR-032**: The B1 completion record MUST include exact local and CI results for typecheck, lint, unit, database, browser, and applicable reconciliation checks; full seeded document reconciliation remains deferred to B3 and MUST NOT be reported as passed in B1.

### Key Entities

- **Tenant**: One showroom's isolated business and security boundary, including profile, plan/status, lock date, settings, and secret references only.
- **Membership**: A user's tenant-scoped role and active state.
- **Account**: A tenant's chart-of-accounts node, optionally identified by a stable system key and linked to a parent account.
- **Journal Entry**: An immutable balanced financial event header with business date, source, number, request, actor, and reversal relationships.
- **Journal Line**: One exact debit or credit against an account, with optional reporting dimensions.
- **Document Counter**: The next committed gapless sequence state for one tenant, document type, and year.
- **Posting Request**: The idempotency record binding one tenant request identifier to one operation and canonical result.
- **Audit Record**: An immutable record of a tenant-scoped non-financial change and its actor.
- **Secret Reference**: A tenant-scoped typed row containing a secret kind and Vault UUID only, unique per tenant and kind; the protected value remains outside ordinary tenant data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two independently bootstrapped tenants have zero cross-visible B1 records across all tested roles and operations; every unauthorized cross-tenant attempt is denied.
- **SC-002**: 100% of accepted journal entries contain at least two lines, balance to the exact piaster, and remain unchanged after posting.
- **SC-003**: 100% of tested unbalanced, mixed-tenant, invalid-side, header-account, inactive-account, locked-date, and unauthorized postings fail atomically with zero residual financial rows.
- **SC-004**: Repeating any tested successful request at least ten times returns one identical result and creates exactly one financial effect and one committed number.
- **SC-005**: Concurrent distinct requests produce a unique consecutive sequence with zero duplicate or missing committed numbers in every tested tenant/type/year partition.
- **SC-006**: Every tested eligible reversal exactly mirrors the original entry at line and dimension level, preserves the original unchanged, and prevents a second reversal.
- **SC-007**: Every B1 table and operation has an automated same-tenant success case and cross-tenant denial case; T16 and the B1 scope of T19 pass.
- **SC-008**: No browser-visible response, log, settings value, audit detail, or retry result contains a tenant secret value in the complete automated security test set.
- **SC-009**: The five project quality checks pass in CI, and local database tests pass against a clean local environment before B1 is submitted for review.
- **SC-010**: The B1 scope contains zero purchase, sale, inventory, customer, supplier, installment, attachment, report, dashboard, or production manual-journal feature objects.

## Assumptions

- B0 is approved and merged, and its exact money/date contracts remain authoritative.
- Authentication users already exist in the platform identity service; B1 stores memberships, not passwords or profile credentials.
- One tenant represents one showroom; multi-branch behavior is post-MVP.
- Tenant status begins as `trial`; subscription billing and platform-admin reactivation remain manual and outside MVP behavior.
- Business dates and lock dates use Cairo civil dates; timestamps remain absolute instants.
- Account and journal amounts are integer piasters within signed 64-bit bounds and cross application boundaries only as validated decimal strings.
- B1 provides backend foundations and automated tests only; tenant-management and accounting UI arrive in later batches unless explicitly listed here.
- Full reconciliation involving a posted business document begins in B3; B1 proves ledger balance and reversal consistency only.
- Local Docker, sufficient disk, network access, and a clean local database are mandatory B1 prerequisites; the B0 CI-only fallback no longer applies.
