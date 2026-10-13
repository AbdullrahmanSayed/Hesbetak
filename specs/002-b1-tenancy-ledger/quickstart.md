# Quickstart & Validation: B1 — Tenancy & Ledger Core

**Purpose**: prove B1 from a clean local migration state. Detailed behavior: [data-model.md](./data-model.md), [database-security.md](./contracts/database-security.md), [ledger-posting.md](./contracts/ledger-posting.md), [quality-gates.md](./contracts/quality-gates.md).

## Prerequisites

- B0 merged and approved.
- Node.js 22 reference runtime and npm dependencies installed.
- Docker Desktop running with WSL2; `docker info` succeeds.
- Several GB free for the Postgres image, database volume, builds, and Chromium.
- Network access for first-time images/dependencies.

## Local database-only startup

```powershell
npx supabase start -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor
```

The command must exit 0 and expose PostgreSQL on `127.0.0.1:54322`. B1 does not accept CI-only database evidence.

## Clean migration and type generation

```powershell
npx supabase db reset
npx supabase gen types typescript --local --schema public,app > src/types/database.ts
```

Use the repository's finalized drift command from `tasks.md` if it wraps generation to avoid shell redirection differences. Generated output is never hand-edited.

## Validation scenarios

| # | Command / scenario | Expected outcome |
|---|---|---|
| V1 | `npm run typecheck` | strict TypeScript passes |
| V2 | `npm run lint` | zero warnings/errors |
| V3 | `npm run test:unit` | B0 regression suite passes; money/date files remain 100% covered |
| V4 | `npm run test:db` | B0 harness and all B1 pgTAP groups pass |
| V5 | bootstrap two users/tenants in pgTAP | each receives owner membership and exact chart only; no cross-tenant visibility |
| V6 | exact balanced manual JE through rollback-scoped test helper | one immutable balanced entry; totals returned as decimal strings |
| V7 | unbalanced/invalid/mixed-tenant lines | atomic rejection; no rows, counter, or completed request |
| V8 | identical retry and request-id mismatch | identical retry returns original result; mismatch rejected |
| V9 | locked-date checks | on/before lock rejected; after lock accepted, including a valid future Cairo date |
| V10 | internal reversal | exact mirror and net zero; original unchanged; repeat rejected |
| V11 | T19 matrix | every B1 table/browser operation has same-tenant success and cross-tenant denial |
| V12 | type regeneration/drift check | committed generated type file is current |
| V13 | `npm run test:e2e` | B0 desktop/mobile shell regression passes |
| V14 | push B1 branch | five CI jobs green; Codex review recorded on PR |

## Negative privilege checks

Each check must fail and roll back:

- direct browser-role insert/update/delete on journal or audit tables;
- browser execution of internal journal, counter, idempotency, or reversal functions;
- non-member/inactive/cross-tenant access;
- suspended-tenant write;
- caller-controlled `search_path` shadowing;
- loss of the final active owner;
- posting to inactive/header/wrong-tenant account;
- money supplied as a JSON number or outside signed-64-bit bounds;
- locked date, reused request id with different payload, second reversal;
- secret plaintext in settings, result, audit, or browser response.

## Reconciliation evidence

For the B1 test entry and its reversal, sum every affected account from `journal_lines`; the exact net must be zero. Full document/subledger reconciliation is `not applicable — no business document or subledger exists until B3`.

## Teardown

```powershell
npm run db:stop
```
