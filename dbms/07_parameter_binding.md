# Application Parameter Binding Guide

`dbms/04_queries.sql` uses fixed values so the CP4 workload is repeatable. The
application should send those values as PostgreSQL bind parameters instead of
building SQL strings from user input.

## Common bindings

| Query family | Bind values | PostgreSQL types |
|---|---|---|
| Account/profile (`R1`–`R3`, `W1`–`W4`) | login, user ID, identity fields | `text`, `uuid` |
| Deck/content (`R4`–`R8`, `R14`, `W6`–`W8`) | topic/category, deck/card IDs, owner ID | `text`, `uuid` |
| Study/review (`R6`–`R10`, `W9`–`W12`) | user/session/card IDs, review values, timestamps | `uuid`, integer types, `timestamptz`, boolean |
| Achievements/audit (`R12`–`R15`, `W13`, `W15`) | user ID, achievement ID, audit event fields | `uuid`, `text`, `inet`, `timestamptz` |

For optional filters, pass SQL `NULL` and express the optionality in the query;
do not append raw filter text. Keep page size as a bounded integer and dates as
typed `timestamptz` values. The hard-coded workload values remain useful for
reproducing the published plans; change them only when intentionally creating a
different workload and refreshing its plan/timing artifacts.
