# Contract: commands, CI jobs, and repository guards

## npm scripts (single command per check, FR-018)

| Script | Command | Check |
|--------|---------|-------|
| `dev` | `next dev` | local app |
| `build` / `start` | `next build` / `next start` | production app |
| `typecheck` | `tsc --noEmit` | strict TS (FR-020) |
| `lint` | `eslint . --ext .ts,.tsx,.mjs --max-warnings 0` | ESLint rules in research R9, over `src/`, `tests/`, and root config files |
| `test:unit` | `vitest run --coverage` | unit + coverage thresholds + repo guards |
| `db:start` / `db:stop` | `supabase start` / `supabase stop` | local Supabase (Docker required) |
| `test:db` | `supabase test db` | pgTAP harness |
| `test:e2e` | `playwright test` | browser smoke |

## CI (`.github/workflows/ci.yml`, on `push` and `pull_request`)

| Job | Steps | Pass condition |
|-----|-------|----------------|
| `typecheck` | `npm ci`, `npm run typecheck` | exit 0 |
| `lint` | `npm ci`, `npm run lint` | exit 0, zero warnings |
| `unit` | `npm ci`, `npm run test:unit` | exit 0; money.ts and dates.ts 100% coverage |
| `pgtap` | `npm ci`, `npx supabase start -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor` (DB only; verify names with `npx supabase start --help` for `supabase@2.118.0`), `npm run test:db` | exit 0 |
| `e2e` | `npm ci`, `npx playwright install --with-deps chromium`, `npm run test:e2e` | exit 0 |

## Repository guards (run inside `test:unit`)

| Guard | File | Fails when |
|-------|------|-----------|
| Agent rules | `tests/unit/guard-agent-rules.test.ts` | `CLAUDE.md` ≠ `AGENTS.md` byte-for-byte, or either lacks Section 18 as extracted from `docs/HESBETAK_SPEC.md` |
| Product name | `tests/unit/guard-app-name.test.ts` | `Hesbetak` or `حسبتك` appears in any file under `src/` other than `src/config/app.ts` |
| No B1 objects | `tests/unit/guard-no-migrations.test.ts` | any file exists in `supabase/migrations/` |

## pgTAP harness (`supabase/tests/000_harness.test.sql`)

Inside `begin … rollback`: pgTAP runs; `Africa/Cairo` exists; Cairo date of
`2026-01-14 22:00:00+00` is `2026-01-15`; zero tables and zero functions in schema `public`.

## B0 batch report — required lines (FR-027)

typecheck, lint, unit (with coverage numbers), pgTAP, Playwright: exact local command + result (`passed` only when the exact local command ran and passed; otherwise `blocked` + exact error). Approved D-B0-09 allows CI-only pgTAP/Playwright evidence **in B0 only** when local Docker/disk are blocked, but the report must link a 5/5 green CI run and must not claim those local checks passed. Money unit coverage also includes exact signed-64-bit/decimal-string JSON-boundary tests (D-B0-03).
Seeded-scenario reconciliation: `not applicable — no ledger or seed scenario exists in B0`.
Section 14 T01–T30: `not applicable — Section 14 assigns no test to B0`.
Review lines (manual, with evidence): FR-016 / Rule 13 (user-facing strings Arabic; identifiers and
comments English); FR-023 (no secrets or env files committed; no privileged key in client code); Rule 1
(no feature, table, account or rule outside the spec; all B0 decisions recorded); Rule 3 (no money
arithmetic or ad-hoc formatting in React components; display only via `formatMoney`); Rule 15 (no TODO stubs, placeholder data or mocks
outside tests); Rule 16 (commit list with prefixes); Rules 18–19 (no extra service; single builder
branch).
