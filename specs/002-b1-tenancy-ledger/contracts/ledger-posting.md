# Contract: B1 Ledger Posting Primitives

B1 exposes no production manual-journal RPC. pgTAP defines a rollback-scoped helper that composes the internal primitives below in the same order later posting functions must use.

## Test-helper request

```text
tenant_id: uuid
request_id: uuid
entry_date: YYYY-MM-DD Cairo date
source_type: non-empty test identifier
source_id: uuid
description: non-empty text
lines: array with at least two items
  account_id: uuid
  debit: canonical signed-64-bit piaster decimal string
  credit: canonical signed-64-bit piaster decimal string
  memo and nullable dimension UUIDs
```

Runtime SQL converts validated decimal strings directly to `bigint`; no JSON number is accepted for money.

## Test-helper result

```json
{
  "entry_id": "uuid",
  "entry_no": "positive decimal integer string",
  "entry_date": "YYYY-MM-DD",
  "debit_total": "canonical piaster decimal string",
  "credit_total": "canonical piaster decimal string"
}
```

All monetary JSON fields are produced from SQL text casts before JSON construction.

## Posting order

1. Verify authenticated actor and required same-tenant role.
2. Acquire/check the idempotency record using request id, operation name, and payload fingerprint.
3. If an identical completed request exists, return its canonical stored result.
4. Validate date, source, description, line shape, piaster bounds, account activity/header state, and same-tenant ownership.
5. Lock the tenant and reject suspension or `entry_date <= lock_date`; accept any otherwise valid Cairo civil date, including a future date because B1 defines no upper-period lock.
6. Allocate `journal_entry` number under the tenant/type/year counter lock.
7. Insert one entry and all lines.
8. Assert the entry has at least two lines and exact debit=credit (also enforced deferred at commit).
9. Store and return the canonical result.

Any error rolls back every step, including counter and idempotency rows.

## Idempotency outcomes

| Existing request | Outcome |
|---|---|
| none | process normally |
| same RPC + same payload, completed | return stored result; no new rows/number |
| different RPC or payload | reject request-id reuse |
| concurrent identical request | one processes; the other waits and returns the same completed result |
| prior transaction failed | no durable request row; retry may process normally |

## Reversal request

```text
tenant_id: uuid
request_id: uuid
original_entry_id: uuid
reversal_date: YYYY-MM-DD Cairo date
reason: non-blank text
```

The initiating orchestrator supplies and verifies the permitted role. The internal primitive itself is not granted to browser roles.

## Reversal result

Same canonical result shape as posting, plus `original_entry_id`. Every original line is copied with debit/credit swapped and all dimensions/memo preserved. The original rows remain unchanged except the guarded `reversed_by_entry_id` link; the new header contains `reverses_entry_id`.

## Reversal rejection cases

- wrong tenant or missing entry;
- locked reversal date or suspended tenant;
- empty reason;
- original already reversed;
- original is itself a reversal;
- request-id mismatch/reuse;
- caller/orchestrator lacks the required role;
- any resulting imbalance or cross-tenant account/dimension mismatch.

## Exact B1 vectors

1. Debit `cash_main` `2_000_000`, credit `opening_equity` `2_000_000` → accepted; totals return `"2000000"`.
2. Debit `cash_main` `9_007_199_254_740_993`, credit `opening_equity` same → exact accepted round trip above JavaScript safe integer.
3. Debit `100`, credit `99` → rejected with no rows/counter/request result.
4. Two retries of vector 1 with one request id → one entry, one number, identical result.
5. Reversal of vector 1 → debit/credit swapped; combined account net is zero; original unchanged.
