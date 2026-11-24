# CP5 Individual Analysis: SM-2 State Upserts

## Conflict grain

W11 uses `ON CONFLICT (user_id, card_id) DO UPDATE`, matching the composite
identity of one learner's scheduling state for one card. That makes repeated
writes converge on the same row rather than creating duplicate schedules.

## State transition concern

The conflict target guarantees row identity, but it does not by itself make a
review request idempotent. If the same review event is submitted twice, the
second update may increase the repetition count or interval again. A stable
review-event identifier, stored with a uniqueness constraint or processed in
the same transaction as the progress update, is needed when clients can retry
requests.

## Transaction boundary

The review log and the scheduling-state transition represent one logical
action. If they are written separately, a failure between them can leave an
event without updated scheduling state, or updated state without an event. A
production handler should commit both changes atomically and define how
duplicate event IDs are handled.

## Evidence

See W10 and W11 in `dbms/04_queries.sql`, plus the `review_logs` and
`card_progress` keys in `dbms/03_schema.sql`. Benchmarking W11 alone measures
the upsert statement, not the complete review transaction or retry path.
