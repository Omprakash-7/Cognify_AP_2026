# Individual Analysis: Reading Query Plans

## Small tables and sequential scans

The AP schema contains small lookup tables such as topics and achievements. A sequential scan can be the cheapest plan for these relations because it reads only a few pages. The presence of a sequential scan in `EXPLAIN` is not by itself evidence that an index is missing.

## Selective lookups and indexes

Queries that locate a learner's due cards or a specific card can benefit from indexes matching their filters and join keys. The plan should show whether the index actually narrows the rows, and whether the engine then performs expensive heap fetches. An index that is never selected, or that duplicates a primary-key/unique index, adds write and storage cost without improving the measured workload.

## How to validate a change

For a proposed index, compare `EXPLAIN (ANALYZE, BUFFERS)` before and after on the same populated dataset. Check returned rows as well as execution time, buffer reads, scan loops, and rows removed by filters. Repeat runs and report the sample count. For write-heavy statements, include insert/update timings because each applicable index must be maintained.

This interpretation follows the captured CP4 plans; it is a workload-specific observation, not a guarantee that the same plan will be chosen at a larger scale or with different planner settings.
