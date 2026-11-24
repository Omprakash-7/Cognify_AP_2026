# Cognify Database Project

Team T0004 · Section D · PostgreSQL

This repository models the database for a cognitive training and
spaced-repetition app. For a short class walkthrough:

1. Start with [`dbms/01_normalization.md`](dbms/01_normalization.md) and
   [`dbms/02_er_diagram.svg`](dbms/02_er_diagram.svg) for the data model.
2. Browse the 30 read/write examples in [`dbms/04_queries.sql`](dbms/04_queries.sql).
3. Compare the measured plans in [`dbms/05_query_timings.md`](dbms/05_query_timings.md)
   and [`dbms/plans/`](dbms/plans/).
4. Discuss the leaderboard fan-out fix in [`dbms/06_query_review.md`](dbms/06_query_review.md):
   separate aggregates prevent achievements and reviews from multiplying each
   other's totals.
5. For the write-path discussion, compare W10's retry-safe review insert with
   W11's scheduling-state upsert in [`dbms/14_individual_analysis_sm2_upsert.md`](dbms/14_individual_analysis_sm2_upsert.md).

The notes distinguish query correctness from performance measurements; in
particular, the corrected R11 plan uses a small regression fixture and should
be rerun on the full benchmark dataset for a fair timing comparison.
