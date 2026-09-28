<!--
Sync Impact Report
- Version change: 1.0.0 → 2.0.0 (MAJOR: redefinition of a rule, per Governance → Versioning)
- Modified rules: Agent Rule 3 "Money" — the `number` safe-integer option in TypeScript is removed.
  SQL and TS money use `bigint` piasters; financial JSON values are validated decimal strings;
  database monetary results become text before JSON decoding. Mirrors the founder-approved
  amendment of `docs/HESBETAK_SPEC.md` Section 18 Rule 3 (docs/DECISIONS.md, 2026-09-27, D-B0-03
  project-wide). `docs/SPECKIT_CONSTITUTION.md` synced; root `HESBETAK_SPEC.md` untouched.
- Added / removed sections: none. Section 2 principles unchanged (P4 already states `bigint`).
- Templates: no dependent template change required (they read this file at runtime).
- Follow-up: B0 `CLAUDE.md`/`AGENTS.md` (task T036/T037) copy the amended Section 18.
- Deferred TODOs: none.

Previous report (1.0.0):
- Version change: template (unversioned placeholders) → 1.0.0
- Source input: docs/SPECKIT_CONSTITUTION.md (complete input); authority: docs/HESBETAK_SPEC.md
- Principles: template placeholders PRINCIPLE_1..5 replaced by master-spec Section 2 P1–P12
  (verbatim table). No template example principles adopted (no library-first, CLI interface,
  or separate backend).
- Added sections: Agent Rules (Section 18, verbatim); Delivery Workflow & Quality Gates
  (restates Section 0 / Section 17 obligations by reference, no new rules); Governance.
- Removed sections: none (template SECTION_2 / SECTION_3 placeholders filled as above).
- Templates reviewed (read-only, not modified by this command):
  ✅ .specify/templates/plan-template.md — "Constitution Check" gate reads this file at runtime.
  ✅ .specify/templates/spec-template.md — no conflicting mandatory sections.
  ✅ .specify/templates/tasks-template.md — tests are optional in template; this constitution
     makes Section 18 rules 8/10/17 mandatory where applicable (plan/tasks must honor that).
- Conflicts with master spec: none found.
- Deferred TODOs: none.
-->

# Hesbetak (حسبتك) Constitution

This constitution is a derivative of `docs/HESBETAK_SPEC.md`, which is the source of truth. If this
document and the master spec ever disagree, the master spec wins until it is explicitly amended
with Abdullrahman's approval. The principles and rules below are copied verbatim from Sections 2
and 18 of the master spec.

## Core Principles

### Section 2 — Non-negotiable engineering principles (verbatim)

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

Master spec Section 0.4 governs priority among these: **financial correctness beats everything** —
speed, UI polish, and cleverness come after.

## Agent Rules (Section 18, verbatim)

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

## Delivery Workflow & Quality Gates

This section restates obligations already defined in the master spec (Sections 0 and 17) and in
`docs/SPECKIT_WORKFLOW.md`; it adds no new rules.

- Work batch by batch (B0–B10, master spec Section 17). A batch starts only after the previous
  batch's Definition of Done passes and Abdullrahman has reviewed it.
- Every batch ends with: all tests green in CI, `docs/DECISIONS.md` updated, a short
  `CHANGELOG.md` entry, and human review before the next batch.
- Ambiguity handling (Section 0.3): stop, write the question and the proposed answer in
  `docs/DECISIONS.md`, and implement the disputed behavior only after it is confirmed.
- `CLAUDE.md` and `AGENTS.md` at the repo root must both contain Section 18 verbatim (Section 0.5).
- A check is reported as passed only when its exact command ran and passed; checks whose
  infrastructure belongs to a later batch are reported as `not applicable` with the reason.
- A Spec Kit `Converged` verdict is not Abdullrahman's approval of a batch.

## Governance

The generated Spec Kit constitution is a derivative of the canonical master spec, not an
independent source of requirements. Its operative principles MUST stay equivalent to Sections 2
and 18 of `docs/HESBETAK_SPEC.md`; if a template asks for additional principles or governance
rules, they are not invented here.

- **Amendments:** apparent conflicts are resolved in `docs/DECISIONS.md` with Abdullrahman.
  `docs/HESBETAK_SPEC.md` is amended only with his explicit approval; this constitution is then
  updated to match. The founder's original root `HESBETAK_SPEC.md` is never modified by agents.
- **Versioning:** semantic versioning. MAJOR = removal or redefinition of a principle or rule;
  MINOR = a newly mirrored section or materially expanded guidance; PATCH = wording fixes.
- **Compliance review:** every `plan.md` Constitution Check, every `/speckit-analyze` run, and
  every batch review verifies compliance with the principles and rules above. Constitution
  conflicts are CRITICAL and block implementation.
- **Runtime guidance:** `CLAUDE.md` and `AGENTS.md` (identical, containing Section 18 verbatim).

**Version**: 2.0.0 | **Ratified**: 2026-09-27 | **Last Amended**: 2026-09-27
