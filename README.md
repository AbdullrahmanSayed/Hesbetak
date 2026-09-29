# Hesbetak (حسبتك)

Multi-tenant SaaS for Egyptian electrical-appliance showrooms: cash & installment sales, collections,
inventory, and treasury, built on a double-entry ledger so every number is correct. Next.js ·
Supabase · TypeScript.

The source of truth is
[`docs/HESBETAK_SPEC.md`](docs/HESBETAK_SPEC.md); decisions are recorded in
[`docs/DECISIONS.md`](docs/DECISIONS.md). Agents follow [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md)
(identical, Section 18 of the spec).

Current state: **B0 — Foundation** (Next.js 14 shell, money and Cairo-date helpers, local Supabase,
quality gate). No business features, tables, or migrations exist yet.

## Prerequisites

- Node.js 22 LTS (see `.nvmrc`; Node 24 also works for development, CI uses 22) and npm.
- A running Docker-compatible container runtime (for local Supabase and pgTAP).
- Git.
- Network access for `npm ci`, the Google font download at build time, Playwright Chromium, and the
  Supabase container images.
- Several GB of free disk (dependencies, Chromium, Supabase images).

## Setup

```sh
npm ci
npx playwright install chromium
npm run db:start        # first run pulls the Supabase images; starts with no migrations
```

`npm run db:stop` stops the local Supabase stack.

## Checks (one command each)

| Check | Command |
|-------|---------|
| Typecheck (strict + `noUncheckedIndexedAccess`) | `npm run typecheck` |
| Lint (zero warnings) | `npm run lint` |
| Unit tests + coverage (100% for `src/lib/money.ts` and `src/lib/dates.ts`) and repository guards | `npm run test:unit` |
| Database tests (pgTAP, needs `npm run db:start`) | `npm run test:db` |
| Browser smoke test (builds and starts the app itself) | `npm run test:e2e` |

Run the app locally with `npm run dev` and open <http://localhost:3000>.

## CI

`.github/workflows/ci.yml` runs five jobs on every push and pull request — `typecheck`, `lint`,
`unit`, `pgtap`, `e2e` — each from a fresh checkout with `npm ci` and the commands above. CI uses two
documented variants:

- Database only (skips services B0 does not use):
  `npx supabase start -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor`
- Chromium with its Linux system dependencies: `npx playwright install --with-deps chromium`
