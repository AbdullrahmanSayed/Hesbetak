# Hesbetak — Spec Kit constitution content

This is the content to give `/speckit-constitution` (Claude Code) or `$speckit-constitution` (Codex), then review the generated `.specify/memory/constitution.md` against it. `docs/HESBETAK_SPEC.md` is authoritative; this document does not amend it. Sections 2 and 18 below are copied verbatim. Do not replace these rules with Spec Kit template examples such as mandatory library-first or a new backend.

## 2. Non-negotiable engineering principles

| # | Principle | Enforcement |
|---|-----------|-------------|
| P1 | **Double-entry ledger is the single source of truth** for every financial number | Reports query `journal_lines` only. No report recomputes money from documents. |
| P2 | **Every journal entry balances** (Σ debit = Σ credit) | Deferred constraint trigger on `journal_lines` per entry; posting function asserts before commit. |
| P3 | **Append-only financial data** | No `UPDATE`/`DELETE` on posted documents or journal rows. Revoked at the DB privilege level + trigger guard. Corrections = reversal entry + new entry. |
| P4 | **Money is integer piasters (`bigint`)** | 1 EGP = 100 piasters. No `float`, no `numeric` arithmetic in JS. Formatting only at the UI edge. |
| P5 | **All financial writes go through Postgres functions (RPC)** in a single transaction | Client never inserts into financial tables directly. RLS denies direct writes. |
| P6 | **Idempotent posting** | Every posting RPC takes `p_request_id uuid`; unique per tenant; a retry returns the original result. |
| P7 | **Tenant isolation** | Every tenant-scoped table has `tenant_id` + RLS. Tested with automated cross-tenant tests. |
| P8 | **Subledger ↔ GL reconciliation** | Installment, inventory, customer, supplier subledgers must equal their control accounts. A reconciliation report flags any difference; a difference is a P0 bug. |
| P9 | **Period locking** | Postings dated on or before the tenant's `lock_date` are rejected. |
| P10 | **Business dates are Cairo dates** | Stored as `date`; timestamps as `timestamptz`; business day computed in `Africa/Cairo`. |
| P11 | **Gapless document numbers** per tenant, per document type, per year | Counter table with row lock inside the posting transaction. |
| P12 | **Full audit trail** | Every posting stores `created_by`, `created_at`, `request_id`; audit log for master-data changes. |

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

## Governance of the generated constitution

The generated Spec Kit constitution is a derivative of the canonical master spec, not an independent source of requirements. Keep its operative principles equivalent to the sections above; if a template asks for additional principles or governance rules, do not invent them. Resolve apparent conflicts in `docs/DECISIONS.md` with Abdullrahman, and amend `docs/HESBETAK_SPEC.md` only with his explicit approval. Review the generated constitution and all dependent templates before accepting B0. The B0–B10 order, quality gates, and human review are specified in Section 17 of the master spec.
