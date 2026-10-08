---

description: "Task list for B0 — Foundation"
---

# Tasks: B0 — Foundation

**Input**: Design documents from `/specs/001-b0-foundation/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: REQUIRED. The spec mandates automated checks (FR-007, FR-011, FR-012, FR-018–FR-022, FR-024).
Money and date tests are written first and must fail before the implementation task runs.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

**Gating**: T001 reconciles the founder-approved D-B0-01…D-B0-11 choices, the Section 18 Rule 3 amendment and the B1 entry obligations and re-runs analysis before any implementation. Decision annotations identify the approved choices in `docs/DECISIONS.md`; they are not unresolved blockers. No B1 or merge to `main` is authorized.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks, no `npm install`)
- **[Story]**: US1–US5 from spec.md

## Path Conventions

Single Next.js project at repository root: `src/`, `tests/unit/`, `tests/e2e/`, `supabase/` (plan.md §Project Structure).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Founder gates, then project initialization

- [X] T001 Verify the approved D-B0-01…D-B0-11 entries (D-B0-11 answers the SC-004 deferral), the Section 18 Rule 3 amendment and § B1 entry obligations in docs/DECISIONS.md, and the updated B0 spec, plan, research, data model, quickstart, contracts, checklists and tasks; re-run `/speckit-analyze` and resolve findings before T002. Do not alter the founder's root spec.
- [X] T002 approved D-B0-07 Create git branch `001-b0-foundation` from the current unborn `main` (no commits yet; the first `docs:` commit is the branch root) and make the first `docs:` commit containing docs/, .specify/, .claude/skills/, .agents/skills/, specs/ — leaving the root HESBETAK_SPEC.md untracked and unmodified
- [X] T003 Create package.json (name `hesbetak`, private, `engines.node` `>=22 <25`, scripts exactly as specs/001-b0-foundation/contracts/quality-gates.md) and .nvmrc containing `22`; then run ONE `npm install` for all Setup dependencies — runtime: `next@14.2.35`, `react@18`, `react-dom@18`, `date-fns@3`, `date-fns-tz@3.2.0`, `clsx`, `tailwind-merge`, `@radix-ui/react-direction` (approved D-B0-06); dev: `typescript@5`, `@types/react@18`, `@types/react-dom@18`, `@types/node`, `tailwindcss@3.4.19`, `postcss`, `autoprefixer`, `eslint@8`, `eslint-config-next@14.2.35`, `@typescript-eslint/eslint-plugin`, `@typescript-eslint/parser`, `vitest`, `@vitest/coverage-v8`, `@playwright/test`, `supabase@2.118.0` — producing package-lock.json (no `lucide-react` in B0). If disk/cache installation fails, record the exact error; do not claim setup passed.
- [X] T004 Create tsconfig.json, complete so `tsc --noEmit` works before any `next build` and `next build` does not rewrite it: `"target": "ES2020"` (so `bigint` literals compile), `lib` `["dom", "dom.iterable", "esnext"]`, `allowJs: false`, `skipLibCheck: true`, `strict: true`, `noUncheckedIndexedAccess: true`, `noEmit: true`, `esModuleInterop: true`, `module: "esnext"`, `moduleResolution: "bundler"`, `resolveJsonModule: true`, `isolatedModules: true`, `jsx: "preserve"`, `incremental: true`, `plugins` `[{ "name": "next" }]`, `paths` `@/*` → `./src/*`, `include` `["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"]`, `exclude` `["node_modules"]`; next.config.mjs (no experimental flags), and next-env.d.ts at repo root
- [X] T005 [P] Create .gitignore covering `node_modules/`, `.next/`, `coverage/`, `playwright-report/`, `test-results/`, `*.tsbuildinfo` (from `incremental: true` in T004), `.env*`, `supabase/.temp/`, and `.claude/settings.local.json` (Spec Kit init warns the agent folder can hold local credentials; Section 12 secrets rule)
- [X] T006 [P] Create tailwind.config.ts (content `./src/**/*.{ts,tsx}`, `fontFamily.sans` = `var(--font-plex-arabic)` + system fallback, and approved D-B0-06 the shadcn CSS-variable color names) and postcss.config.mjs (tailwindcss + autoprefixer)
- [X] T007 [P] approved D-B0-06 Configure shadcn/ui for Tailwind v3 (research R4): components.json (style `new-york`, `tailwind.config` `tailwind.config.ts`, `css` `src/app/globals.css`, `cssVariables: true`, aliases `@/components`, `@/components/ui`, `@/lib/utils`) and src/lib/utils.ts exporting `cn()`; add no components
- [X] T008 [P] Create .eslintrc.json per research R9: extends `next/core-web-vitals`; `@typescript-eslint/no-explicit-any: error` and `@typescript-eslint/ban-ts-comment: error` for all linted files; `no-restricted-syntax` forbidding `new Date()` with zero arguments and `Date.now()` in `src/**` with an override exempting `src/lib/dates.ts`; in `src/lib/money.ts` only, forbid unsafe number conversions of money — `parseFloat`, `parseInt`, `Number.parseFloat`, `Number.parseInt`, `.toFixed`, `Number(...)`, `new Number(...)`, unary `+` — keeping the two `Date` selectors in that file's `no-restricted-syntax` override (FR-001, FR-005, amended Rule 3); do not ban `Math.*` or `Intl.NumberFormat` (research R9); `ignorePatterns` `.next/`, `coverage/`, `playwright-report/`, `test-results/`; `lint` script `eslint . --ext .ts,.tsx,.mjs --max-warnings 0`; no rule disabled
- [X] T009 [P] Create vitest.config.ts: `environment: 'node'`, `pool: 'forks'`, `include: ['tests/unit/**/*.test.ts']`, alias `@` → `src`, coverage provider `v8`, `include: ['src/lib/**']`, per-file thresholds for `src/lib/money.ts` and `src/lib/dates.ts` = 100 for lines, branches, functions, statements
- [X] T010 [P] Create playwright.config.ts: `testDir: 'tests/e2e'`, Chromium projects `desktop` (1280×800) and `mobile-360` (360×800), `webServer` command `npm run build && npm run start`, port 3000, `reuseExistingServer: !process.env.CI`; attempt `npx playwright install chromium` locally and report its exact result (approved D-B0-09: if local disk/network blocks it, CI must still install Chromium and run E2E successfully).
- [X] T011 [P] Run `npx supabase init` non-interactively to create supabase/config.toml; set `[db.seed] enabled = false` because no seed.sql exists in B0 (Section 3.1's seed needs tenant/product tables from B1; Rule 2); confirm supabase/migrations/ contains no files

**Checkpoint**: tooling in place. approved D-B0-07 commit `feat: scaffold Next.js 14 foundation tooling`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Product-name config and the RTL root layout every page and test depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T012 Create src/config/app.ts exporting `APP_NAME = { en: "Hesbetak", ar: "حسبتك" } as const` — the only file in `src/` that may contain either string (FR-012)
- [X] T013 [P] Create src/app/globals.css with Tailwind `base`/`components`/`utilities` layers and approved D-B0-06 the shadcn neutral CSS-variable tokens (Section 11 neutral base; accent color not chosen in B0)
- [X] T014 [P] approved D-B0-06 Create src/components/direction-provider.tsx (`'use client'`) wrapping `@radix-ui/react-direction` `DirectionProvider` with `dir="rtl"`
- [X] T015 Create src/app/layout.tsx: `<html lang="ar" dir="rtl">`; `IBM_Plex_Sans_Arabic` from `next/font/google` (subsets `arabic` + `latin`, weights 400/500/600/700, `display: 'swap'`, `variable: '--font-plex-arabic'`); body wrapped in the direction provider (T014, approved D-B0-06); `metadata.title` and `metadata.applicationName` = `APP_NAME.ar` imported from src/config/app.ts (Section 0: metadata reads the constant) (depends on T012–T014)

**Checkpoint**: foundation ready. approved D-B0-07 commit `feat: add RTL root layout and APP_NAME config`

---

## Phase 3: User Story 1 - Money values are always exact integer piasters (Priority: P1) 🎯 MVP

**Goal**: Shared parse/format/rounding helpers in integer piasters (FR-001–FR-007)

**Independent Test**: `npm run test:unit` passes and reports 100% lines/branches/functions/statements for src/lib/money.ts

### Tests for User Story 1 (write first; must fail before T019)

- [X] T016 [P] [US1] Write tests/unit/money-parse.test.ts covering every row of contracts/money.md §Parsing edge cases as exact `bigint` piasters, including signed-64-bit maximum/overflow, and asserting every `MoneyParseError` code maps to the approved Arabic message in `MONEY_PARSE_MESSAGES_AR` (D-B0-01/D-B0-03). In the same task write tests/unit/money-wire.test.ts for exact decimal-string round trips at `0n`, values above `Number.MAX_SAFE_INTEGER`, signed-64-bit min/max, plus `MoneyError` for a JSON number or other non-string passed to `piastersFromWire`, for non-`bigint` values passed to `toPiasters`/`formatMoney`/`piastersToWire`, for noncanonical strings and for overflow and underflow (`"9223372036854775808"`, `"-9223372036854775809"`); `parseMoney` with a non-string returns `invalid_format` without throwing; tests must fail before implementation.
- [X] T017 [P] [US1] Write tests/unit/money-format.test.ts using `toPiasters(...)` with `n` literals, asserting exact strings: `2_000_000n` → `"20,000.00 ج.م"`; `0n` → `"0.00 ج.م"`; `5n` → `"0.05 ج.م"`; `-2_000_000n` → `"\u2066-20,000.00\u2069 ج.م"`; `2_000_000n` with `{ digits: "arab" }` → `"٢٠٬٠٠٠٫٠٠ ج.م"`; `-2_000_000n` with `{ digits: "arab" }` → `"\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م"` (D-B0-10); `MAX_PIASTERS` (typed `Piasters`) → `"92,233,720,368,547,758.07 ج.م"`; `MIN_PIASTERS` (typed `Piasters`) → `"\u2066-92,233,720,368,547,758.08\u2069 ج.م"`; out-of-range or non-`bigint` runtime values throw; `toPiasters`/`isPiasters` validate signed-64-bit `bigint` bounds (D-B0-02/03/05).
- [X] T018 [P] [US1] Write tests/unit/money-rounding.test.ts with `bigint` vectors in contracts/money.md §Required exact test vectors (600_000n; 210_000n; 150_000n; 310_350n; 192_500n; 28_571n; ties 3n and 0n); a product `a × b` exceeding signed-64-bit while the quotient still fits, and `MoneyError` for a non-`bigint` argument, negative operands, zero/negative divisor or step, and out-of-range monetary results (D-B0-03/04).


### Implementation for User Story 1

- [X] T019 [US1] Create src/lib/money.ts with `Piasters = bigint` brand, `PIASTERS_PER_EGP = 100n`, PostgreSQL signed-64-bit bounds, `MoneyError`, `toPiasters`, `isPiasters`, `piastersToWire` and `piastersFromWire` per contracts/money.md; only canonical decimal strings cross JSON boundaries, no `number` coercion (D-B0-03). B0 adds no DB adapter or financial SQL.
- [X] T020 [US1] Implement `parseMoney` and `MONEY_PARSE_MESSAGES_AR` in src/lib/money.ts using string/digit → `bigint` processing only — no `parseFloat`, `Number(text)` on monetary text, `toFixed`, or `Intl.NumberFormat` on fractional money (research R6); signed-64-bit overflow returns approved `out_of_range` error (D-B0-01/03).
- [X] T021 [US1] Implement `formatMoney` for signed-64-bit `bigint` piasters with integer digit grouping, exactly two decimals, ` ج.م` suffix, approved negative isolation and Arabic-Indic option, exactly as the contracts/money.md vectors (D-B0-02/05/10).
- [X] T022 [US1] Implement `mulDivRoundHalfUp`, `mulDivFloor`, `divCeilToStep` with `bigint` operands and signed-64-bit result checks; no installment-schedule function (FR-006, D-B0-04).
- [X] T023 [US1] Run `npm run typecheck`, `npm run test:unit` and `npm run lint`; confirm T016–T018 pass and src/lib/money.ts coverage is 100/100/100/100; save the coverage summary for the batch report

**Checkpoint**: US1 verifiable. approved D-B0-07 commits `test: add money helper vectors` and `feat: add integer-piaster money helpers`

---

## Phase 4: User Story 2 - Business dates are always Cairo dates (Priority: P1)

**Goal**: Africa/Cairo business-date helpers independent of machine time zone (FR-008–FR-011)

**Independent Test**: `npm run test:unit` passes all date vectors under TZ = UTC, America/New_York, Asia/Tokyo, with 100% coverage of src/lib/dates.ts

### Tests for User Story 2 (write first; must fail before T025)

- [X] T024 [P] [US2] Write tests/unit/dates.test.ts with every vector in contracts/dates.md, each asserted after setting `process.env.TZ` to `UTC`, `America/New_York`, and `Asia/Tokyo`; `cairoToday()` via `vi.useFakeTimers()` + `vi.setSystemTime(new Date('2026-01-14T22:30:00Z'))` → `2026-01-15`; `toBusinessDate(new Date('invalid'))` and `cairoDayRange('2026-02-30' as BusinessDate)` throw `BusinessDateError`

### Implementation for User Story 2

- [X] T025 [US2] Using date-fns@3 and date-fns-tz@3.2.0 already installed in T003 (no second dependency install), create src/lib/dates.ts with `BUSINESS_TIME_ZONE = "Africa/Cairo"`, `BusinessDate` brand, `BusinessDateError`, `toBusinessDate`, `cairoToday`, `parseBusinessDate`, `isBusinessDate`, `cairoDayRange` per contracts/dates.md ("Matches `^\d{4}-\d{2}-\d{2}$` **and** is a real calendar date (round-trip check)", data-model.md); day start = earliest instant whose Cairo date is the given date, with the DST-gap handling in research R7
- [X] T026 [US2] Run `npm run typecheck`, `npm run test:unit` (dates 100/100/100/100) and `npm run lint`; temporarily add `new Date()` to src/app/layout.tsx, confirm `npm run lint` fails, then remove it (FR-011 negative check); record results

**Checkpoint**: US1 and US2 verifiable. approved D-B0-07 commits `test: add Cairo business-date vectors` and `feat: add Africa/Cairo date helpers`

---

## Phase 5: User Story 3 - A working Arabic-first RTL application shell (Priority: P2)

**Goal**: Home page in Arabic RTL with the configured product name, usable at 360 px (FR-012–FR-016)

**Independent Test**: `npm run test:e2e` passes on `desktop` and `mobile-360`; the product-name guard passes

### Tests for User Story 3

- [X] T027 [P] [US3] Write tests/e2e/smoke.spec.ts per research R11: `lang="ar"`, `dir="rtl"`, `document.title` equals `APP_NAME.ar` imported from src/config/app.ts, computed `font-family` of `body` matches `/IBM[ _]Plex[ _]Sans[ _]Arabic/`, `document.documentElement.scrollWidth <= window.innerWidth`, zero console errors; and approved D-B0-06 the single `<h1>` text equals `APP_NAME.ar`
- [X] T028 [P] [US3] Write tests/unit/guard-app-name.test.ts: fails if `Hesbetak` or `حسبتك` appears in any file under `src/` other than src/config/app.ts (FR-012)

### Implementation for User Story 3

- [X] T029 [US3] approved D-B0-06 Create src/app/page.tsx rendering `<main>` with a single `<h1>{APP_NAME.ar}</h1>`, logical Tailwind utilities only, no links, sample data, or other copy (Rule 15)
- [X] T030 [US3] Run `npm run typecheck`; attempt `npx playwright install chromium`, `npm run test:e2e` (both projects) and `npm run test:unit` locally; record actual results. Under approved B0-only D-B0-09, local E2E blocked by disk/network is reported with exact error, never as locally passed; CI E2E must pass.

**Checkpoint**: US1–US3 verifiable. approved D-B0-07 commits `test: add RTL shell smoke and app-name guard` and `feat: add Arabic RTL home page`

---

## Phase 6: User Story 4 - Repeatable local development and automated quality gate (Priority: P2)

**Goal**: Local Supabase + pgTAP harness, documented setup, five-job CI (FR-017–FR-023)

**Independent Test**: `npm run test:db` passes on a running local Supabase (or is recorded `blocked` per D-B0-09); the CI workflow defines all five jobs — 5/5 green is verified in T042

### Tests for User Story 4

- [X] T031 [P] [US4] Write supabase/tests/000_harness.test.sql (`begin` … `rollback`): `create extension if not exists pgtap with schema extensions`; `plan(4)`; `Africa/Cairo` exists in `pg_timezone_names`; `(timestamptz '2026-01-14 22:00:00+00' at time zone 'Africa/Cairo')::date = date '2026-01-15'`; zero rows in `pg_tables` for schema `public`; zero functions in schema `public`
- [X] T032 [P] [US4] Write tests/unit/guard-no-migrations.test.ts: fails if any file exists in supabase/migrations/ (FR-026, SC-008)

### Implementation for User Story 4

- [X] T033 [US4] Create .github/workflows/ci.yml, using the setup and check commands documented in README.md (SC-004 B0 evidence; CI-only flags such as `supabase start -x …` and `playwright install --with-deps` must also be documented in README.md), with jobs `typecheck`, `lint`, `unit`, `pgtap`, `e2e` exactly as contracts/quality-gates.md; triggers `push` and `pull_request`; `actions/setup-node` with `node-version-file: .nvmrc` and npm cache; `pgtap` runs `npx supabase start -x` with the exact service list in contracts/quality-gates.md (verify the names with `npx supabase start --help` for `supabase@2.118.0`, fix the contract if they differ, and use the same list in README.md), then `npm run test:db`
- [X] T034 [US4] Create README.md with prerequisites (Node 22, Docker, disk, network), setup, the one-command-per-check list from specs/001-b0-foundation/quickstart.md, and the CI-only command variants (`npx supabase start -x …` database-only, `npx playwright install --with-deps chromium`) (FR-017, SC-004)
- [X] T035 [US4] Attempt `npm run db:start` and `npm run test:db` locally; record exact outcomes. Under approved B0-only D-B0-09, if blocked by missing Docker/disk report `blocked` and the actual error, never `passed`; CI must still run and pass the DB job. Prepare local DB environment before B1.

**Checkpoint**: US1–US4 verifiable locally. approved D-B0-07 commits `test: add pgTAP harness and migration guard`, `test: add CI quality gate`, `docs: add local setup guide`

---

## Phase 7: User Story 5 - Both coding agents follow identical rules (Priority: P3)

**Goal**: Identical root rule files with Section 18 verbatim (FR-024)

**Independent Test**: `npm run test:unit` agent-rules guard passes; editing one character in AGENTS.md makes it fail

- [X] T036 [P] [US5] Create CLAUDE.md containing lines 742–762 of docs/HESBETAK_SPEC.md exactly (including the amended Rule 3 of 2026-09-27) (the `## 18. Agent Rules …` heading and rules 1–19), UTF-8, LF line endings
- [X] T037 [US5] Create AGENTS.md byte-identical to CLAUDE.md (depends on T036)
- [X] T038 [US5] Write tests/unit/guard-agent-rules.test.ts: extracts the Section 18 block from docs/HESBETAK_SPEC.md; fails unless CLAUDE.md and AGENTS.md are byte-identical and each contains that block verbatim; run it, then run the one-character negative check and revert

**Checkpoint**: all stories verifiable. approved D-B0-07 commit `docs: add identical CLAUDE.md and AGENTS.md agent rules`

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T039 [P] Create CHANGELOG.md with a short `B0 — Foundation` entry (scope delivered, checks, deferred items), including a "B1 entry obligations" list copied from docs/DECISIONS.md § B1 entry obligations (DB monetary text before JSON decoding with adapter docs and round-trip tests; local Docker/disk; local clean-machine walkthrough; `docs/ACCOUNTING.md`)
- [X] T040 [P] Update docs/DECISIONS.md: plan choices from research.md (Node 22, npm, Tailwind v3, date-fns v3, `eslint .` instead of `next lint`) and "no lint rules disabled" (Rule 14)
- [X] T041 Run every quickstart.md scenario V1–V6 and every negative check; record exact commands and results
- [X] T042 approved D-B0-07 Commit T039–T040 (`docs:`), push `001-b0-foundation`, and confirm 5/5 CI jobs green on the push run (V7); record the run URL. Open a PR only if `git ls-remote --heads origin` shows a `main` branch; otherwise never create or push `main` (D-B0-07) and record that no PR base exists
- [X] T043 Prepare the B0 batch report per contracts/quality-gates.md §B0 batch report: changed-file list; exact local commands/results for typecheck, lint, unit (coverage numbers), pgTAP, Playwright (`passed` only if that exact local command ran and passed; else `blocked` + error) plus CI run link/status for all five jobs under D-B0-09; `not applicable — no ledger or seed scenario exists in B0`; `not applicable — Section 14 assigns no test to B0`; all review lines listed in contracts/quality-gates.md (FR-016/Rule 13, FR-023, Rules 1, 3, 15, 16, 18–19); SC-004 evidence (CI jobs run the README commands from a fresh checkout; local clean-machine walkthrough deferred to B1 under D-B0-09); the four B1 entry obligations from docs/DECISIONS.md; confirmation that the root HESBETAK_SPEC.md SHA-256 is still `084472721173072DD9DEB1E1695371F05F58A6A813A897CF6B12AFCDCA81B12D` and supabase/migrations/ has no files; known risks
- [X] T044 Run `/speckit-converge`; implement any appended tasks and converge again; then stop for Codex review and Abdullrahman's explicit B0 approval (no B1 work)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 → T002 → T003 → T004 → T005–T011 [P] (config files only; the single install happened in T003)
- **Foundational (Phase 2)**: after Setup; T015 depends on T012–T014; blocks all stories
- **Stories run sequentially in priority order: US1 → US2 → US3 → US4 → US5.** The whole-suite `npm run test:unit` and `next build` type-check every present test file, so one story's failing-first tests would break another story's checkpoint if developed concurrently. Each story remains independently testable at its own checkpoint.
- **US1, US2 (P1)**: after Foundational; no code dependency between them
- **US3 (P2)**: after US2 · **US4 (P2)**: after US3 · CI green for all five jobs is verified once, in T042, after every story exists
- **US5 (P3)**: after US4 (no code dependency; sequenced for a clean checkpoint)
- **Polish**: after all stories

### Approved decision dependencies

- D-B0-01: T016, T020 · D-B0-02 and D-B0-10: T017, T021 · D-B0-03: T016–T022 · D-B0-04: T018, T022 · D-B0-05: T017, T021
- D-B0-06: T003 (three packages), T006 (shadcn color names), T007, T013 (shadcn tokens), T014, T015 (direction provider), T027 (`<h1>` assertion), T029
- D-B0-07: T002, all checkpoint commits, T042 · D-B0-09: T010, T030, T035 (local errors and CI-only B0 fallback) · D-B0-11: T033, T034, T043 (SC-004 CI evidence; local walkthrough in B1)
- These founder decisions are confirmed in `docs/DECISIONS.md`; no founder clarification remains blocking B0 implementation.

### Within Each User Story

Tests first (must fail) → implementation → run and record results → checkpoint commit.

### Parallel Opportunities

- Setup: T005–T011 (no installs)
- Foundational: T013, T014
- US1 tests T016–T018 together
- US3 T027/T028; US4 T031/T032; US5 T036 alongside T038 drafting
- Polish T039/T040

---

## Parallel Example: User Story 1

```text
Task: "Write tests/unit/money-parse.test.ts (T016)"
Task: "Write tests/unit/money-format.test.ts (T017)"
Task: "Write tests/unit/money-rounding.test.ts (T018)"
# then T019 → T020 → T021 → T022 (same file, sequential) → T023
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 (with founder decisions) → Phase 2
2. Phase 3 (money) → validate 100% coverage — the B0 DoD's named item
3. Continue with US2 (dates), US3 (shell), US4 (gate), US5 (rules)

### Incremental Delivery

Each story ends at a checkpoint with its own test command and commit (Rule 16: only `feat:`, `fix:`,
`test:`, `db:`, `docs:`). B0 is done only when T042 shows CI green and Abdullrahman approves (Section 17).

---

## Notes

- 44 tasks. [P] = different files, no dependency on incomplete tasks, no package installation.
- No task creates a migration, table, RPC, route group, Supabase client factory, seed, generated types, or `lucide-react` dependency (Rule 2, D-B0-06).
- A check is reported `passed` only when its exact command ran and passed; otherwise `blocked`/`not applicable` with the reason.

---

## Phase 9: Convergence

- [X] T045 After Abdullrahman confirms the PR-base option recorded in docs/DECISIONS.md (2026-09-29), reconcile `001-b0-foundation` with `origin/main` accordingly and open the PR per T042 (partial) — option A approved; merged in `7de20b1`; PR https://github.com/AbdullrahmanSayed/Hesbetak/pull/1
- [X] T046 Remove the CI `retries` setting from playwright.config.ts so a flaky smoke failure fails the gate per plan: R11 / contracts/quality-gates.md `e2e` (unrequested)
- [X] T047 Review the binary-search `cairoDayRange` boundaries in src/lib/dates.ts that replace research R7's `fromZonedTime` fallback; after review exposed four-digit year boundary failures, Abdullrahman approved option B in docs/DECISIONS.md, the implementation now supports civil years `0001`–`9999`, and exact boundary regression tests pass per T025