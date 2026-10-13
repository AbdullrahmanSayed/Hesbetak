# Contract: B1 Database Security and Tenancy

## Browser-reachable operations

Only these B1 operations may be granted to `authenticated`; `anon` receives none:

| Operation | Caller | Result |
|---|---|---|
| `public.bootstrap_tenant` | authenticated user creating their own tenant | tenant id and slug; no secret/money values |
| `public.manage_membership` | active owner of the same writable tenant | sanitized membership metadata |
| `public.set_lock_date` | active owner of the same writable tenant | tenant id and resulting date |
| `public.manage_tenant_secret_ref` | active owner of the same writable tenant | secret kind and Vault UUID metadata only; never the value |
| tenant/account reads | active member | rows limited by membership and role |

Internal ledger, counter, idempotency, balance, reversal, audit-write, and Vault-resolution primitives have no browser execution grant.

## Required function order

Every privileged operation uses fixed `search_path = public, pg_temp`, fully qualified object references, and performs:

1. Resolve `auth.uid()`; reject absent identity.
2. Check active membership and required role.
3. Lock the tenant row for any write.
4. Reject ordinary writes when tenant status is `suspended`.
5. Validate inputs and tenant ownership.
6. Apply the change atomically.
7. Append sanitized audit metadata where required.
8. Return only the documented result.

## RLS matrix

| Object | SELECT | INSERT/UPDATE/DELETE |
|---|---|---|
| `tenants` | active member of that tenant | no direct browser DML |
| `memberships` | active same-tenant member; management through owner operation | no direct browser DML |
| `accounts` | active same-tenant member | no direct browser DML in B1 |
| `journal_entries`, `journal_lines` | active same-tenant member; later cost views may narrow fields | no direct browser DML |
| `document_counters`, `posting_requests` | no browser read needed | no browser DML |
| `audit_log` | active same-tenant owner/accountant | no browser DML |
| `tenant_secret_refs` | active same-tenant owner sees metadata only | no direct browser DML |

## T19 minimum matrix

For every table and browser-callable operation, pgTAP must prove:

- authorized same-tenant success;
- non-member denial;
- inactive-member denial;
- member of another tenant denial;
- tenant-id spoof denial;
- suspended tenant write denial;
- no elevated behavior from caller-controlled `search_path`;
- no direct ledger/counter/idempotency/audit write;
- no secret value returned.

## Grants

- Revoke `ALL` on new tables/functions from `anon` and `PUBLIC`.
- Grant `authenticated` table `SELECT` only where the RLS matrix permits.
- Grant `authenticated` function execution only on explicit browser operations.
- Internal functions must remain inaccessible even if their names are known.
- Applied migration ownership and service roles may execute internal primitives only through controlled transactions/tests.

## Audit sanitization

Audit JSON may contain scalar business metadata needed to explain a change. It must omit passwords, JWTs, Vault plaintext, service keys, secret payloads, and any field named or classified as a secret value. A Vault UUID reference may be recorded only when required to identify the changed reference.
