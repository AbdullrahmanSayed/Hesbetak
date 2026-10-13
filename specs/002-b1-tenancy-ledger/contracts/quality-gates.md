# Contract: B1 Quality Gates

## Local commands

| Check | Command | Pass condition |
|---|---|---|
| TypeScript | `npm run typecheck` | exit 0 |
| Lint | `npm run lint` | exit 0, zero warnings |
| Unit regression | `npm run test:unit` | exit 0; B0 money/date coverage remains 100% |
| Database reset | `npx supabase db reset` | exit 0 against local database-only Supabase |
| Database acceptance | `npm run test:db` | exit 0; all B0+B1 pgTAP tests pass |
| Generated types | documented generation/drift command | generated `src/types/database.ts` matches committed file |
| Browser regression | `npm run test:e2e` | B0 desktop/mobile smoke passes |
| Reconciliation | B1 pgTAP ledger/reversal net check | exact zero difference; document/subledger reconciliation reported not applicable until B3 |

Database-only local startup uses the exact documented exclusion list from CI. Unlike B0, a local database pass is mandatory.

## B1 pgTAP acceptance groups

| Group | Required evidence |
|---|---|
| Bootstrap | one tenant, active owner, exact account seed, retry/duplicate safety, no B2 defaults |
| T16/RLS | direct ledger DML denied; internal-only functions ungranted; fixed context |
| T19/isolation | same-tenant success and cross-tenant/non-member/inactive denial for every B1 table/RPC |
| Ledger | exact piasters, ≥2 lines, balance, account validation, append-only guards |
| Lock | on/before rejected, after accepted, row-lock order exercised |
| Idempotency | identical retry same result/effect; mismatch rejected; failure leaves no durable result |
| Counters | tenant/type/year partitioning; rollback safety; concurrency uniqueness/gaplessness |
| Reversal | exact mirror, dimensions preserved, original unchanged, second reversal rejected, net zero |
| Audit | membership/lock/secret-reference changes attributed and immutable; secret plaintext absent |
| Vault refs | one typed reference per tenant/kind; isolation; no value resolver/browser disclosure |

## Type-generation contract

After every migration change:

1. Reset the local database from committed migrations.
2. Generate TypeScript types using the pinned CLI and local database.
3. Do not hand-edit generated output.
4. Run typecheck and the drift guard.
5. Financial SQL/RPC results still require explicit text projection even if generated table types represent SQL `bigint` unsafely.

## CI

The existing five jobs remain mandatory. The `pgtap` job starts database-only Supabase then runs all database tests. B1 may add a type-generation drift step to `typecheck` or `pgtap`, but must not remove or rename the five required jobs.

## B1 completion report

Report:

- changed files and migration identifier;
- exact local command/result for every local gate above;
- pgTAP assertion counts and T16/T19 object matrix;
- exact-money and above-safe-integer evidence;
- B1 journal/reversal reconciliation result;
- `not applicable — no business document or subledger exists until B3` for full T17;
- generated type command and clean diff evidence;
- migration reset-from-zero evidence;
- CI run URL with all five jobs green;
- Codex PR review outcome and founder approval status;
- confirmation that no B2+ table/flow or production manual-journal endpoint exists;
- known risks and B2 entry obligations.
