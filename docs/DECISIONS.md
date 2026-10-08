# Decisions

## 2026-09-27 — Canonical master-spec path (confirmed)

- Question: Section 3.1 and Section 18 refer to `docs/HESBETAK_SPEC.md`, while the provided master spec was at repository root.
- Recommendation: Copy the root document byte-for-byte to `docs/HESBETAK_SPEC.md` and use the docs copy as the canonical agent reference; do not alter or discard the founder's root file.
- Decision: Abdullrahman approved this recommendation before the Spec Kit materials were prepared. The root file remains untouched. Future spec amendments require explicit approval and must be made to the canonical copy; reconcile the root copy with the founder before retiring it.
- Scope: Path selection only. No product, accounting, or batch rule changed.

## 2026-09-27 — B1 T17 acceptance versus document scope (approved)

- Conflict: Section 17 says B1 must pass T17, while Section 14 defines T17 as posting the same request id twice to obtain only one **document**. Section 17 B1 does not include a production posting document/RPC; its manual journal test helper cannot establish the full document claim.
- Recommendation: Test request-level idempotency with B1's journal test helper in B1; require the full document T17 at the first document-posting batch B3 and keep it in regression thereafter. Do not label the B1 partial test as full T17.
- Proposed explicit amendment to Section 17, B1 Definition of Done: replace `T16, T17, T19 pass; a manual JE via test helper balances; unbalanced JE rejected` with `T16 and T19 pass for B1 objects; idempotency is tested through the B1 journal test helper; a manual JE via test helper balances; unbalanced JE rejected. Full T17 with one posted document is required in B3.`
- Proposed explicit amendment to Section 17, B3 Definition of Done: replace `T13, T14 pass; inventory reconciliation = 0` with `T13 and full T17 pass; inventory reconciliation = 0; T14 purchase/weighted-average portion passes, and the complete T14 sale/COGS scenario is required in B4.` (See next open question.)
- Decision: Abdullrahman approved the recommended test timing. Section 17 B1 and B3 Definitions of Done in `docs/HESBETAK_SPEC.md` now use the exact replacement text above. T17 is not considered fully passed in B1; its complete document assertion is required in B3.

## 2026-09-27 — B3 T14 sale depends on B4 (approved)

- Conflict: Section 17 requires full T14 in B3; Section 14's T14 ends with `sell 5 → COGS 575`, but `post_cash_sale` is B4 scope.
- Recommendation: Verify purchase receipts and exact weighted average 115 in B3, then complete the sale/COGS portion in B4 rather than introducing out-of-batch cash sale posting.
- Proposed explicit amendment to Section 17, B3 Definition of Done: use the replacement text proposed above under the T17 question.
- Proposed explicit amendment to Section 17, B4 Definition of Done: replace `T01, T02, T12, T18, T20 pass` with `T01, T02, T12, T14, T18, T20 pass`.
- Decision: Abdullrahman approved the recommended test timing. Section 17 B3 and B4 Definitions of Done in `docs/HESBETAK_SPEC.md` now use the exact replacement text above. Full T14 remains mandatory in B4.

## Open questions policy

No open decisions remain from T17/T14. Record subsequent ambiguities with a recommendation and obtain Abdullrahman's confirmation before implementing the disputed behavior.

## 2026-09-27 — B0 Spec Kit setup record (informational, no decision needed)

- Spec Kit CLI `specify` 1.0.12 (Python 3.12.13), repaired by the founder. Initialized with `specify init --here --force --non-interactive --integration claude --script ps`, then `specify integration install codex` (per `docs/SPECKIT_WORKFLOW.md`). `specify integration status`: OK, installed `claude, codex`, 0 modified/missing managed files.
- Init diff: only new files under `.specify/`, `.claude/skills/`, `.agents/skills/`. No existing file was overwritten; SHA-256 of `docs/*` and the root `HESBETAK_SPEC.md` are identical before and after.
- Guardrail: the optional Spec Kit `agent-context` extension is **not installed** and must not be installed without founder approval. By default it injects a managed block into `CLAUDE.md` only, which would break the Section 0.5 / Section 18 requirement that `CLAUDE.md` and `AGENTS.md` are identical.
- The Spec Kit `git` extension is not installed, so `/speckit-specify` created the spec directory `specs/001-b0-foundation` but **no git branch** (see D-B0-07).

## B0 decisions (raised by `/speckit-clarify`, confirmed by Abdullrahman on 2026-09-27)

The founder approved options A for D-B0-01/02/04/05/06, option B (`bigint` in TypeScript with exact decimal strings at JSON boundaries) for D-B0-03, D-B0-08 in B1, D-B0-09 option B for B0 only, and explicitly authorized the B0 branch, commits, and push to `origin` under D-B0-07. These decisions apply to B0 planning; D-B0-03 was later extended project-wide and amends Section 18 Rule 3 of the master spec (see the Rule 3 amendment entry below). No B0 implementation or Git operation is claimed here.

### D-B0-01 — Money input parsing policy (blocks money parser tasks)

- Question: Which typed EGP inputs does the shared parser accept, and what happens with more than two decimals or a sign?
- Context: Section 2 P4 / Rule 3 require exact integer piasters; Section 11 is Arabic-first (Arabic keyboards emit Arabic-Indic digits). The spec does not define input rules.
- Options: A) strict parser (below); B) as A but round more than two decimals half-up; C) Western digits only.
- Recommendation: **A**. Accept Western digits or Arabic-Indic digits (`٠`–`٩`), one digit system per input; separators from one family per input — Western (`,` grouping, `.` decimal) or Arabic (`٬` grouping, `٫` decimal) — and either family may be used with either digit system; grouping only in valid 3-digit groups; at least one digit before and, if a decimal separator is present, at least one digit after it (1–2 digits accepted; 3 or more is a too-many-decimals error, not an invalid-format error); leading zeros allowed (`007` = 7 EGP); zero is valid (positivity is a per-form rule, not a parser rule); trim surrounding spaces, tabs, no-break spaces (U+00A0) and direction marks (U+200E, U+200F, U+061C) that often arrive when pasting RTL text. Reject with one of the five Arabic messages below: empty input; any sign (`-`/`+`); invalid format (exponent notation, internal spaces or direction marks, currency text, other characters, bad grouping, mixed digit systems or separator families); more than two decimals; values above the signed-`bigint` maximum. When several apply, the first in that order wins (empty → signed → invalid format → too many decimals → out of range). The approved maximum is the PostgreSQL signed-`bigint` maximum 9,223,372,036,854,775,807 piasters (92,233,720,368,547,758.07 EGP); negative internal balances may reach the signed minimum -9,223,372,036,854,775,808 piasters. Rationale: silently rounding typed money hides entry mistakes; sign is carried by the document type, not by the amount.
- Approval covers the input → result rules in `specs/001-b0-foundation/contracts/money.md` (§Parsing edge cases), **after updating the boundary rows to signed-`bigint` range**; the following user-facing Arabic messages are approved:
  - `empty`: أدخل المبلغ
  - `invalid_format`: صيغة المبلغ غير صحيحة
  - `too_many_decimals`: المبلغ يقبل رقمين فقط بعد العلامة العشرية
  - `signed`: أدخل المبلغ بدون علامة موجب أو سالب
  - `out_of_range`: المبلغ أكبر من الحد المسموح
- Decision: **Approved by Abdullrahman, 2026-09-27** — option A and the Arabic messages/input rules above, with PostgreSQL signed-`bigint` bounds.

### D-B0-02 — Negative amount display (blocks formatter negative branch)

- Question: How should a negative piaster amount (e.g. an overdrawn partner current account, Section 6.10) be displayed?
- Context: Section 11 fixes `20,000.00 ج.م` for positives only. In RTL text a bare leading minus can render on the wrong side.
- Options: A) `-20,000.00 ج.م`, with the signed number wrapped in Unicode left-to-right isolate marks (U+2066…U+2069) so the minus stays on the number's left; B) accounting parentheses `(20,000.00) ج.م`; C) trailing minus `20,000.00- ج.م`.
- Recommendation: **A**. Positive and zero output stays exactly `20,000.00 ج.م` / `0.00 ج.م` (plain U+0020 space as written in Section 11, no isolate marks); UI prevents line wrapping with CSS.
- Decision: **Approved by Abdullrahman, 2026-09-27** — option A.

### D-B0-03 — TypeScript money representation (blocks money module type)

- Question: Should TypeScript money values be `number` restricted to safe integers, or native `bigint`?
- Context: Rule 3 allows "`bigint`/`number` safe-integer in TS via `lib/money.ts`" without choosing.
- Options: A) `number` restricted to `Number.isSafeInteger` (|value| ≤ 9,007,199,254,740,991 piasters ≈ 90 trillion EGP), exposed as a branded `Piasters` type; intermediate products inside rounding helpers computed with `BigInt` and range-checked on return; B) native `bigint` everywhere.
- Original recommendation (superseded): A, restricted safe-integer `number`. Generated Supabase types can map `bigint` to `number`, but that is not a runtime precision guarantee: a JSON number may lose precision before `Number.isSafeInteger` can validate it.
- Decision: **Approved by Abdullrahman, 2026-09-27** — option B: PostgreSQL signed-`bigint` piasters end-to-end in financial TypeScript helpers; use exact base-10 integer strings at JSON/transport boundaries, validate their shape and signed-64-bit bounds, and convert string ↔ `bigint` without passing through a JavaScript `number`. In B1+, financial database reads/RPC results must yield text for monetary fields **before** JSON number parsing (e.g. authorized SQL projections/casts); never simply cast a value already decoded as a number. No new B1 object is built in B0. Keep generated database types unedited; document the transport adapter and test boundary/round trips when the B1 DB path exists.
- Scope extension: **Approved by Abdullrahman, 2026-09-27** — D-B0-03 applies **project-wide** (B0–B10), not only to B0 planning. Recorded as an explicit amendment of Section 18 Rule 3 (entry below).

### D-B0-04 — Rounding primitives: domain and scope (blocks rounding tasks)

- Question: What input domain do the rounding helpers support, and should the application layer contain any installment-schedule logic?
- Context: Section 17 B0 DoD requires rounding helpers; Section 8.2 defines `round_half_up` and `ceil_to_step` on non-negative values only; Section 9.2 makes `preview_installment_schedule` (Postgres, B5) the single shared schedule calculation.
- Options (original wording, written before D-B0-03 chose `bigint`; the approval line below governs): A) three primitives `mulDivRoundHalfUp(a, b, d)` = round_half_up(a × b / d), `mulDivFloor(a, b, d)` = floor(a × b / d), `divCeilToStep(n, d, step)` = ceil_to_step(n / d, step), for safe-integer arguments with `a, b, n` ≥ 0, `d` > 0, `step` > 0 (settings restrict steps to 100/500/1000 later), with the product `a × b` computed in `BigInt` so it never loses precision; a negative, zero-where-positive-required, non-safe-integer argument, or an unsafe result throws a programming error (not user-facing); no schedule function in TS; B) also support negatives (half away from zero); C) no rounding in TS in B0.
- Original recommendation: A's non-negative domain and three primitives, with safe-integer `number` inputs as originally proposed. The input type is superseded by the approved `bigint` choice in D-B0-03. Section 8.6 intermediates (600,000; 210,000; 150,000; 310,350; 192,500) and Section 14 T05 (28,571) remain exact tests; B invents a rule and C contradicts the B0 DoD.
- Decision: **Approved by Abdullrahman, 2026-09-27** — option A's non-negative domain and three primitives, adapted to D-B0-03's approved `bigint` operands/results with signed-64-bit result checks; no TypeScript installment schedule.

### D-B0-05 — Arabic-Indic digit output (lower impact; blocks one formatter option)

- Question: Should the B0 formatter already support Arabic-Indic digit output?
- Context: Section 11: "Western digits by default (setting for Arabic-Indic digits)". The setting UI belongs to Settings (B9).
- Options: A) formatter option `digits: 'latn' | 'arab'`, default `'latn'`; `'arab'` uses `٠`–`٩`, `٬` grouping, `٫` decimal; setting wiring later; B) defer entirely to B9.
- Recommendation: **A**. Keeps every money-format rule in one 100%-tested module; no settings storage in B0.
- Decision: **Approved by Abdullrahman, 2026-09-27** — option A.

### D-B0-06 — B0 app-shell content and deferred scaffolding (scope)

- Question: What exactly does the B0 app shell contain?
- Context: Rule 15 forbids placeholder data and stubs; Section 3.1 lists `(auth)`, `(app)/[tenant]`, `lib/supabase/`, `types/database.ts`, `seed.sql`, all of which have no consumer until B1.
- Options: A) one root page whose only content is an `<h1>` showing `APP_NAME.ar` (no tagline or other invented copy; the page title reads `APP_NAME.ar` as Section 0 already requires for metadata); root layout with `lang="ar" dir="rtl"` and IBM Plex Sans Arabic; shadcn/ui **configuration** (`components.json`, `cn()` helper with `clsx` + `tailwind-merge`, neutral theme tokens) and the Radix `DirectionProvider` set to RTL, treated as framework configuration required by the B0 scope "shadcn/ui RTL" (Section 17) and **not** as stubs, even though the B0 page uses no shadcn component yet; no shadcn component and no `lucide-react` until first used; `lib/supabase/*`, `types/database.ts`, route groups and `seed.sql` deferred to B1; B) also scaffold empty route groups and Supabase client factories now; C) as A but defer shadcn configuration and `DirectionProvider` until the first component is used.
- Recommendation: **A**. B adds unused code that Rule 15 treats as stubs; C leaves the Section 17 B0 scope item "shadcn RTL" undelivered. (Disabling Supabase seeding in B0 is not part of this decision: no seed can exist before B1's tables — Rule 2.)
- Decision: **Approved by Abdullrahman, 2026-09-27** — option A.

### D-B0-07 — Branch, commits, push, and root-spec tracking (operational; needs authorization)

- Question: May the builder create branch `001-b0-foundation`, commit, and push to `origin` (github.com/AbdullrahmanSayed/Hesbetak) to obtain CI evidence?
- Context: `main` has no commits and every file is untracked. "CI green" (Section 17 B0 DoD) needs a pushed branch. The workflow asks for a reviewable branch.
- Recommendation: Before `/speckit-implement`, create `001-b0-foundation`; commit docs + Spec Kit scaffolding + B0 artifacts (`docs:`), then small implementation commits (Rule 16); push the branch and open a PR for CI. Commit `.claude/skills/` and `.agents/skills/`; ignore local agent state (e.g. `.claude/settings.local.json`). Keep the root `HESBETAK_SPEC.md` **untracked and not gitignored** until the founder decides whether to commit or retire it.
- Decision: **Approved by Abdullrahman, 2026-09-27** — create `001-b0-foundation`, make small conventional commits, push only that branch to `origin` and open a PR for CI evidence. Do not push to `main` or merge without founder review; preserve the untracked root `HESBETAK_SPEC.md` and unrelated files.

### D-B0-08 — Batch that creates `docs/ACCOUNTING.md` (non-blocking for B0)

- Question: Which batch produces `docs/ACCOUNTING.md` (Section 3.1: "generated from Sections 7–8, kept in sync")?
- Context: No Section 17 batch lists it.
- Recommendation: B1 (chart of accounts and journal land there), then keep it in sync in every batch that adds a posting rule. Not produced in B0.
- Decision: **Approved by Abdullrahman, 2026-09-27** — create in B1, then keep in sync with later posting batches.

### D-B0-09 — Local evidence versus CI-only evidence for pgTAP and Playwright (operational)

- Question: If the builder machine still cannot run local Supabase (no Docker) or download Chromium (≈1.06 GB free disk), may B0's pgTAP and Playwright evidence come from CI only, with the local runs reported as `blocked` plus the exact error?
- Context: Rule 17 and `docs/SPECKIT_WORKFLOW.md` require reporting pgTAP against local Supabase and Playwright results for every batch. On 2026-09-27 the builder machine has no Docker, no global Supabase CLI, and ≈1.06 GB free on `C:`. CI runners provide Docker and browsers.
- Options: A) fix the machine before implementation (install Docker Desktop, free roughly 15 GB or more), so local and CI evidence both exist; B) accept CI-only evidence for pgTAP and Playwright in B0, with local runs reported `blocked` (never `passed`); C) postpone B0 implementation until A is done.
- Original recommendation: A (prepare Docker and disk locally); B was described as an acceptable B0-only fallback.
- Decision: **Approved by Abdullrahman, 2026-09-27** — option B for **B0 only**: run pgTAP and Playwright in CI; locally attempt the commands, report actual results or `blocked` with exact errors, never `passed` without execution. B0 still requires 5/5 green CI. Resolve local Docker/disk blockers before B1 database implementation; no standing exemption from Section 18 Rule 17.

### D-B0-10 — Negative amount with Arabic-Indic digits (approved)

- Question: How does `formatMoney` render a negative amount when `digits: 'arab'` (D-B0-02 combined with D-B0-05)?
- Decision: **Approved by Abdullrahman, 2026-09-27** — exactly `"\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م"` for −2,000,000 piasters: ASCII hyphen-minus (U+002D) directly before the Arabic-Indic digits, `٬` grouping, `٫` decimal, the signed number wrapped in U+2066 … U+2069, then U+0020 and `ج.م`. Exact test vector: `formatMoney(toPiasters(-2_000_000n), { digits: "arab" })` === `"\u2066-٢٠٬٠٠٠٫٠٠\u2069 ج.م"`.

### D-B0-11 — Timing of the SC-004 local clean-machine walkthrough (approved)

- Question: May B0's SC-004 evidence come from CI (jobs run the README setup and check commands from a fresh checkout, CI-only flags documented in README.md), with the local clean-machine walkthrough deferred to B1?
- Context: D-B0-09 permits CI-only pgTAP/Playwright evidence in B0 because the builder machine has no Docker and ≈1.06 GB free disk; a full local walkthrough needs both. Raised by `/speckit-analyze` on 2026-09-28.
- Recommendation: B0 evidence = 5/5 green CI running the README commands; the local walkthrough is performed after B1 entry obligation 2 and before B1 implementation.
- Decision: **Approved by Abdullrahman, 2026-09-28** — as recommended. B0-only; no standing exemption from SC-004 in later batches.

## 2026-09-27 — Amendment of Section 18 Rule 3 (money representation) — approved

- Trigger: D-B0-03 extended project-wide by Abdullrahman. The previous Rule 3 still allowed a `number` safe-integer representation in TypeScript, which B1+ agents could choose.
- Amended file: `docs/HESBETAK_SPEC.md` Section 18 Rule 3 (line 746). The founder's root `HESBETAK_SPEC.md` is **not** modified. It now differs from the canonical copy on this line and on the Section 17 B1/B3/B4 rows (earlier approved T17/T14 amendments); reconcile with the founder before retiring it.
- Replaced text: `` 3. **Money:** integer piasters (`bigint` in SQL, `bigint`/`number` safe-integer in TS via `lib/money.ts`). Never use floating-point for money. Never do money arithmetic in React components. ``
- New text: `` 3. **Money:** integer piasters. SQL and TS money use `bigint` piasters (TS via `lib/money.ts`); financial JSON values are validated decimal strings; database monetary results become text before JSON decoding. Never use floating-point for money. Never do money arithmetic in React components. ``
- Wording source: the three clauses are Abdullrahman's approval text of 2026-09-27; no earlier verbatim draft of this rule existed in the repository. The remaining sentences of Rule 3 are unchanged.
- Synced: `docs/SPECKIT_CONSTITUTION.md` (Section 18 copy) and `.specify/memory/constitution.md` (version 1.0.0 → 2.0.0, MAJOR, per its Governance policy). B0 `CLAUDE.md`/`AGENTS.md` will copy the amended Section 18 (tasks T036/T037).
- Decision: **Approved by Abdullrahman, 2026-09-27.**

## B1 entry obligations carried from B0 (must be read before B1 planning)

1. D-B0-03 / amended Rule 3: every financial database read or RPC result exposes monetary columns as text **before** JSON decoding (authorized SQL projections/casts); never cast a value already decoded as a JSON number. Keep `src/types/database.ts` generated and unedited; document the transport adapter; test DB-path round trips including values above `Number.MAX_SAFE_INTEGER` and the signed-`bigint` bounds.
2. D-B0-09: install a container runtime and free enough disk on the builder machine so pgTAP and Playwright run locally; the B0 CI-only fallback does not apply to B1.
3. D-B0-11 / B0 SC-004: perform the local clean-machine walkthrough of the documented setup once item 2 is done.
4. D-B0-08: create `docs/ACCOUNTING.md` in B1 and keep it in sync in later posting batches.

## 2026-09-28 — B0 implementation plan choices (technical defaults; no product or accounting rule)

Recorded under T040. None of these changes a product, accounting, or batch rule; each can be revisited without touching the master spec.

- Runtime and tooling (research R2–R9): Node.js 22 LTS in CI (`.nvmrc`), npm with a committed `package-lock.json`, Tailwind CSS v3 (`3.4.19`), `date-fns@3` + `date-fns-tz@3.2.0`, TypeScript 5.9, Vitest 5, Playwright 1.63, ESLint 8.57 with `eslint-config-next@14.2.35`, Supabase CLI `2.118.0` as a dev dependency.
- `eslint . --ext .ts,.tsx,.mjs --max-warnings 0` instead of `next lint`, because `next lint` skips `tests/` and root config files by default.
- No lint rule is disabled (Rule 14). The Rule 11 `new Date()` / `Date.now()` ban applies to `src/**` and exempts `src/lib/dates.ts` through ESLint `excludedFiles`, not by turning the rule off.
- `tailwind-merge@2.6.1` (dist-tag `tailwind-merge-2`): `tailwind-merge@3` targets Tailwind v4; the v2 line is the one compatible with the Tailwind v3 choice in research R4.
- `tailwindcss-animate` is not installed: shadcn only needs it for component animations, and B0 adds no component (D-B0-06).
- `cairoDayRange` finds a day's start by binary search for the earliest instant whose Cairo business date is the given date (the contract's own definition in `contracts/dates.md`). This replaces research R7's `fromZonedTime` + DST-gap fallback, so the result does not depend on how a library resolves the nonexistent local midnight on a DST-start day. The exact 23/24/25-hour vectors pass under UTC, America/New_York and Asia/Tokyo.
- `supabase/config.toml`: `project_id = "Hesbetak"` was generated by `supabase init` from the folder name. It is a local Docker project identifier, not a displayed product name, so the `APP_NAME` single-source rule (which covers UI, prints, emails, metadata) does not apply; the product-name guard covers `src/`. `db.major_version = 17` satisfies Section 3 (Postgres 15+).

## 2026-09-28 — B0 builder-machine notes (informational)

- The agent sandbox on the builder machine blocks writes outside the repository and piped child processes. Local runs therefore needed a temporary npm cache (`npm_config_cache` under `%TEMP%`) and elevated runs for Vitest (Vite spawns `net use` on Windows), Playwright (Chromium download to `%LOCALAPPDATA%\ms-playwright`, web server), and the Supabase CLI (`%USERPROFILE%\.supabase`). None of this affects the repository or CI.
- npm 12 on the builder machine blocks unapproved install scripts; it skipped only the optional `unrs-resolver` postinstall. CI uses the npm bundled with Node 22.
- Docker is still not installed: `npm run db:start` fails with `docker: command not found (podman also not found)`. B1 entry obligation 2 stands.

## Later — ideas noted during B0, not implemented (not part of any batch until confirmed)

- A CI check that `src/types/database.ts` matches `supabase gen types` output once B1 creates the first migration (Rule 9).
- A `.gitattributes` forcing LF for Markdown/SQL/TS files (the builder machine has `core.autocrlf=true`; the agent-rules guard already normalizes line endings).
- Upgrading from Next.js 14 (only backports; research R1) — requires a founder-approved amendment of Section 3.
- The Section 11 accent color and the Arabic-Indic digit setting wiring (B9 Settings).
## 2026-09-29 — PR base for `001-b0-foundation` (approved)

- Finding: `origin/main` now exists (`a89a4d0`, "Initial commit" created on GitHub 2026-09-29, containing only a two-line `README.md`). The B0 branch was started from the then-unborn local `main`, so the two histories share no commit and GitHub cannot open a pull request between them. Both sides contain a `README.md`.
- Done under D-B0-07: only `001-b0-foundation` was pushed; `main` was not touched. CI run https://github.com/AbdullrahmanSayed/Hesbetak/actions/runs/36562884729 is 5/5 green on `60dad1f`.
- Options: A) merge `origin/main` into `001-b0-foundation` with `--allow-unrelated-histories`, keeping the B0 `README.md` and adding the GitHub one-line description to it, then open the PR; B) rebase the B0 commits onto `origin/main` (rewrites the pushed branch history); C) review the branch without a PR and decide the merge approach at B0 approval.
- Recommendation: **A** — no history rewrite, no change to `main`, and the PR shows exactly the B0 diff plus the README reconciliation. Not performed until confirmed.
- Decision: **Approved by Abdullrahman, 2026-09-29** — option A. Merge `origin/main` into `001-b0-foundation` with `--allow-unrelated-histories`, keep the B0 `README.md` with the GitHub description folded in, push only `001-b0-foundation`, and open the PR into `main`. No push to `main` and no merge of the PR without founder review (D-B0-07).

## 2026-09-29 — B0 supported business-date range (approved)

- Finding: T047 review found that the original binary search was correct for the documented modern vectors and millisecond-exact, but the public `YYYY-MM-DD` contract did not state a supported year range. `0001-01-01` crossed the BCE boundary inside the search window, where year-of-era formatting broke the string-order invariant; `9999-12-31` could not form its next public `YYYY-MM-DD` date. Historical Cairo offsets can also produce day lengths outside the modern 23/24/25-hour set.
- Options reviewed: A) define a narrower modern range; B) support all civil four-digit years (`0001`–`9999`); C) defer extreme-year hardening.
- Decision: **Approved by Abdullrahman, 2026-09-29 — option B.** Year `0000` is invalid; `BusinessDate` supports `0001-01-01` through `9999-12-31`. Boundary search uses equality instead of lexical year ordering and computes the end boundary without constructing a public year-10000 `BusinessDate`. Historical Cairo offsets retain exact instant boundaries even when a historical day is not exactly 23, 24 or 25 hours.

## 2026-10-08 — B0 approval record

- Abdullrahman merged PR #1 (`001-b0-foundation` → `main`, merge commit `5ccdeaf`) on 2026-09-29 and confirmed on 2026-10-08 that this merge is his explicit approval of B0 (Section 17).
- The T047 fix `d1fb0e3` (approved option B above) was pushed after that merge; it reaches `main` through PR #2, with CI 5/5 green on `d1fb0e3` (run https://github.com/AbdullrahmanSayed/Hesbetak/actions/runs/37714023630).
- PR #1 carries no recorded Codex review on GitHub. From PR #2 onward, Codex reviews on the PR (`@codex review`) so the review is recorded.
- B1 still waits for the B1 entry obligations above, in particular a local container runtime and disk (D-B0-09 / D-B0-11); the B0 CI-only fallback does not apply to B1.
