# Hesbetak Accounting Contract

This document starts with B1 and records only accounting behavior already delivered or approved for the current batch. `docs/HESBETAK_SPEC.md` remains authoritative.

## Money

- Storage unit: integer piasters in PostgreSQL and TypeScript `bigint`.
- 1 EGP = 100 piasters.
- No floating-point financial arithmetic.
- Financial JSON values are canonical decimal strings built from SQL text casts before decoding.
- Shared application parsing/formatting/rounding remains in `src/lib/money.ts`.

## Tenant boundary

- One tenant represents one showroom.
- `tenants.id` is the root tenant identity; every tenant-owned child row carries `tenant_id` and RLS.
- Active membership is required for access. Inactive membership grants none.
- A suspended tenant is readable by authorized members but rejects ordinary writes.
- Permissions are authoritative in database operations, not only the UI.

## B1 chart of accounts

Tenant bootstrap seeds the full chart from Section 7.1 of the master specification. Application behavior resolves required system accounts by `system_key`, never by account code. Codes remain display/bookkeeping identifiers.

B1 seeds tenant, active owner membership, and chart only. Default cash-account records, expense-category records, and installment-plan templates begin in B2.

## Journal invariants

- `journal_entries` and `journal_lines` are the financial source of truth.
- Every completed entry has at least two lines.
- Exact total debit equals exact total credit in piasters.
- Each line has exactly one positive side and one zero side.
- Entry, account, and every line belong to one tenant.
- Header and inactive accounts cannot receive postings.
- Posted lines are never updated or deleted.
- Browser roles cannot insert, update, or delete ledger rows directly.
- B1 ships no production manual-journal endpoint; pgTAP uses a rollback-scoped helper only.

## Business dates and locks

- Entry and lock dates are Cairo civil dates.
- Posting/reversal requires `entry_date > tenant.lock_date` when a lock exists.
- The tenant row is locked while validating the period so lock changes cannot race a posting.
- B1 defines no upper/current-period lock, so an otherwise valid future Cairo date is accepted.

## Gapless numbering

- Number partitions are `(tenant_id, document_type, civil_year)`.
- The relevant counter row is locked and incremented inside the posting transaction.
- Rollback also rolls back the increment; committed numbers have no duplicates or gaps.
- PostgreSQL sequences are not used for gapless document numbers.

## Idempotency

- Every financial posting accepts a caller-generated `request_id` unique within the tenant.
- The request record binds that id to the operation name and canonical payload fingerprint.
- An identical completed retry returns the original canonical result without another effect or number.
- Reuse for another operation or payload is rejected.
- A failed transaction leaves no completed request, ledger effect, or permanent counter increment.

## Reversals

- Corrections are append-only reversals; originals remain intact.
- The internal B1 reversal primitive mirrors every line by swapping debit and credit while preserving account, dimensions, and memo.
- Original and reversal headers retain bidirectional links.
- A reversal requires an unlocked date, non-empty reason, authorized initiating role, and idempotent request.
- Already reversed entries and entries that are themselves reversals are rejected.
- The raw ledger reversal primitive is not executable by browser roles. Later document reversal RPCs must compose it with required stock, allocation, and subledger corrections in one transaction.

## Audit

Tenant, membership, lock-date, and secret-reference changes append immutable audit rows identifying tenant, actor, action, target, timestamp, and sanitized before/after data. Financial attribution remains on journal/request rows. Audit data is not a second source for balances and never contains secret plaintext.

## Secret references

B1 stores only typed tenant-scoped Vault UUID references, unique by tenant and secret kind. Owners may manage reference metadata through the documented operation. Secret values are never stored in tenant settings, audit rows, idempotency results, logs, or browser responses.

## B1 reconciliation boundary

B1 acceptance proves:

- every entry balances exactly;
- an entry plus its reversal nets to zero by account from `journal_lines`;
- retries do not duplicate effects;
- all tenant isolation checks pass.

Full document/subledger-to-GL reconciliation is not applicable until B3 introduces the first posted business document. Later reports must read financial totals only from `journal_lines`.
