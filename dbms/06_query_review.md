# CP4 Query Review: R11 Leaderboard

## Finding

The original R11 joined a user's achievements and review history before
aggregating both. Those are independent one-to-many relationships. A user with
two badges and two reviews produced four joined rows, so `SUM(xp_value)` counted
each badge twice. `COUNT(DISTINCT ...)` protected the badge and review counts,
but did not protect the XP sum.

## Correction and verification

R11 now aggregates achievements and reviews separately by `user_id` and joins
those one-row-per-user results to the active user/profile list. A local
regression fixture with two badges worth 100 and 50 XP, plus two reviews,
returned **150 XP, 2 badges, 2 reviews**. The old join returned 300 XP for the
same fixture.

`plans/R11.txt` contains three `EXPLAIN (ANALYZE, BUFFERS)` captures of the
corrected query on that small fixture. Those timings are correctness-smoke-run
measurements, not comparable to the 10,000+ tuple benchmark in
`05_query_timings.md`. Rerun R11 against the full benchmark dataset before using
an updated performance comparison.

## W1 duplicate-email handling

The registration example originally named only the `username` constraint in
`ON CONFLICT`. The schema also requires a unique `email`, so an email already
owned by another account raised a uniqueness error instead of following the
query's duplicate-safe path. W1 now uses unqualified `ON CONFLICT DO NOTHING`,
covering the primary key and both unique constraints. A local collision fixture
confirmed the statement returns `INSERT 0 0` without changing the existing
account.
