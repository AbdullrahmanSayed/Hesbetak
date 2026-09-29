# Feature Specification: B0 — Foundation

**Feature Branch**: `001-b0-foundation` (spec directory; git branch not yet created — see `docs/DECISIONS.md` D-B0-07)

**Created**: 2026-09-27

**Status**: Draft — awaiting founder review

**Batch**: B0 (master spec Section 17). Source of truth: `docs/HESBETAK_SPEC.md`.

**Input**: User description: "Build the minimal project foundation for an Arabic-first RTL showroom application, so future batches can reliably create correct Cairo business dates and integer-piaster money values. Deliver a working app shell and repeatable local development/test setup only. Scope: Section 17 B0; Sections 0, 2, 3, 11, 12, 18. No B1 data model or financial features."

## Clarifications

### Session 2026-09-27

The builder recorded the questions in `docs/DECISIONS.md`; Abdullrahman approved the B0 decisions on 2026-09-27. The accepted behaviors below follow those decisions. Approval of the requirements does not constitute approval to merge or start B1.

- D-B0-01: Strict Western/Arabic-Indic typed EGP input, valid grouping, 0–2 decimals; reject excess decimals, signs, exponent and currency text. Exact approved edge cases and Arabic messages: `contracts/money.md`.
- D-B0-02: Negative display uses `-20,000.00 ج.م` with the signed digits isolated LTR; positives unchanged. D-B0-10: with Arabic-Indic digits, a negative is exactly `"\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م"`.
- D-B0-03: Monetary TypeScript values use `bigint` in signed PostgreSQL `bigint` piaster range. JSON/RPC monetary transport uses validated decimal strings, not JSON numbers. B0 provides money-module wire conversions but no DB adapter. Extended project-wide and written into the amended Section 18 Rule 3 (approved 2026-09-27); the B1 database obligations are listed under Assumptions.
- D-B0-04: Three rounding primitives with `bigint` operands/results, non-negative numerators, positive denominators/steps, signed-64-bit monetary result checks; no schedule logic in TypeScript.
- D-B0-05: Optional Arabic-Indic digit formatting, Western by default; setting wiring belongs to B9.
- D-B0-06: Minimal root `<h1>` from `APP_NAME.ar`, RTL layout and shadcn/ui configuration; no unused business routes, components, seed, types or client factories.
- D-B0-07: B0 branch, small commits and push to `origin` authorized; no merge or B1 without review.
- D-B0-08: `docs/ACCOUNTING.md` starts in B1.
- D-B0-09: B0 pgTAP/Playwright may be verified by 5/5 green CI if local Docker/disk are unavailable; local attempted commands are reported `blocked` with actual errors, never `passed`. Local DB blockers must be resolved before B1 implementation.
- D-B0-11: SC-004 B0 evidence is CI running the README setup/check commands; the local clean-machine walkthrough is deferred to B1 (approved 2026-09-28).

## User Scenarios & Testing *(mandatory)*

Actors: **Abdullrahman** (founder and reviewer), **builder/reviewer coding agents** (Claude Code,
Codex), and — later — **showroom staff** who will use the application in Arabic.

### User Story 1 - Money values are always exact integer piasters (Priority: P1)

Every later batch (sales, installments, collections, reports) needs one shared, trusted way to turn
an amount a person types in Egyptian pounds into an exact whole number of piasters, to display a
stored piaster amount in the standard Egyptian format, and to apply the integer rounding rules that
installment math (Section 8.2) depends on. Floating-point mistakes caused the previous product's
reports to be wrong; this foundation must make that class of error impossible.

**Why this priority**: Financial correctness beats everything (Section 0.4). B0's Definition of Done
names money helpers explicitly (100% unit-tested for parsing, formatting, rounding).

**Independent Test**: Run the money-helper unit tests with coverage; every parse, format and
rounding path is exercised and every expected value matches exactly.

**Acceptance Scenarios**:

1. **Given** the typed amount `20000`, **When** it is parsed, **Then** the result is exactly
   `2,000,000` piasters.
2. **Given** the typed amount `1,234.5`, **When** it is parsed, **Then** the result is exactly
   `123,450` piasters.
3. **Given** a stored value of `2,000,000` piasters, **When** it is formatted for display, **Then**
   the text is exactly `20,000.00 ج.م` (Section 11).
4. **Given** the Section 8.6 awkward vector (financed base `1,034,500`, factor `3000` bp), **When**
   the half-up rounding rule is applied to `1,034,500 × 3000 / 10000`, **Then** the result is
   exactly `310,350`.
5. **Given** receivable `1,344,850`, `n = 7`, rounding step `500`, **When** ceil-to-step is applied
   to `1,344,850 / 7`, **Then** the result is exactly `192,500`.
6. **Given** the Section 8.6 standard vector (financed base `1,500,000`, factor `4000` bp, receivable
   `2,100,000`, `n = 10`, step `100`), **When** the rounding rules are applied, **Then** margin is
   `600,000` and the base amount is `210,000`.
7. **Given** an amount with letters, exponent notation, a sign, more than two decimals, or a value above the signed-64-bit piaster maximum, **When** it is parsed, **Then** it is rejected with the corresponding approved Arabic message and no value is produced (D-B0-01/D-B0-03).
8. **Given** a value above JavaScript's safe-integer limit but within signed-64-bit range, **When** it crosses an application JSON boundary as a decimal string, **Then** it round-trips exactly as `bigint` without conversion to `number` (D-B0-03).

---

### User Story 2 - Business dates are always Cairo dates (Priority: P1)

Every posting in later batches is dated by the Cairo business day (Section 2 P10), regardless of the
user's device time zone or the server's time zone. The foundation must provide one shared way to
obtain "today in Cairo", convert any instant to its Cairo business date, validate a business date,
and get the exact start/end instants of a Cairo business day — correct across midnight, month/year
ends, leap days, and Egypt's daylight-saving transitions.

**Why this priority**: Wrong business dates break lock-date checks (P9), daily closing and overdue
calculations in later batches. B0 is where the helper is created (Section 17 B0, Rule 11).

**Independent Test**: Run the date-helper unit tests with fixed instants on both sides of Cairo
midnight in winter (UTC+2) and summer (UTC+3), on DST transition days, and at month/year ends; each
returns the expected Cairo date regardless of the machine time zone the tests run in.

**Acceptance Scenarios**:

1. **Given** the instant `2026-01-14T21:59:59Z`, **When** converted, **Then** the Cairo business date
   is `2026-01-14`; **and given** `2026-01-14T22:00:00Z`, **Then** it is `2026-01-15`.
2. **Given** a summer instant `2024-07-10T20:59:59Z`, **When** converted, **Then** the date is
   `2024-07-10`; **and given** `2024-07-10T21:00:00Z`, **Then** it is `2024-07-11`.
3. **Given** the instant `2025-12-31T22:00:00Z`, **When** converted, **Then** the date is
   `2026-01-01`.
4. **Given** the text `2026-02-30` or `2026-13-01`, **When** validated as a business date, **Then** it
   is rejected.
5. **Given** a Cairo business date on a DST transition day, **When** its day range is requested,
   **Then** the start and end instants reflect that day's actual length (23 or 25 hours).
6. **Given** the test process runs with a non-Cairo system time zone (e.g. UTC or
   America/New_York), **When** the same conversions run, **Then** results are identical.

---

### User Story 3 - A working Arabic-first RTL application shell (Priority: P2)

The founder can open the application locally and see an Arabic, right-to-left page that uses the
product's Arabic font and shows the product name taken from the single configured source, readable
on a 360 px wide phone screen and on a desktop.

**Why this priority**: It proves the application layer, styling system and RTL/font setup work end to
end before any feature is built on them (Sections 3, 11). It carries no financial behavior.

**Independent Test**: Start the application and load the home page in a browser at 360 px and at
desktop width; verify language, direction, font, product name, and absence of horizontal scrolling.

**Acceptance Scenarios**:

1. **Given** the application is running, **When** the home page loads, **Then** the document language
   is Arabic, the direction is right-to-left, and the browser title shows `حسبتك` read from the single
   product-name configuration (Section 0 header: metadata reads the constant). The page heading also
   shows it (approved D-B0-06).
2. **Given** a 360 px wide viewport, **When** the home page loads, **Then** the document is no wider
   than the viewport (no horizontal scrolling).
3. **Given** the product name configuration is changed, **When** the page reloads, **Then** every
   displayed occurrence changes with it (no hardcoded name elsewhere).
4. **Given** the home page, **When** it is inspected, **Then** it contains no feature links, sample
   business data, or placeholder content (Rule 15; exact content approved D-B0-06).

---

### User Story 4 - Repeatable local development and automated quality gate (Priority: P2)

A builder or reviewer agent (or the founder) can go from a fresh clone to a running application, a
running local database, and a full test run using documented steps, and every change is checked
automatically by the same gate: typecheck, lint, unit tests with money coverage enforcement,
database tests, and a browser smoke test.

**Why this priority**: B0's Definition of Done is "CI green". Every later batch relies on this gate
and on Rule 17's check list.

**Independent Test**: On a clean checkout, follow the documented steps; then push a change and
confirm every CI job runs and passes; introduce a deliberate money-helper coverage gap and confirm
the gate fails.

**Acceptance Scenarios**:

1. **Given** a fresh clone and the documented prerequisites, **When** the documented setup steps are
   followed, **Then** the application runs locally and the local database starts with no migrations.
2. **Given** the local database is running, **When** database tests run, **Then** at least one database
   test executes and passes, proving the database test harness works.
3. **Given** a pushed change, **When** CI runs, **Then** typecheck, lint, unit, database, and browser
   smoke checks each run as separate visible results and all pass.
4. **Given** money-helper coverage below 100% (lines, branches, functions, statements), **When** unit
   tests run, **Then** the run fails.
5. **Given** code that uses an unchecked type escape (`any`, `@ts-ignore`) or reads the device clock for
   a business date outside the date helper, **When** lint/typecheck runs, **Then** it fails.

---

### User Story 5 - Both coding agents follow identical rules (Priority: P3)

Claude Code and Codex read the same agent rules from the repository root, so either agent follows
Section 18 exactly.

**Why this priority**: Required by Sections 0.5 and 18; low effort, prevents divergent behavior.

**Independent Test**: Compare the two root rule files byte-for-byte and check that each contains
Section 18 of the master spec verbatim.

**Acceptance Scenarios**:

1. **Given** the repository root, **When** `CLAUDE.md` and `AGENTS.md` are compared, **Then** they are
   identical and each contains Section 18 verbatim.
2. **Given** either file drifts from the other or from Section 18, **When** CI runs, **Then** a check fails.

### Edge Cases

- Money input: empty or whitespace-only text; `.5` or `5.`; leading zeros (`007`); misplaced grouping separators (`1,00`); exponent notation (`1e3`); `NaN`/`Infinity`; Arabic-Indic digits (`٢٠٠٠٠`) and Arabic separators (`٬`, `٫`); a currency suffix typed by the user (approved D-B0-01).
- Money values outside the signed-64-bit piaster range, noncanonical decimal strings at JSON boundaries, and negative values passed to formatting (approved D-B0-02/D-B0-03).
- Rounding with a zero or negative denominator or step, negative inputs, or out-of-range monetary results (approved D-B0-04).
- Zero amount formats as `0.00 ج.م`.
- Cairo dates at exactly 00:00:00 local, on the DST start and end days, on 29 February, and at
  31 December → 1 January.
- Business-date text with valid shape but impossible calendar values (`2026-02-29`, `2026-04-31`).
- Test runs on machines whose system time zone is not Cairo.
- Local environment without the container runtime required by the local database (see Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

**Money (Section 2 P4, Rule 3, Sections 8.1–8.2, 11)**

- **FR-001**: The system MUST represent every money amount as a whole number of piasters (1 EGP =
  100 piasters) and MUST NOT use fractional/floating-point arithmetic for money anywhere.
- **FR-002**: The system MUST provide one shared parser that converts typed EGP text into exact piasters and rejects invalid input with an approved Arabic message. It accepts Western or Arabic-Indic digits (not mixed), valid grouping from one separator family, and at most two decimal places; rejects signs, malformed input, excess decimals and values above the PostgreSQL signed-`bigint` maximum (approved D-B0-01/D-B0-03; exact cases in `contracts/money.md`).
- **FR-003**: The system MUST provide one shared formatter rendering piasters as `20,000.00 ج.م` by default (Western digits), optionally using Arabic-Indic digits. Negative amounts retain a visible leading ASCII minus with LTR isolation; positives and zero preserve the plain space before `ج.م` (approved D-B0-02/D-B0-05/D-B0-10). Exact outputs, including the signed-64-bit minimum and the Arabic-Indic negative, are listed in `contracts/money.md`.
- **FR-004**: The system MUST provide integer rounding primitives with Section 8.2 semantics: round-half-up of a ratio, ceil-to-step of a ratio, and floor of a ratio. All operands are `bigint`, numerators non-negative, denominators/steps positive, returned piasters checked against signed-64-bit bounds (approved D-B0-04/D-B0-03).
- **FR-005**: Monetary values MUST be `bigint` piasters in TypeScript within PostgreSQL signed-`bigint` range. A B0 money helper MUST convert values to/from validated canonical decimal integer strings at JSON boundaries without ever coercing via `number`, and MUST reject input of the wrong runtime type (approved D-B0-03).
- **FR-006**: The installment schedule itself MUST NOT be computed in the application layer in B0;
  the foundation provides only the rounding primitives (schedule preview is B5, Section 9.2).
- **FR-007**: The whole money module — parsing, formatting, rounding and JSON-wire conversion — MUST
  have 100% automated unit-test coverage (lines, branches, functions, statements), enforced as a
  failing check (Section 17 B0 DoD).

**Business dates (Section 2 P10, Rule 11, Section 12)**

- **FR-008**: The system MUST provide one shared date helper that returns the current Cairo business
  date (`Africa/Cairo`) as a calendar date value, independent of device and server time zones.
- **FR-009**: The date helper MUST convert any instant to its Cairo business date and MUST provide the
  half-open start/end instants of a given Cairo business day, correct on DST transition days.
- **FR-010**: The date helper MUST validate business-date text in `YYYY-MM-DD` form and reject
  impossible calendar dates.
- **FR-011**: Application code MUST NOT read the device clock for business dates outside the shared
  date helper; this MUST be enforced by an automated check (Rule 11).

**Application shell (Sections 0, 3, 11)**

- **FR-012**: The product name MUST exist in exactly one configuration location
  (`APP_NAME = { en: "Hesbetak", ar: "حسبتك" }`); UI text and page metadata MUST read it from there,
  and an automated check MUST fail if the name is hardcoded elsewhere in application code.
- **FR-013**: The application MUST render with Arabic language, right-to-left direction, and the
  IBM Plex Sans Arabic font on every page, with the UI component system configured for right-to-left
  use (Section 17 B0 "shadcn RTL"; configuration approved in D-B0-06).
- **FR-014**: The shell MUST be usable at a 360 px viewport width without horizontal scrolling
  (Section 11).
- **FR-015**: The shell MUST contain only a root home page with one `<h1>` showing `APP_NAME.ar` (approved D-B0-06) — no authentication, tenant, business-feature screens or placeholder content.
- **FR-016**: All user-facing strings MUST be Arabic; code, identifiers and comments MUST be English
  (Rule 13).

**Local development, tests and CI (Sections 3, 12, 17 B0, Rule 17)**

- **FR-017**: The repository MUST provide documented, repeatable steps to run the application, start
  the local database (with no migrations), and run all checks locally.
- **FR-018**: The repository MUST provide automated checks for typecheck, lint, unit tests, database
  tests, and a browser smoke test, each runnable by a single documented command.
- **FR-019**: CI MUST run all five checks on every push and pull request, and B0 is not done until CI
  is green (Section 17 B0 DoD).
- **FR-020**: Type checking MUST run in strict mode with unchecked indexed access enabled; lint MUST
  forbid `any` and `@ts-ignore` (Rule 14).
- **FR-021**: The browser smoke test MUST verify Arabic language, RTL direction, font, product name from
  configuration, and 360 px layout.
- **FR-022**: The database test harness MUST run at least one real passing database test without
  creating any B1 table, function, or migration.
- **FR-023**: Secrets MUST NOT be committed; only non-secret example environment settings for local
  development may be committed, and no privileged database key may be exposed to the browser
  (Section 12).

**Agent rules and records (Sections 0.5, 17, 18)**

- **FR-024**: Root `CLAUDE.md` and `AGENTS.md` MUST be identical and each MUST contain Section 18
  verbatim; an automated check MUST fail on drift.
- **FR-025**: `docs/DECISIONS.md` MUST be updated with B0 decisions, and a `CHANGELOG.md` MUST contain a
  short B0 entry (Section 17).
- **FR-026**: B0 MUST NOT add any B1+ data model, migration, table, RPC, account, or financial feature
  (Rule 2); the founder's root `HESBETAK_SPEC.md` MUST remain unmodified.
- **FR-027**: The batch report MUST list exact commands and results for typecheck, lint, unit, database, browser smoke, and seeded-scenario reconciliation, reporting reconciliation and all Section 14 financial acceptance tests as `not applicable` in B0 (no ledger exists yet). Under approved D-B0-09, local pgTAP/Playwright attempts that cannot run are reported `blocked` with actual errors, while successful CI runs of those same checks provide B0 evidence; B0 still requires all five CI jobs green.

### Key Entities

- **Money amount (piasters)**: a signed-64-bit `bigint` piaster value, transported as an exact decimal string at JSON boundaries; displayed in EGP only through the shared formatter.
- **Business date**: a Cairo calendar date (`YYYY-MM-DD`) with no time or zone component; derived from
  an instant only through the shared date helper.
- **Product name configuration**: the single source of the English and Arabic product name.
- **Agent rules files**: the two identical root files carrying Section 18.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the money module (parsing, formatting, rounding and JSON-wire conversion) is
  exercised by automated tests (lines, branches, functions, statements), and the check fails if it
  drops below 100%.
- **SC-002**: All Section 8.6 rounding intermediates listed in User Story 1 (600,000; 210,000; 310,350; 192,500) are reproduced exactly, with zero tolerance; signed-64-bit boundary values and a JSON-wire round trip above JavaScript's safe-integer range are reproduced exactly.
- **SC-003**: 100% of the Cairo boundary cases in User Story 2 return the expected date under at least two
  different machine time zones.
- **SC-004**: The documented setup and check commands run end to end from a fresh checkout with no
  undocumented step. B0 evidence: the CI jobs run the README's setup and check commands (a clean
  dependency install, local database start, the five check scripts; any CI-only flags are documented
  in the README) and all five pass. The local clean-machine walkthrough is a B1 entry obligation
  (approved D-B0-11).
- **SC-005**: CI shows 5 of 5 check groups (typecheck, lint, unit, database, browser smoke) passing on the
  B0 branch.
- **SC-006**: The home page renders RTL Arabic with the configured product name at 360 px with zero
  horizontal overflow.
- **SC-007**: The product name appears in exactly one application source location; the rules files are
  byte-identical and contain all 19 Section 18 rules verbatim.
- **SC-008**: Zero database migrations, tables, or functions exist after B0.

## Assumptions

- The tech stack is fixed by master spec Section 3; the plan applies it and this spec does not choose it.
- The local database requires a container runtime on the developer machine. It is not currently
  installed on the builder machine; local attempts are reported `blocked` with the exact error, and
  CI (which provides one) supplies the B0 pgTAP/Playwright evidence under approved D-B0-09.
- Local setup and CI need network access for the dependency install, the Google font download at build
  time, Playwright Chromium and Supabase images (see `quickstart.md` prerequisites).
- The authoritative installment math runs in the database from B5 onward; B0 application-layer rounding
  primitives exist for shared integer semantics and must agree with Section 8.2.
- Date display formatting (e.g. day/month order) is not needed by B0 and is deferred to the first batch
  that displays dates.
- The seeded-scenario reconciliation check (Rule 17) has no ledger to run against in B0 and is reported
  as `not applicable`.
- `docs/ACCOUNTING.md` (Section 3.1) starts in B1 (approved D-B0-08).
- B1 carry-over, not testable in B0 (amended Rule 3 / D-B0-03): financial database reads and RPC
  results must expose monetary values as text before JSON decoding, with a documented adapter and
  DB-path round-trip tests. Listed in `docs/DECISIONS.md` § B1 entry obligations.
- CI-only pgTAP/Playwright evidence is permitted for B0 when local infrastructure is blocked; locally run exact commands and report their failures honestly (approved D-B0-09).
- The founder's root `HESBETAK_SPEC.md` stays untracked and unmodified; the canonical copy is
  `docs/HESBETAK_SPEC.md` (existing decision, 2026-09-27).
