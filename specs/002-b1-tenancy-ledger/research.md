# Phase 0 Research: B1 — Tenancy & Ledger Core

**Date**: 2026-10-12 | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

## R1 — Schema and API boundary

- **Decision**: Tenant-owned tables remain in `public` with RLS and generated types. Privileged helpers and financial primitives live in schema `app`, which is not added to the exposed API schemas. Exactly four browser operations are deliberately granted in `public`: `bootstrap_tenant`, `manage_membership`, `set_lock_date`, and `manage_tenant_secret_ref`; each delegates to fully qualified internal functions, including canonical `app.bootstrap_tenant`.
- **Rationale**: Keeping `app` unexposed reduces accidental RPC surface. Explicit wrappers make browser reachability and grants auditable while preserving the master spec's `app.*` internal naming.
- **Alternatives considered**: expose the whole `app` schema (larger attack surface); place every function in `public` (harder to distinguish internal primitives).

## R2 — Fixed execution context and privileges

- **Decision**: Every `SECURITY DEFINER` function declares `SET search_path = public, pg_temp`, fully qualifies `auth`, `app`, `vault`, and extension objects, verifies `auth.uid()`, and is owned by the migration owner. Revoke function execution from `PUBLIC`, `anon`, and `authenticated` before granting only documented browser operations.
- **Rationale**: PostgreSQL grants function execution to `PUBLIC` by default. A fixed path plus explicit qualification blocks caller-controlled name resolution and accidental exposure.
- **Alternatives considered**: caller search path (unsafe); granting all authenticated users execute and relying only on function checks (unnecessary defense reduction).

## R3 — Root tenant boundary and RLS

- **Decision**: `tenants.id` is the tenant identity. Every child B1 table has `tenant_id NOT NULL REFERENCES tenants(id)` and an index beginning with `tenant_id`. Tenant RLS checks membership against `tenants.id`; child policies use `app.is_member(tenant_id)`. The root table does not duplicate its own identifier in a self-referencing `tenant_id` column.
- **Rationale**: A self-reference adds no isolation and complicates bootstrap. Rule 10's tenant identity requirement is satisfied by the boundary key on the root and `tenant_id` on all owned children.
- **Alternatives considered**: duplicate/self-referencing tenant id (redundant and fragile); no RLS on tenants (cross-tenant disclosure).

## R4 — Bootstrap scope

- **Decision**: B1 bootstrap creates one tenant, one active owner membership, and the complete Section 7.1 account chart. B2 later extends bootstrap for default cash account, expense categories, and installment templates.
- **Rationale**: Those master-data tables are explicitly assigned to B2. Creating them early would violate the current-batch rule.
- **Alternatives considered**: pre-create B2 tables (rejected scope violation); omit the account chart (contradicts B1 DoD).

## R5 — Account chart identity

- **Decision**: Account code is unique per tenant for display/bookkeeping. `system_key` is nullable and unique per tenant when present; application behavior resolves system accounts only through `system_key`. Parent accounts must belong to the same tenant. Partner/cash-account UUID dimensions are nullable placeholders without foreign keys until their owning B2 tables exist.
- **Rationale**: Stable behavior cannot depend on changeable account codes. Deferred foreign keys avoid creating later-batch tables while preserving the specified shape.
- **Alternatives considered**: hardcoded code lookup (forbidden); omit future columns and edit the applied migration later (forbidden).

## R6 — Deferred balance enforcement

- **Decision**: A deferred constraint trigger validates each touched journal entry at transaction end: at least two lines, exact sum(debit)=sum(credit), matching tenant/account ownership, and no invalid sides. A transaction-local marker prevents redundant full checks while preserving deferred semantics.
- **Rationale**: Line-by-line immediate validation would reject the first half of every valid entry. Commit-time validation guarantees no unbalanced entry becomes durable.
- **Alternatives considered**: application-only assertion (not authoritative); statement trigger (does not cover multi-statement posting); numeric/float totals (forbidden).

## R7 — Append-only ledger

- **Decision**: Revoke direct ledger DML from browser roles and add mutation guard triggers so even privileged accidental updates/deletes fail unless a narrowly scoped internal reversal context performs only the permitted header-link transition. Journal lines are never updated or deleted.
- **Rationale**: Privileges alone do not protect against future privileged code mistakes. Reversal must preserve the original lines.
- **Alternatives considered**: privilege-only enforcement; mutable status flags or replacement entries.

## R8 — Idempotency fingerprint

- **Decision**: `posting_requests` is unique on `(tenant_id, request_id)` and records `rpc_name`, a canonical payload SHA-256 fingerprint, completion state, and canonical JSON result. Identical completed retries return the stored result; mismatched operation/fingerprint reuse is rejected. The row is locked during processing and rolls back with failed posting.
- **Rationale**: Request id alone cannot distinguish a legitimate retry from accidental reuse with different values.
- **Alternatives considered**: store only request/result (cannot enforce FR-019); commit an in-progress row separately (can strand requests after rollback).

## R9 — Gapless counters

- **Decision**: `document_counters` is keyed by `(tenant_id, doc_type, year)`. Allocation inserts the first row or locks the existing row `FOR UPDATE`, increments once inside the caller transaction, and returns the new positive `bigint`. Rollback also rolls back the increment.
- **Rationale**: Database sequences are not gapless and are not rolled back. Row locks serialize only the relevant tenant/type/year partition.
- **Alternatives considered**: sequence per tenant/type (gaps on rollback and operational sprawl); `max()+1` (race condition).

## R10 — Business dates and lock concurrency

- **Decision**: Posting and reversal lock the tenant row before comparing the SQL `date` against `lock_date`; dates on or before the lock are rejected. Lock-date updates also lock the same tenant row.
- **Rationale**: A shared row-lock order prevents the lock date from changing between validation and commit.
- **Alternatives considered**: unlocked read (race); timestamp comparison (violates Cairo business-date model).

## R11 — Internal reversal primitive

- **Decision**: B1 implements an internal, ungranted ledger reversal primitive. It locks the tenant and original entry, rejects locked/already-reversed/reversal entries, creates a new numbered entry, mirrors every line and dimension, writes bidirectional header links through the guarded internal context, and records the reason in immutable audit data. A pgTAP transaction-local helper invokes it for B1 acceptance tests.
- **Rationale**: A browser-accessible raw-ledger reversal would bypass stock and subledger corrections in later batches. Internal composition preserves one safe primitive.
- **Alternatives considered**: authenticated generic reversal (unsafe later); helper-specific implementation requiring redesign.

## R12 — Typed Vault references

- **Decision**: `tenant_secret_refs` stores `(tenant_id, secret_kind, vault_secret_id)` with one row per tenant/kind and no secret value. Kinds initially cover `whatsapp`, `n8n`, and `llm`. Active owners may create, replace, or remove reference metadata through `public.manage_tenant_secret_ref`; B1 grants no secret-value resolver.
- **Rationale**: Typed rows provide constraints and RLS without mixing references into settings. New kinds can be added deliberately without changing the security boundary.
- **Alternatives considered**: fixed tenant columns (schema change per kind); JSON map (weaker per-reference constraints); secret values in settings (forbidden).

## R13 — Audit scope

- **Decision**: Immutable `audit_log` rows capture actor, action, target, timestamp, and sanitized before/after JSON for tenant, membership, lock-date, and secret-reference changes. Financial entries retain their own actor/request metadata; reversal reason is additionally audited. Audit JSON rejects known secret-value keys and B1 code never reads Vault plaintext.
- **Rationale**: P12 requires attribution without creating a second financial source of truth or leaking secrets.
- **Alternatives considered**: database-wide generic JSON trigger (risks secrets and noisy financial duplicates); application-only logs (bypassable).

## R14 — pgTAP identity fixtures and test helper

- **Decision**: pgTAP tests create `auth.users`, set request JWT claims/user identity transactionally, create tenant fixtures through bootstrap, and roll back. The B1 manual-JE helper is defined only inside the pgTAP transaction and composes the production internal primitives in mandated order.
- **Rationale**: Tests exercise real Auth/RLS behavior without shipping a production manual journal endpoint or persistent fixtures.
- **Alternatives considered**: service-role-only tests (miss RLS); migration-defined test RPC (production surface/stub).

## R15 — Database type generation

- **Decision**: After local reset succeeds, generate `src/types/database.ts` with the pinned Supabase CLI from the local schema. Commit generated output unedited and add a unit guard that generation targets the current migration/schema contract.
- **Rationale**: Rule 9 requires regeneration after every migration and generated types may not be hand-maintained.
- **Alternatives considered**: handwritten database types (drift); postponing types until UI work (rule violation).

## R16 — Local Supabase mode and disk

- **Decision**: B1 pgTAP uses documented database-only startup excluding non-database services. Full-stack startup is not required for this database-only batch. Keep the Postgres image/volume and prune unused Supabase service images if disk pressure returns.
- **Rationale**: The restored environment successfully starts database-only Supabase. Full-stack startup failed health checks and consumed unnecessary disk for B1; database-only mode matches CI's pgTAP job.
- **Alternatives considered**: CI-only fallback (explicitly disallowed after B0); require all local services (no B1 consumer).
