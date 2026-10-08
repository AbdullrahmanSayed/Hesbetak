# Phase 0 Research: B0 — Foundation

**Date**: 2026-09-27 | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

Every technology below is fixed by master spec Section 3 unless marked *(plan choice)*. Plan choices are technical defaults where the spec is silent; they are reviewable here. Founder-level questions D-B0-01…D-B0-11 and the Section 18 Rule 3 amendment are **confirmed** in `docs/DECISIONS.md`, including native `bigint` in TypeScript and decimal-string JSON transport.

Version facts were read from the npm registry dist-tags on 2026-09-27 (`registry.npmjs.org/-/package/<name>/dist-tags`).
Exact versions are pinned in `package-lock.json` at implementation time; a newer patch within the
same line is acceptable.

## R1 — Framework: Next.js 14 App Router

- **Decision**: `next@14.2.35` (dist-tag `next-14`), React 18, App Router, Server Components.
- **Rationale**: Section 3 fixes Next.js 14. `14.2.35` is the latest 14.x line release.
- **Risk (reported, not acted on)**: Next.js 14 is two majors behind `latest` (16.3.6); it receives
  only backports. Upgrading would amend Section 3 and needs founder approval.
- **Alternatives considered**: Next 15/16 — rejected (contradicts Section 3).

## R2 — Node.js runtime and package manager *(plan choice)*

- **Decision**: CI uses Node.js 22 LTS (`.nvmrc` = `22`, `engines.node` = `>=22 <25`, covering CI
  and the builder's Node 24; narrower than Next 14's `>=18.17` because current Vitest majors need newer
  Node); npm with a committed `package-lock.json`; CI installs with `npm ci`. Exact Vitest and
  Playwright versions are pinned in `package-lock.json` at install time and checked against this range.
- **Rationale**: Node 20 is past end-of-life on 2026-09-27; Node 22 is a maintained LTS supported by
  Next 14 (`>=18.17`). npm ships with Node; `pnpm` is not installed on the builder machine.
- **Local note**: the builder machine has Node 24.15.0. Development may use it, but CI (Node 22) is the reference; if a Node-24-only failure appears, install Node 22 locally instead of adding workarounds. `date-fns@3` and `date-fns-tz@3.2.0` are installed with the first npm install, not a later task.
- **Alternatives considered**: pnpm (extra tool, no spec requirement); Node 24 in CI (Next 14 predates
  Node 24; less proven).

## R3 — TypeScript configuration

- **Decision**: TypeScript 5.x, `"target": "ES2020"`, `lib` `["dom", "dom.iterable", "esnext"]`,
  `strict: true`, `noUncheckedIndexedAccess: true`, `noEmit`, path alias `@/*` → `src/*`; typecheck
  command `tsc --noEmit`.
- **Rationale**: Section 3 and Rule 14. `bigint` literals (`100n`) fail with TS2737 below ES2020, and
  the TypeScript default target is ES5, so the target is set explicitly. Next.js 14 accepts ES2020.

## R4 — Styling: Tailwind CSS v3 + shadcn/ui, RTL (shadcn configuration and DirectionProvider approved; D-B0-06)

- **Decision**: `tailwindcss@3.4.19` (dist-tag `v3-lts`) with PostCSS/autoprefixer; shadcn/ui set up for
  Tailwind v3 (`components.json`, CSS variables theme, `cn()` helper using `clsx` + `tailwind-merge`).
  Only components actually used are added; `lucide-react` (Section 11 iconography) is installed with the
  first icon, not in B0 (D-B0-06).
  RTL: `<html lang="ar" dir="rtl">`; Tailwind logical utilities (`ms-/me-/ps-/pe-/start-/end-`) and
  `rtl:`/`ltr:` variants; Radix `DirectionProvider` with `dir="rtl"` in the root layout so Radix-based
  shadcn components render mirrored.
- **Rationale**: Next 14 ships React 18. shadcn states existing Tailwind v3 + React 18 projects keep
  receiving v3/React 18 component variants ([shadcn Tailwind v4 notes](https://raw.githubusercontent.com/shadcn-ui/ui/main/apps/v4/content/docs/(root)/tailwind-v4.mdx)).
  Tailwind v4 targets React 19-era tooling.
- **Implementation check**: if the current `shadcn` CLI `init` insists on Tailwind v4 for a v3 project,
  create `components.json` and the `cn()` helper manually (documented shadcn manual path) instead of
  upgrading Tailwind.
- **Alternatives considered**: Tailwind v4 (mismatch with React 18 / Next 14 shadcn variants).

## R5 — Font: IBM Plex Sans Arabic

- **Decision**: `next/font/google` `IBM_Plex_Sans_Arabic`, subsets `arabic` + `latin`, weights
  400/500/600/700, `display: 'swap'`, exposed as a CSS variable used by Tailwind `fontFamily.sans`.
- **Rationale**: Section 3 names Google Fonts; `next/font` self-hosts at build time (no runtime request
  to Google, no layout shift). CI builds need network access to fetch the font once.
- **Smoke-test note**: `next/font` renames the family (e.g. `__IBM_Plex_Sans_Arabic_<hash>`), so the
  browser test matches `/IBM[ _]Plex[ _]Sans[ _]Arabic/` on the computed `font-family`.

## R6 — Money representation and arithmetic (approved D-B0-03/D-B0-04)

- **Decision**: branded `Piasters = bigint`, range-checked against PostgreSQL signed-`bigint` minimum/maximum. Parsing typed EGP is string → integer piasters, formatting is integer → grouped EGP text; rounding primitives operate on `bigint` only and verify monetary results fit the signed-64-bit range. No `parseFloat`, `Number(text)` on monetary text, `toFixed`, or `Intl.NumberFormat` on fractional money.
- **Transport boundary**: use canonical base-10 piaster **strings** in JSON and convert to/from `bigint` in `src/lib/money.ts` without a JavaScript `number` intermediate. Generated Supabase types may map SQL `bigint` to TS `number`; this does not prove runtime precision. At B1+ database/RPC reads, financial values must be projected as text **before** JSON decoding; casting an already decoded number cannot recover lost digits. B0 tests wire helpers and boundary round trips but creates no B1 SQL objects.
- **Rationale**: Section 2 P4 and the amended Rule 3 require `bigint` piasters in SQL and TS, decimal-string JSON values, and database monetary text before JSON decoding. This avoids an undetected precision loss in financial transport and remains safe for large future balances.
- **Alternatives considered**: branded safe-integer `number` only with an end-to-end bound before JSON decoding (rejected by founder for D-B0-03); decimal libraries (not needed for integer piasters).

## R7 — Business dates: `date-fns` + `date-fns-tz`

- **Decision**: `date-fns@3` + `date-fns-tz@3.2.0`; zone constant `Africa/Cairo`.
  Conversion uses `formatInTimeZone(instant, 'Africa/Cairo', 'yyyy-MM-dd')`. Day start is defined as
  the earliest instant whose Cairo business date is the given date. Because local `00:00` can be
  missing or repeated, the implementation finds both boundaries by millisecond binary search over the
  instant → Cairo-date mapping. Equality rather than lexical year ordering preserves the invariant at
  civil year `0001`; finding the end directly lets `9999-12-31` work without constructing a public
  year-10000 `BusinessDate`. Validation is a strict `YYYY-MM-DD` regex plus a calendar round-trip check
  for civil years `0001`–`9999`; year `0000` is invalid.
- **Rationale**: Section 3 names these libraries; they rely on `Intl` time-zone data, so results do not
  depend on the process time zone.
- **DST facts used by tests** (Egypt rules since 2023: DST starts last Friday of April 00:00 → 01:00,
  ends last Thursday of October 24:00 → 23:00): `2024-04-26` is a 23-hour Cairo day
  (`2024-04-25T22:00:00Z` → `2024-04-26T21:00:00Z`); `2024-10-31` is a 25-hour Cairo day
  (`2024-10-30T21:00:00Z` → `2024-10-31T22:00:00Z`). Historical 2024 dates are used because they are
  settled in tzdata.
- **Time-zone independence test**: Vitest runs with `pool: 'forks'`; the date tests re-run their
  assertions after setting `process.env.TZ` to `UTC`, `America/New_York`, and `Asia/Tokyo` (Node applies
  runtime `TZ` changes in the main thread of a process).
- **Alternatives considered**: `@date-fns/tz` (date-fns v4) — Section 3 names `date-fns-tz`; Temporal
  polyfill — not in the spec.

## R8 — Unit tests and coverage

- **Decision**: Vitest (current major) + `@vitest/coverage-v8`; environment `node`; tests in
  `tests/unit/`; command `vitest run --coverage`. Per-file thresholds: `src/lib/money.ts` 100% lines,
  branches, functions, statements (Section 17 B0 DoD); `src/lib/dates.ts` 100% as well (small module;
  stricter than required, not a new rule). Coverage below threshold fails the command.
- **Repository guard tests** (same unit run; `tests/unit/guard-*.test.ts`): `CLAUDE.md` and `AGENTS.md` byte-identical and containing
  Section 18 extracted from `docs/HESBETAK_SPEC.md` (FR-024); the product name strings appear in `src/`
  only in `src/config/app.ts` (FR-012); `supabase/migrations/` is empty or absent (SC-008).

## R9 — Lint

- **Decision**: ESLint 8 with `eslint-config-next@14.2.35` (`next/core-web-vitals`) plus
  `@typescript-eslint` rules `no-explicit-any: error` and `ban-ts-comment: error` applied to **all**
  linted files (`src/`, `tests/`, root `*.config.ts`/`*.mjs`); `no-restricted-syntax` forbidding
  `new Date()` with no arguments and `Date.now()` in `src/**` except `src/lib/dates.ts` (Rule 11); in
  `src/lib/money.ts` only, bans on unsafe number conversions of money (FR-001, FR-005, amended Rule 3):
  `no-restricted-globals` for `parseFloat`, `parseInt`; `no-restricted-properties` for
  `Number.parseFloat`, `Number.parseInt` and `.toFixed`; `no-restricted-syntax` for `Number(...)`,
  `new Number(...)` and unary `+` (kept together with the two `Date` selectors, because an override
  replaces the rule's options for that file). `Math.*` and `Intl.NumberFormat` are not banned: they
  are not conversion paths for `bigint` and no need has been shown. Command
  `eslint . --ext .ts,.tsx,.mjs --max-warnings 0` with `ignorePatterns` for `.next/`, `coverage/`,
  `playwright-report/`, `test-results/` — `next lint` is not used because by default it skips
  `tests/` and root config files. Tests may construct fixed instants.
- **Rationale**: Rule 14, Rule 11 and P4 enforced mechanically. No rule is disabled (any disable needs a
  DECISIONS entry per Rule 14).

## R10 — Local Supabase and pgTAP

- **Decision**: Supabase CLI as an npm dev dependency (`supabase@2.118.0`, run through `npx supabase`)
  so local and CI use one pinned version. `supabase init` creates `supabase/config.toml`; seeding
  disabled because no seed can exist before B1's tables (Rule 2); `supabase/migrations/` stays empty. pgTAP harness test
  `supabase/tests/000_harness.test.sql` runs in a transaction that is rolled back and asserts: pgTAP
  works; `Africa/Cairo` exists in `pg_timezone_names`; `(timestamptz '2026-01-14 22:00:00+00' at time
  zone 'Africa/Cairo')::date = '2026-01-15'` (parity with the TS helper); no tables and no functions
  exist in schema `public`. Command: `npx supabase test db`.
- **Prerequisite**: a Docker-compatible container runtime. **Not installed on the builder machine**; approved D-B0-09 allows CI-only pgTAP and Playwright evidence in B0 with local attempts reported `blocked` and exact errors. B1 local DB implementation needs Docker/disk restored.
- **Alternatives considered**: global Supabase CLI (version drift); plain Postgres container (spec says
  Supabase local).

## R11 — Browser smoke test

- **Decision**: `@playwright/test`, Chromium only, two projects: desktop (1280×800) and mobile width
  (360×800). `webServer` runs the production build (`next build` then `next start`). Assertions: `lang="ar"`,
  `dir="rtl"`, `<title>` equals `APP_NAME.ar` imported from `src/config/app.ts` (and the heading does too, approved D-B0-06), computed
  font family matches IBM Plex Sans Arabic, `scrollWidth <= innerWidth` at 360 px, no console errors.
- **Rationale**: Section 3 (Playwright smoke), Section 11 (≥ 360 px).

## R12 — CI

- **Decision**: GitHub Actions `.github/workflows/ci.yml`, triggered on `push` and `pull_request`, five
  jobs: `typecheck`, `lint`, `unit`, `pgtap` (`npx supabase start` with non-database services excluded,
  then `npx supabase test db`), `e2e` (`npx playwright install --with-deps chromium`, build, test).
  Node from `.nvmrc`, npm cache enabled.
- **Prerequisite**: the founder authorized B0 branch creation, small commits and pushing `001-b0-foundation` to `origin` (D-B0-07). CI green still requires an observed 5/5 run; no merge to `main` before review.

## R13 — Spec Kit agent-context guard

- **Decision**: do not install the Spec Kit `agent-context` extension. Its default target for the
  `claude` integration is `CLAUDE.md` only, which would break the identical-files rule (Section 0.5).
- **Recorded in**: `docs/DECISIONS.md` (B0 Spec Kit setup record).

## R14 — Items intentionally deferred (no B0 work)

`src/lib/supabase/*`, `src/lib/rpc/*`, `src/schemas/*`, `src/types/database.ts`, `supabase/seed.sql`,
`(auth)`/`(app)` routes, TanStack Query/Table, React Hook Form, Zod, exceljs, `lucide-react`, env example file — each
has no consumer before B1+ (D-B0-06; Rule 15). `docs/ACCOUNTING.md` starts in B1 (approved D-B0-08).

## Machine prerequisites found on 2026-09-27 (builder machine)

| Item | Found | Impact |
|------|-------|--------|
| Node.js | 24.15.0 | OK for dev; CI reference is Node 22 (R2) |
| npm | 12.0.2 | Installed; attempt install and report actual result if disk/cache access fails |
| Docker | not installed | Blocks local `supabase start` / pgTAP |
| Supabase CLI | not installed globally | Resolved by npm dev dependency (R10) |
| Free disk on `C:` | ≈ 1.06 GB | Likely insufficient for `node_modules` + Playwright Chromium + Supabase images |
| Git remote | `origin` = github.com/AbdullrahmanSayed/Hesbetak | Founder authorized push of B0 branch only (D-B0-07) |
