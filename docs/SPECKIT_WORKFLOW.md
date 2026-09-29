# Hesbetak — Spec Kit delivery workflow (B0–B10)

`docs/HESBETAK_SPEC.md` is the master specification; this workflow is a derivative, not an amendment. Follow Sections 0 and 17: **one batch at a time**, no next batch until its Definition of Done passes and Abdullrahman reviews it. For open interpretation conflicts, use `docs/DECISIONS.md` and stop the affected work. The founder-approved canonical spec copy is recorded there; the original root `HESBETAK_SPEC.md` remains untouched.

## Set up and run

Spec Kit's current documentation distinguishes **terminal setup** from **agent-chat skills**. Have the B0 owner install the `specify-cli` developer tool (requires Python 3.11+ and `uv`, **not** a Python application backend). Initialize in this existing repository on a reviewable branch; inspect the diff before using `--force` because it can overwrite conflicting managed paths. Do **not** run initialization against the founder's untracked root spec without checking the diff.

```text
uv tool install specify-cli
specify init --here --force --integration claude
specify integration install codex
specify integration status
```

The last integration install is for handoff/review; if the installed CLI reports a multi-install conflict, stop and inspect its guidance rather than force overwriting files. Claude Code skills use `/speckit-constitution`, `/speckit-specify`, `/speckit-plan`, `/speckit-clarify`, `/speckit-checklist`, `/speckit-tasks`, `/speckit-analyze`, `/speckit-implement`, `/speckit-converge`. Codex skills use `$speckit-constitution`, `$speckit-specify`, `$speckit-plan`, `$speckit-clarify`, `$speckit-checklist`, `$speckit-tasks`, `$speckit-analyze`, `$speckit-implement`, `$speckit-converge`. The reference docs also write commands as `/speckit.specify`; that is **notation**, not necessarily the installed skill spelling. Run skills **in the coding agent chat**, not PowerShell. If a locally installed version differs, check `specify version`, `specify integration status`, and the installed skills before issuing prompts.

First, in Claude Code chat: `/speckit-constitution Use docs/SPECKIT_CONSTITUTION.md as the complete constitution input. Preserve all Section 2 principles and Section 18 rules verbatim; docs/HESBETAK_SPEC.md remains authoritative. Do not adopt unrelated example principles. Report any conflict before modifying the master spec.` Review `.specify/memory/constitution.md` against both source sections before B0. B0 also creates **identical** root `CLAUDE.md` and `AGENTS.md` containing Section 18 verbatim (per Sections 0 and 18).

For each row below, paste the **Specify input** after `/speckit-specify` in Claude Code (or `$speckit-specify` in Codex) and the **Plan input** after `/speckit-plan` in the same agent. Each Specify input intentionally states *what/why*; each Plan input states *how*. Before planning, use `/speckit-clarify` for unresolved requirements, log recommendation and founder decision in `docs/DECISIONS.md`; never invent a rule. After planning, use `/speckit-checklist` for requirements quality; founder owns approval of its items. Then `/speckit-tasks`, `/speckit-analyze` (fix source artifacts until consistent), `/speckit-implement`, and `/speckit-converge`. A non-converged outcome appends tasks: implement those tasks and converge again. **Converged is necessary but not proof tests ran.** Independently run the exact checks below and inspect results. Keep feature artifacts labeled B0–B10; Spec Kit may assign its own numeric feature/branch name. Do not assume B0 corresponds to generated feature `000`.

For **every batch**, the agent must report exact commands/results of typecheck, lint, unit, pgTAP against local Supabase, Playwright, and seeded-scenario reconciliation (Section 18.17); if infrastructure for a later scenario does not yet exist, report `not applicable` and why, never `passed`. Every batch ends with CI green for applicable checks, `docs/DECISIONS.md` updated, a short `CHANGELOG.md` entry, regression tests for previously delivered behavior, and **human review** (Section 17). Any new tenant table/RPC requires progressive T19 isolation coverage; any new posting rule requires exact-number pgTAP, balanced journal, idempotency, lock-date, and reconciliation checks (Sections 2, 7–10, 14, 18). Validate customer-facing installments contain no percentages or interest wording. Do not introduce later-phase technologies, features, accounts, or tables.

## Batch prompts and convergence gates

### B0 — Foundation

**Specify input:** `Build the minimal project foundation for an Arabic-first RTL showroom application, so future batches can reliably create correct Cairo business dates and integer-piaster money values. Deliver a working app shell and repeatable local development/test setup only. Scope: Section 17 B0; Sections 0, 2, 3, 11, 12, 18. No B1 data model or financial features.`

**Plan input:** `Follow Sections 3, 8.1–8.2, 11–12, 17 B0, 18. Set up Next.js 14 App Router, TS strict + noUncheckedIndexedAccess, Tailwind, shadcn/ui RTL, IBM Plex Sans Arabic; Supabase local and CI; src/config/app.ts APP_NAME; src/lib/money.ts integer-piaster parse/format/rounding and src/lib/dates.ts Africa/Cairo helpers. Use Vitest, pgTAP, Playwright smoke. Copy Section 18 verbatim into identical CLAUDE.md and AGENTS.md. No B1 migrations. Verify exact 100% money-helper unit coverage for parse/format/rounding; test Cairo date boundaries. Update DECISIONS and CHANGELOG.`

**Converge/DoD:** Section 14 assigns no T ID to B0. CI green; 100% unit coverage of money helpers for parsing, formatting, rounding; suitable app smoke and date tests. Report later-batch financial acceptance tests as not applicable, not green.

### B1 — Tenancy & ledger core

**Specify input:** `Enable isolated showroom tenants and membership roles, with a trustworthy balanced append-only ledger foundation, period locking, auditable reversals, gapless numbering, and safe retry behavior. No purchase or sale flows yet. Scope: Sections 2, 5, 6.16, 7.1–7.2, 9–10, 17 B1, 18.`

**Plan input:** `Implement the B1 schema and policies from Sections 5, 7, 9–10: tenants, memberships, RLS helpers and role checks, bootstrap_tenant, chart-of-accounts seed by system_key, journal_entries/journal_lines, deferred balance trigger, document counters with row locks, posting_requests, lock date, reversal engine, Vault secret references. SQL SECURITY DEFINER functions with fixed search_path; transaction-scoped permission/idempotency/locks and audit. Regenerate DB types after migration. Use pgTAP exact-number manual JE test helper, unbalanced rejection, locked-date rejection, idempotency harness, and per-existing-table/RPC cross-tenant tests. Do not add production manual financial-write endpoints.`

**Converge/DoD:** T16 and T19 for B1 objects; idempotency via B1 journal test helper, balanced manual JE via test helper and unbalanced JE rejected. Full T17 with one posted document is required in B3, not claimed in B1 (approved Section 17 amendment in `docs/DECISIONS.md`). T19 covers every table/RPC that exists so far, and expands with later batches.

### B2 — Master data & unified attachments

**Specify input:** `Allow authorized showroom staff to manage validated master data without hard-deleting historical records, and to upload/view sensitive documents according to role and tenant. Cashiers may upload customer ID images but cannot view them after saving. Build one attachment system for later modules. Scope: Sections 5.2, 6.1, 6.15, 9, 17 B2, 18.`

**Plan input:** `Create the Section 6.1 master data + UI, archive and audit rules, unified Section 6.15 attachments schema and RPCs, three private buckets, tenant/path/owner-type Storage RLS, signed URL permission and view audit, camera upload, resizing/WebP/EXIF stripping, MIME sniff in Edge Function, 10 MB and 10-file limits, upload_session_id draft-to-post lifecycle, idempotent post-commit move, 24h pending cleanup; register/attach/supersede via authorized RPCs only. Respect posting-time attachment checks to be wired into relevant later batch posting RPCs. pgTAP and Playwright role and storage boundary tests.`

**Converge/DoD:** T26, T27, T28, T29, T30; master-data CRUD validation, audit entries, archive instead of delete. Verify T19 for new tables/RPCs and cannot directly write attachments. Do not implement installment/purchase posting here.

### B3 — Purchases & inventory

**Specify input:** `Let showrooms receive and return purchased goods, track unique appliances and quantity stock at exact cost, pay suppliers, and reconcile inventory and supplier balances to the ledger. Prevent double movement and negative stock. Scope: Sections 6.2–6.3, 7.3 J–L/T, 9, 14, 17 B3, 18.`

**Plan input:** `Implement only B3 purchase invoice/return, supplier payment, serial and quantity stock, moving weighted-average cost, stock_movements and adjustments via transactional posting RPCs; specific identification for serials. Lock inventory/counter rows, use bigint piasters, ensure exact journal lines and subledger-to-GL reconciliation. Reuse B2 attachment RPCs for supplier invoices and honor required-image settings. Add pgTAP exact balances, permission/tenant/idempotency/reversal coverage and Playwright purchase flows. No POS screen or post_cash_sale yet.`

**Converge/DoD:** T13 and full T17 with a posted document; inventory reconciliation = 0. Verify T14's purchase/weighted-average portion (`avg cost = 115`) now; complete its sale/COGS scenario in B4, as approved in Section 17 and `docs/DECISIONS.md`. T19 expands to new B3 objects.

### B4 — Cash sales (POS)

**Specify input:** `Cashiers need fast fully-paid cash sales with serial-safe stock release, role-limited discounts and split payments, printable receipts/invoices, and reversible returns without losing audit history. Keep cost/profit hidden from cashiers. Scope: Sections 5.2, 6.4, 7.3 A/I, 9–11, 14, 17 B4, 18.`

**Plan input:** `Implement post_cash_sale/post_sales_return RPCs with row locks, one transaction, request idempotency, numbering, journal and COGS at specific/weighted-average cost, stock out/restock, discounts and multi-cash-account settlement. Add POS keyboard/barcode flow, Arabic RTL confirmation, 80mm and A4 prints, permission-safe costless cashier reads. pgTAP concurrent serial sale, exact postings and return; Playwright POS/print/role flows. Add the 5-unit sale to B3's weighted-average fixture here to complete T14 under the approved Section 17 timing.`

**Converge/DoD:** T01, T02, T12, T14 (including `COGS = 575`), T18, T20; T19 for B4 objects and full prior regression.

### B5 — Installment sales

**Specify input:** `Offer a fixed-price deferred appliance sale with transparent cash price, deferred total, down payment and exact dated schedule, while keeping percentages and interest wording off all customer-facing surfaces. Posting must fail atomically if mandatory ID uploads are absent. Scope: Sections 1.4, 6.5, 6.15, 7.3 B, 8, 9, 14, 17 B5, 18.`

**Plan input:** `Implement preview_installment_schedule and post_installment_sale in Postgres using Section 8 exact integer math, month-end due dates, round-half-up/rounding-step logic, principal/margin invariant tests, attachment session activation in posting transaction, locks/stock/journal/COGS, fixed unearned margin 1215. Build customer-facing Arabic RTL preview/contract A4 + down-payment receipt without factor/percent/interest; signed-contract upload follows Section 6.15. Add pgTAP vectors from 8.6, missing-attachment atomic rejection, and Playwright contract/print tests.`

**Converge/DoD:** T03, T23, T25; no customer-facing percentage/interest; T19 for new objects and exact GL/subledger reconciliation. Lawyer review of contract text before production use (Section 1.4), not a license to invent legal text.

### B6 — Collections lifecycle

**Specify input:** `Allow authorized staff and assigned collectors to collect installments and manage overpayments, settlement, rescheduling, write-offs, cancellations, trade-ins, and receipt reversals with preserved history and correct margin recognition. Scope: Sections 5.2, 6.6–6.8, 7.3 C–H/M, 8.4–8.5, 10, 14, 17 B6, 18.`

**Plan input:** `Implement receipt and lifecycle posting RPCs per Section 7 exact journals and Section 8 deterministic allocation (due_date, installment_no, partial floor split, full-installment remainder); lock installment rows and use idempotent request ids. Preserve frozen schedule history and reverse receipts latest first; trade-in purchased used goods enter 1320 and offsets release margin. Build mobile assigned-collector flow with own cash account and printable receipts; no interest/percentage in customer UI. Add pgTAP exact piasters, balance and reconciliation for every posting path, role/tenant/lock/concurrency checks, Playwright collector flow.`

**Converge/DoD:** T04, T05, T06, T07, T08, T09, T10, T11, T15, T21 (all exact Section 14 expected values); T19 for new objects and prior regression. Never claim T09 creates a journal when no extra margin was added.

### B7 — Treasury & partners

**Specify input:** `Let the owner reconcile cash shifts and transfers, expenses and partner capital/current/drawings, close period profit by approved shares, and onboard paper balances without corrupting GL controls. Scope: Sections 5.2, 6.9–6.10, 6.13, 7.3 N–S, 9, 14, 17 B7, 18.`

**Plan input:** `Implement expense, transfer, shift, partner transaction, period close and opening balance posting RPCs, partner share validation and gapless numbers, with exact Section 7 journal entries and row locking. Build opening wizard against 3999, finish by reclassifying to partner capital; cash balances and daily close read ledger only; reuse B2 expense attachments. Add pgTAP 60/40 closing + drawings vector, daily cash balance, permission, isolation, idempotency and reconciliation tests; Playwright treasury/onboarding flow.`

**Converge/DoD:** T24; daily closing matches ledger; T19 for new objects and prior regression. First-client paper parallel run remains a go-live requirement, not a B7 test pass.

### B8 — Reports

**Specify input:** `Give authorized owners/managers/accountants trustworthy, traceable business reports and subledger reconciliation, with printable and Excel outputs, while hiding cost/profit from cashiers. Scope: Sections 2 P1/P8, 5.2, 6.11, 7, 9, 12, 14, 17 B8, 18.`

**Plan input:** `Implement every Section 6.11 report: report monetary totals from journal_lines only with dimensions; schedule/subledger only for due dates, aging and operational detail reconciled to GL. Add date/dimension filters, Excel export, print, journal drill-down, role-safe views, 100k-line indexing as specified in Section 12 (no speculative summaries). Include seeded complete-scenario trial balance/reconciliation pgTAP and Playwright drill-down/export tests.`

**Converge/DoD:** T22: trial balance Σ debit = Σ credit and all reconciliation differences zero; every report total matches the corresponding trial-balance/GL lines where applicable; regression T01–T30 applicable by B8 plus T19 on new report interfaces. **First-client go-live eligibility begins after B8 minimum, then ≥2 weeks parallel paper run with daily reconciliation (Section 17); not automatic launch approval.**

### B9 — Dashboard & polish

**Specify input:** `Make the completed MVP usable end-to-end for Arabic-speaking showroom staff, including dashboard KPIs, overdue follow-up links, settings, audit trail and onboarding, without adding new financial calculations outside the ledger. Scope: Sections 5, 6.11–6.14, 11, 14, 17 B9, 18.`

**Plan input:** `Build ledger-derived KPI dashboard and overdue operational lists, Section 11 WhatsApp reminder links (not API sending), owner settings and audit UI, end-to-end onboarding flow. Enforce role visibility, RTL/mobile collector UX and print behavior. Playwright signup → setup → purchase → cash sale → installment sale → collections → reports, plus security regression and all applicable Section 14 checks.`

**Converge/DoD:** No newly assigned Section 14 T ID; all applicable T01–T30 must remain green. Section 17 B9 complete Playwright journey; daily ledger consistency and T19 regression verified.

### B10 — Hardening

**Specify input:** `Prepare the MVP for a controlled paid pilot by proving tenant/security boundaries, reliable failures, restorable data export and performance at stated load, without expanding product scope. Scope: Sections 2, 6.15, 9–10, 12, 14–15, 17 B10, 18.`

**Plan input:** `Audit every RPC SECURITY DEFINER role/search_path, privilege and RLS policy including storage; test cross-tenant and cashier-cost isolation and concurrent posts. Seed 100k journal lines, measure Section 12 latency targets (POS search <200 ms/10k products, dashboard <1.5 s, reports <3 s/100k lines), validate Arabic support-code errors, daily backups, owner-only tenant-level Excel data export, and Section 6.15 attachment export in a ZIP. Run full pgTAP T01–T30, Playwright, unit, typecheck, lint and seeded reconciliation; document evidence and security signoff. No Python/FastAPI, VAT, multi-branch, automated billing, WhatsApp API or AI.`

**Converge/DoD:** No newly assigned Section 14 T ID; rerun **all T01–T30**, verify Section 12 targets and signed-off security checklist. Founder approves readiness for pilot only after security/performance evidence and the first-client parallel-run gate; do not conflate technical convergence with go-live approval.

## Owner assignment and human gates

- **Default primary builder: Claude Code for B0–B10** on the current batch branch, including the Spec Kit feature artifacts, implementation, migrations (when needed), and test evidence. **Independent reviewer: Codex** on a separate review branch or read-only snapshot, checking the canonical spec, constitution, tests, and diff; Codex does not modify the builder branch or create competing migrations. For any confirmed defect, Claude Code fixes it on the batch branch and reruns checks; Codex rechecks the changed surface. If Claude Code is unavailable, Codex may own the *whole* next batch after Abdullrahman explicitly assigns it, with Claude Code reviewing; never mix ownership halfway through a DB migration. Section 18.19 permits parallel work only on separate branches and separate batches, but Section 17's sequential human gate still prohibits starting the next batch early.
- **Before implementation:** Abdullrahman reviews generated `spec.md`, `plan.md`, requirement checklist and `/speckit-analyze` report for spec fidelity, scope and unresolved decisions; approve checklist items only after actual review. Do not implement while a material `[NEEDS CLARIFICATION]` or constitutional contradiction remains.
- **Before moving on:** builder supplies changed-file list, migration diff and generated types, journal arithmetic where applicable, exact test commands/output, convergence verdict, CI evidence, `DECISIONS` and `CHANGELOG` entry, and known risks; Codex supplies independent P0/P1 findings with file/line references. Abdullrahman checks each applicable Section 14 test and Section 17 DoD, either requests fixes or gives an explicit Bn approval. Nothing outside Bn is merged as hidden scope; put it on a later list. A `Converged` verdict is not Abdullrahman's approval.

## Sources for current tool syntax

- [Spec Kit README](https://raw.githubusercontent.com/github/spec-kit/main/README.md) — setup prerequisites, skill sequence and convergence loop.
- [Agentic SDD reference](https://github.github.io/spec-kit/reference/agentic-sdd.html) — order, optional quality gates and append-only `/speckit.converge` behavior.
- [Integrations reference](https://github.github.io/spec-kit/reference/integrations.html) — Claude/Codex keys, skill names, installation and multi-install constraints.
- [Existing-project guide](https://github.github.io/spec-kit/guides/existing-projects.html) — `specify init --here --force` precautions.
- [Spec-driven methodology](https://raw.githubusercontent.com/github/spec-kit/main/spec-driven.md) — spec-first rationale (some historical dotted command examples; prefer current integration docs for invocation).
