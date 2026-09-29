## 18. Agent Rules (copy verbatim into CLAUDE.md and AGENTS.md)

1. This spec (`docs/HESBETAK_SPEC.md`) is the source of truth. Do not add features, tables, accounts, or rules not in it. Put open questions in `docs/DECISIONS.md` and wait for confirmation.
2. Work only on the current batch. Finish its Definition of Done before touching the next.
3. **Money:** integer piasters. SQL and TS money use `bigint` piasters (TS via `lib/money.ts`); financial JSON values are validated decimal strings; database monetary results become text before JSON decoding. Never use floating-point for money. Never do money arithmetic in React components.
4. **All financial writes go through Postgres posting functions.** Never insert/update financial tables from the client or from Server Actions directly.
5. **Never UPDATE or DELETE posted documents or journal rows.** Corrections are reversals.
6. **Reports read only from `journal_lines`** (and subledgers only for schedules/aging, which must reconcile to the GL).
7. Every posting function: permission check → idempotency check → validation → row locks → document number → stock → journal → assert balanced → return result.
8. Every new posting rule needs a pgTAP test with exact numbers before or together with the implementation.
9. Never edit an applied migration; create a new one. Regenerate `src/types/database.ts` after every migration.
10. Every table has `tenant_id` and RLS. Add a cross-tenant test for every new table and RPC.
11. Business dates use `Africa/Cairo`. Never use `new Date()` for business dates in the client; use `lib/dates.ts`.
12. Customer-facing UI, prints, and messages must never show interest, percentages, or "فائدة" for installment sales.
13. Arabic RTL UI; all user-facing strings in Arabic; code, identifiers, and comments in English.
14. TypeScript strict; no `any`; no `// @ts-ignore`; no disabled lint rules without a comment in DECISIONS.md.
15. Production-ready code only: no TODO stubs, no placeholder data in app code, no mock implementations outside tests and `seed.sql`.
16. Small, focused commits with conventional messages (`feat:`, `fix:`, `test:`, `db:`, `docs:`).
17. Before declaring a batch done: run typecheck, lint, unit, pgTAP, Playwright; run the reconciliation check on the seeded scenario; report results.
18. The MVP backend is Next.js + Supabase only (Postgres functions, Edge Functions). Do not add Python, FastAPI, or any other server/service. Image processing happens client-side and in Edge Functions (Section 6.15).
19. If two agents work in parallel, they work on separate branches and separate batches; DB migrations are only created on the branch owning the current DB batch.
