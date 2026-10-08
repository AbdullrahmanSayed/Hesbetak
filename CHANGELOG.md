# Changelog

## B0 — Foundation (branch `001-b0-foundation`, awaiting founder review)

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
