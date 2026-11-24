# Write Query Retry-Safety Review

This note records the behavior a caller should expect if a request is retried.
It is based on the write statements in `dbms/04_queries.sql`; a conflict-safe
statement still needs the application to check its affected-row count.

| Query | Current behavior on retry | Caller guidance |
|---|---|---|
| W1 | `DO NOTHING` for any primary-key or unique-key conflict | Check `INSERT 0 0`; distinguish an existing username/email from a successful registration. |
| W2–W4 | Upsert by the user key | Safe for final state; each retry refreshes the change timestamp. |
| W5 | `DO NOTHING` for an existing user/role pair | Safe to retry. |
| W6 | Upsert by `(owner_user_id, deck_slug)` | Reuse the same owner and slug; a primary-key collision on a different slug still fails. |
| W7 | `DO NOTHING` for an existing `card_id` | Retry with the same card ID; check the affected-row count before reporting creation. |
| W8 | `DO NOTHING` for an existing `media_id` | Retry with the same media ID; check the affected-row count before reporting attachment. |
| W9–W10 | Plain inserts with fixed primary keys | Not retry-safe yet; use a stable request/event ID and handle duplicate-key responses. |
| W11 | Upsert by `(user_id, card_id)` | Safe against duplicate state rows, but do not apply the learning event twice; deduplicate the review event first. |
| W12 | Updates only while `session_end IS NULL` | Repeating a successful close is a no-op. |
| W13 | `DO NOTHING` for an existing user/achievement pair | Safe to retry. |
| W14 | Set profile values | State is repeatable; `updated_at` changes on each retry. |
| W15 | Append an audit event with a generated ID | Do not retry blindly without an event/idempotency key, or duplicate audit events may be recorded. |

The benchmark wraps writes in `BEGIN`/`ROLLBACK`; that guarantees repeatable
timing runs, but it does not by itself guarantee safe application retries.
