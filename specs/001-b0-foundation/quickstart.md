# Quickstart & Validation: B0 — Foundation

**Purpose**: prove B0 works end to end. Detailed APIs: [contracts/money.md](./contracts/money.md),
[contracts/dates.md](./contracts/dates.md), [contracts/quality-gates.md](./contracts/quality-gates.md).

## Prerequisites

- Node.js 22 LTS (`.nvmrc`; Node 24 works for development but CI uses 22), npm.
- Docker-compatible container runtime running (for local Supabase / pgTAP).
- Git; network access for `npm ci`, the Google font download at build time, Playwright Chromium, and
  Supabase images.
- Disk: several GB free (dependencies + Chromium + Supabase images). Approved D-B0-09 allows **B0-only** CI evidence for pgTAP/Playwright if local Docker/disk are blocked; attempt local commands and record exact errors as `blocked`, never `passed`. Before B1 local DB work, resolve the machine prerequisites.

## Setup

```powershell
npm ci
npx playwright install chromium
npm run db:start        # first run pulls Supabase images
```

## Validation scenarios

| # | Command | Expected outcome | Proves |
|---|---------|------------------|--------|
| V1 | `npm run typecheck` | exit 0 | FR-020 |
| V2 | `npm run lint` | exit 0, 0 warnings | FR-011, FR-020 |
| V3 | `npm run test:unit` | all tests pass; 100/100/100/100 coverage for `src/lib/money.ts` and `src/lib/dates.ts`; signed-64-bit and exact decimal-string wire round trips pass; repo guards pass | US1, US2, US5, FR-005/007/012/024, SC-001–003, SC-007–008 |
| V4 | `npm run test:db` | pgTAP harness: all assertions `ok` | FR-022, SC-008 |
| V5 | `npm run test:e2e` | desktop and 360 px projects pass | US3, FR-013/014/021, SC-006 |
| V6 | `npm run dev`, open `http://localhost:3000` | Arabic RTL page titled `حسبتك` in IBM Plex Sans Arabic; heading per D-B0-06 | US3 |
| V7 | Push authorized B0 branch; open GitHub Actions | 5/5 jobs green; no merge to `main` without founder review | FR-019, SC-005 |

SC-004 in B0: the CI jobs run the README's setup and check commands from a fresh checkout. CI uses two documented variants: `npx supabase start -x …` (database only) and `npx playwright install --with-deps chromium`. The local clean-machine walkthrough is a B1 entry obligation (approved D-B0-11). B0-only evidence rule (D-B0-09): if V4 or V5 is locally blocked, retain the actual command and error in the batch report and link the CI run where that same check passes. Do not call a local blocked command passed. The CI gate still requires 5/5 green.

## Negative checks (should fail, then revert)

- Remove all `divCeilToStep` cases from `tests/unit/money-rounding.test.ts` → V3 fails on the `src/lib/money.ts` function-coverage threshold.
- Pass `"9223372036854775808"` or a JSON `number` to `piastersFromWire` → reject before any financial conversion; `"9007199254740993"` must round-trip exactly without a `number` step.
- Add `const x: any = 1` in `tests/unit/dates.test.ts` → V2 fails (lint covers tests too).
- Add `// @ts-ignore` above any line in `tests/unit/dates.test.ts` → V2 fails (`@typescript-eslint/ban-ts-comment`).
- Add `new Date()` in `src/app/layout.tsx` → V2 fails.
- Write `حسبتك` in `src/app/page.tsx` → V3 fails (product-name guard).
- Edit one character in `AGENTS.md` → V3 fails (agent-rules guard).

## Teardown

```powershell
npm run db:stop
```
