# Implementation Plan: B0 — Foundation

**Branch**: `001-b0-foundation` (not yet created — D-B0-07) | **Date**: 2026-09-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-b0-foundation/spec.md`

**Plan input (verbatim, `docs/SPECKIT_WORKFLOW.md` B0)**: "Follow Sections 3, 8.1–8.2, 11–12, 17 B0, 18. Set up Next.js 14 App Router, TS strict + noUncheckedIndexedAccess, Tailwind, shadcn/ui RTL, IBM Plex Sans Arabic; Supabase local and CI; src/config/app.ts APP_NAME; src/lib/money.ts integer-piaster parse/format/rounding and src/lib/dates.ts Africa/Cairo helpers. Use Vitest, pgTAP, Playwright smoke. Copy Section 18 verbatim into identical CLAUDE.md and AGENTS.md. No B1 migrations. Verify exact 100% money-helper unit coverage for parse/format/rounding; test Cairo date boundaries. Update DECISIONS and CHANGELOG."

## Summary

B0 delivers the foundation only: a Next.js 14 App Router shell rendered in Arabic RTL with IBM Plex Sans
Arabic and the product name from `src/config/app.ts`; exact integer-piaster money helpers (parse,
format, Section 8.2 rounding primitives) with enforced 100% coverage; Africa/Cairo business-date
helpers tested across midnight, DST, month/year ends and machine time zones; local Supabase with a
pgTAP harness and zero migrations; a Playwright smoke test; a five-job GitHub Actions gate; identical
`CLAUDE.md`/`AGENTS.md` carrying Section 18 verbatim; `CHANGELOG.md` and `docs/DECISIONS.md` updates.
Technical choices are in [research.md](./research.md). Abdullrahman confirmed D-B0-01…D-B0-11 in `docs/DECISIONS.md` and amended Section 18 Rule 3 (constitution 2.0.0): notably `bigint` piasters with validated decimal-string JSON transport (D-B0-03), authorized B0 branch/commits/push (D-B0-07), and CI-only pgTAP/Playwright evidence as a B0-only fallback (D-B0-09).

## Technical Context

**Language/Version**: TypeScript 5.x (`target` ES2020 for `bigint` literals, `strict`, `noUncheckedIndexedAccess`); Node.js 22 LTS in CI (R2); SQL (pgTAP test only)

**Primary Dependencies**: `next@14.2.35`, React 18, `tailwindcss@3.4.19`, shadcn/ui configuration (Tailwind v3 variant) with `clsx`, `tailwind-merge`, `@radix-ui/react-direction` (no components or `lucide-react` until first used, D-B0-06); `date-fns@3`, `date-fns-tz@3.2.0`; dev: `supabase@2.118.0` CLI, Vitest + `@vitest/coverage-v8`, `@playwright/test`, ESLint 8 + `eslint-config-next@14.2.35` + `@typescript-eslint`

**Storage**: Supabase local (Postgres) started with no migrations; no application data in B0

**Testing**: Vitest (unit, coverage thresholds, repository guards), pgTAP via `supabase test db`, Playwright (Chromium desktop + 360 px)

**Target Platform**: Web — Vercel (app) + Supabase (DB) per Section 3; B0 runs locally and in GitHub Actions only (no deployment in B0)

**Project Type**: Web application (single Next.js project; database assets under `supabase/`)

**Performance Goals**: None measurable in B0 (Section 12 targets concern POS/dashboard/reports, which do not exist yet)

**Constraints**: `bigint` piasters in TypeScript/Postgres, exact decimal strings at JSON boundaries (D-B0-03), no floating-point money (P4, Rule 3); business dates only via `lib/dates.ts` (P10, Rule 11); no `any`/`@ts-ignore` (Rule 14); no stubs or placeholder data (Rule 15); Next.js + Supabase only (Rule 18); zero B1 objects (Rule 2)

**Scale/Scope**: ~2 library modules, 1 page, 1 layout, 1 config file, 1 SQL test, 1 CI workflow, 3 test suites

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Rule | B0 applicability | Status |
|------|------------------|--------|
| P1 ledger source of truth, P2 balanced entries, P3 append-only, P5 RPC-only writes, P6 idempotency, P8 reconciliation, P9 lock date, P11 gapless numbers | No ledger, documents or postings exist in B0 | N/A — nothing built that could violate them |
| P4 integer piasters | `lib/money.ts` uses signed-64-bit `bigint` and decimal-string wire values, no `number` money or float APIs | PASS (design) |
| P7 tenant isolation | No tenant-scoped tables in B0 | N/A |
| P10 Cairo dates | `lib/dates.ts` with `Africa/Cairo`; TZ-independent tests; pgTAP parity check | PASS (design) |
| P12 audit trail | No postings or master data | N/A |
| Rule 1 spec is source of truth / DECISIONS | D-B0-01…D-B0-11 and the Rule 3 amendment approved and recorded; no new financial features | PASS (design; still requires implementation review) |
| Rule 2 current batch only | No B1 migrations, tables, RPCs, routes; deferred list in R14 | PASS |
| Rule 3 money (amended 2026-09-27): `bigint` in SQL/TS, decimal-string JSON, DB text before JSON decoding; no arithmetic in React | `lib/money.ts` `bigint` + wire helpers; page renders no money; DB text projection is a B1 entry obligation | PASS (design) |
| Rules 4–8 posting rules | No posting in B0 | N/A |
| Rule 9 migrations / generated types | No migration → no type generation in B0 | N/A |
| Rule 10 tenant_id + RLS + cross-tenant tests | No tables | N/A |
| Rule 11 no `new Date()` for business dates | Lint rule outside `lib/dates.ts` | PASS (design) |
| Rule 12 no interest/percent on customer surfaces | No installment surface | N/A |
| Rule 13 Arabic UI, English code | Arabic page and messages; English identifiers/comments | PASS (design) |
| Rule 14 strict TS, no `any`/`@ts-ignore`, no disabled lint rules | tsconfig + ESLint rules; no disables planned | PASS (design) |
| Rule 15 production-ready, no stubs | Deferred scaffolding not created (approved D-B0-06) | PASS (design) |
| Rule 16 small conventional commits | One commit per phase checkpoint using only `feat:`/`fix:`/`test:`/`db:`/`docs:`; branch/commits/push authorized by D-B0-07 | PASS (design) |
| Rule 17 run all checks + reconciliation | All five checks in CI; reconciliation reported `not applicable` | PASS (design) |
| Rule 18 Next.js + Supabase only | No other service | PASS |
| Rule 19 parallel agents on separate branches | Single builder; Codex reviews read-only | PASS |
| Section 0.5 identical CLAUDE.md/AGENTS.md | Created verbatim + guard test; agent-context extension not installed | PASS (design) |

**Gate result (pre-research)**: PASS, no violations. **Re-check after Phase 1 design**: PASS — the
contracts introduce no ledger, tenant, or posting object. Automated checks cover P4 and FR-001 (lint
unsafe-number-conversion ban in `money.ts`, coverage), P10 and Rule 11 (TZ-matrix tests, lint, pgTAP parity), Rule 14 (tsconfig, lint),
Rule 17 (CI), Section 0.5 (guard test), FR-012 and SC-008 (guard tests). Rules 1, 3 (no money
arithmetic in React), 13, 15, 16, 18 and 19 are covered by review lines in the B0 batch report
(contracts/quality-gates.md) and per-phase commit steps. **Re-check after `/speckit-analyze` fixes**:
PASS.

## Project Structure

### Documentation (this feature)

```text
specs/001-b0-foundation/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   ├── money.md
│   ├── dates.md
│   └── quality-gates.md
├── checklists/
│   ├── requirements.md  # /speckit-specify spec-quality checklist
│   └── foundation.md    # /speckit-checklist requirements-quality checklist
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
/
├── CLAUDE.md                     # Section 18 verbatim (identical to AGENTS.md)
├── AGENTS.md                     # Section 18 verbatim
├── CHANGELOG.md                  # B0 entry
├── README.md                     # local setup and check commands (FR-017)
├── .nvmrc                        # 22
├── .gitignore                    # node_modules, .next, coverage, test results, .env*, local agent state
├── package.json / package-lock.json
├── tsconfig.json                 # target ES2020, strict + noUncheckedIndexedAccess
├── next.config.mjs
├── next-env.d.ts                 # Next.js generated type reference
├── tailwind.config.ts / postcss.config.mjs
├── components.json               # shadcn/ui (Tailwind v3)
├── .eslintrc.json
├── vitest.config.ts              # node env, forks pool, per-file 100% thresholds
├── playwright.config.ts          # chromium desktop + 360 px, webServer = build + start
├── .github/workflows/ci.yml      # typecheck, lint, unit, pgtap, e2e
├── docs/                         # existing; DECISIONS.md updated
├── supabase/
│   ├── config.toml               # from `supabase init`; seed disabled until B1
│   ├── migrations/               # must contain no files in B0 (guard test)
│   └── tests/000_harness.test.sql
├── src/
│   ├── app/
│   │   ├── layout.tsx            # <html lang="ar" dir="rtl">, font, DirectionProvider, metadata from APP_NAME
│   │   ├── page.tsx              # APP_NAME.ar heading only (D-B0-06)
│   │   └── globals.css           # Tailwind layers + shadcn CSS variables
│   ├── components/
│   │   ├── direction-provider.tsx  # client wrapper for Radix DirectionProvider (rtl)
│   │   └── ui/                   # shadcn components, only if used
│   ├── config/app.ts             # APP_NAME
│   └── lib/
│       ├── money.ts
│       ├── dates.ts
│       └── utils.ts              # shadcn cn()
└── tests/
    ├── unit/
    │   ├── money-parse.test.ts
    │   ├── money-format.test.ts
    │   ├── money-rounding.test.ts
    │   ├── money-wire.test.ts
    │   ├── dates.test.ts
    │   ├── guard-app-name.test.ts
    │   ├── guard-no-migrations.test.ts
    │   └── guard-agent-rules.test.ts
    └── e2e/
        └── smoke.spec.ts
```

**Structure Decision**: single Next.js project matching master spec Section 3.1; unit tests live in
`tests/unit/` next to the spec-defined `tests/e2e/`. Section 3.1 paths with no B0 consumer are not
created (research R14, D-B0-06).

## Implementation phases (input to /speckit-tasks)

1. **Gate**: founder decisions D-B0-01…D-B0-11 and the Rule 3 amendment recorded; branch created under D-B0-07; B0-only CI fallback for local Docker/disk accepted under D-B0-09. B1 DB work waits for local infrastructure.
2. **Setup**: one dependency install **including `date-fns` and `date-fns-tz`**; Next 14 + TS config; Tailwind v3; shadcn/ui configuration (D-B0-06); ESLint including the Rule 11 `new Date()` rule and the `money.ts` unsafe-number-conversion ban; Vitest; Playwright; Supabase CLI init; npm scripts; `.gitignore`, `.nvmrc`.
3. **Foundational**: `APP_NAME`, `globals.css`, direction provider (D-B0-06), root layout (RTL, font,
   metadata).
4. **US1 money**: tests from `contracts/money.md` first (including exact signed-64-bit and wire-string round trips), then `lib/money.ts`; 100% coverage threshold.
5. **US2 dates**: tests from `contracts/dates.md` first, then `lib/dates.ts`; lint negative check.
6. **US3 shell**: home page; Playwright smoke (desktop + 360 px); product-name guard.
7. **US4 gate**: pgTAP harness; no-migrations guard; complete five-job CI workflow; README steps.
8. **US5 rules**: `CLAUDE.md`, `AGENTS.md`, agent-rules guard.
9. **Polish**: `CHANGELOG.md`, `docs/DECISIONS.md`, push and CI green, batch report with exact
   commands/results, review lines, and `not applicable` lines.

Stories run sequentially in priority order (US1 → US2 → US3 → US4 → US5): the whole-suite unit command
and `next build` type-check every present test file, so a story's failing-first tests would break
another story's checkpoint if run concurrently. `[P]` applies within a story.

## Risks

- Next.js 14 is two majors behind current; backports only (R1).
- Builder machine: no Docker and ≈1.06 GB free disk → local pgTAP/e2e evidence may be blocked; report exact local failures and use green CI evidence for B0 only (approved D-B0-09). Prepare local Docker/disk before B1.
- CI evidence requires an authorized push to the B0 branch (approved D-B0-07); no push/merge to `main`.
- DST rules for Egypt come from tzdata; tests use settled 2024 dates to avoid future rule changes.

## Complexity Tracking

No constitution violations; nothing to justify.
