# Individual Analysis: Leaderboard Aggregation (R11)

## Failure mode

R11 combines two independent one-to-many relationships for each learner: earned achievements and review history. Joining both detail tables before aggregation creates a fan-out. For example, two achievements and two reviews form four joined rows. `COUNT(DISTINCT ...)` can protect counts, but a plain `SUM(xp_value)` still counts each achievement more than once.

## Corrected shape

The corrected query aggregates achievements and reviews separately by `user_id`, producing at most one row per learner from each side, and then joins those results to the active learner set. This makes the intended grain explicit and prevents one relationship from multiplying the other. The small regression fixture recorded in `dbms/06_query_review.md` returns 150 XP, two achievements, and two reviews; the previous join returned 300 XP.

## Performance interpretation

The corrected plan's small-fixture timings in `dbms/05_query_timings.md` are correctness-smoke-run measurements. They should not be compared directly with the other queries measured on the 10,000+ tuple dataset. To make a performance claim, rerun R11 on the full benchmark dataset with the same run count, database state, PostgreSQL settings, and cache protocol used for the other query plans.

## General lesson

When aggregating multiple child tables, aggregate each child to the parent's key before joining, or use separate correlated subqueries where appropriate. Verify both the result cardinality and aggregate values with a fixture that has more than one row in each child table; a one-row fixture cannot expose this fan-out bug.
