# Cognify Database Query Timings & Performance Benchmark (CP4)

**Project:** Cognify — Adaptive Cognitive Training & Spaced-Repetition Platform
**Team:** T0004 · Section: D · Academic Year: 2026
**Deliverable:** Checkpoint 4 (CP4) — Query Plan Capture & Timing Benchmarks
**Environment:** PostgreSQL 18.4 (ARM64 / macOS), 16 BCNF Normalized Tables, 10,000+ benchmark tuples. R11 was corrected and rechecked separately on a small regression fixture; see the note below.

---

## 1. Official Query Timings Table

All timings were recorded using PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` executed across **3 consecutive runs** on populated tables with fresh query planner statistics (`VACUUM ANALYZE`). All `WRITE` queries were executed inside transactional `BEGIN; ... ROLLBACK;` blocks to ensure identical database state across iterations.

**R11 benchmark note:** R11 was corrected after its original 10,000+ tuple timing. Its replacement row above comes from a small one-user regression fixture that verifies independent XP/review aggregation, so its latency is not directly comparable with the other rows. `plans/R11_pre_fix.txt` preserves the original benchmark; `plans/R11.txt` contains three plans for the corrected query. Re-run R11 on the full benchmark dataset for an apples-to-apples performance result.

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|:---|:---:|:---|---:|---:|---:|---:|:---|
| R1 | READ | Authenticate user by email or username, verify active status, and aggregate assigned roles | 0.224 | 0.123 | 0.122 | 0.156 | Index Scan, Seq Scan |
| R2 | READ | Fetch user dashboard profile, timezone, daily study goal, and cognitive assessment status | 0.052 | 0.053 | 0.042 | 0.049 | Seq Scan |
| R3 | READ | Fetch user psychometric cognitive baseline metrics and compute readiness score | 0.069 | 0.063 | 0.059 | 0.064 | Seq Scan |
| R4 | READ | Browse public decks filtered by topic category with creator attribution and total card count | 0.261 | 0.255 | 0.294 | 0.270 | Seq Scan |
| R5 | READ | Deck mastery breakdown for a learner across retention states (NEW, LEARNING, REVIEW, RELEARNING) | 0.107 | 0.098 | 0.099 | 0.101 | Index Scan, Bitmap Index/Heap Scan, Seq Scan |
| R6 | READ | Check active unfinalized study session for a learner | 0.068 | 0.067 | 0.064 | 0.066 | Index Scan, Bitmap Index/Heap Scan, Seq Scan |
| R7 | READ | Spaced Repetition (SM-2) due queue for a user in a target deck, prioritized by state and due date | 0.100 | 0.115 | 0.103 | 0.106 | Index Scan, Bitmap Index/Heap Scan, Seq Scan |
| R8 | READ | Fetch flashcard details with all attached multimedia assets | 0.054 | 0.043 | 0.050 | 0.049 | Index Scan, Seq Scan |
| R9 | READ | Chronological card review telemetry history and latency trend for a learner | 0.069 | 0.070 | 0.069 | 0.069 | Index Scan, Bitmap Index/Heap Scan, Seq Scan |
| R10 | READ | Comprehensive study session performance report with duration, accuracy rate, and average latency | 0.130 | 0.124 | 0.124 | 0.126 | Index Scan, Bitmap Index/Heap Scan, Seq Scan |
| R11 | READ | Global student leaderboard ranked by total earned XP and completed reviews (small correctness fixture) | 0.314 | 0.424 | 0.377 | 0.372 | Seq Scan, HashAggregate |
| R12 | READ | Fetch user unlocked achievements, tiers, XP values, and unlock timestamps | 0.044 | 0.041 | 0.088 | 0.058 | Seq Scan |
| R13 | READ | Fetch locked achievements available for a learner to earn | 0.042 | 0.043 | 0.044 | 0.043 | Seq Scan |
| R14 | READ | Deck creator analytics measuring learner engagement, total reviews, and average rating | 0.816 | 0.822 | 0.839 | 0.826 | Seq Scan |
| R15 | READ | Security audit trail inspection with IP address, user agent, and action classification | 0.038 | 0.037 | 0.039 | 0.038 | Seq Scan |
| W1 | WRITE | Register a new user account | 0.206 | 0.169 | 0.170 | 0.182 | Insert |
| W2 | WRITE | Store secure password hash and salt for user credentials | 0.131 | 0.094 | 0.209 | 0.145 | Insert |
| W3 | WRITE | Initialize or provision a user profile with timezone and daily study goal | 0.138 | 0.105 | 0.106 | 0.116 | Insert |
| W4 | WRITE | Record initial or updated cognitive baseline psychometric assessment | 0.137 | 0.107 | 0.104 | 0.116 | Insert |
| W5 | WRITE | Assign access role to a user | 0.039 | 0.037 | 0.038 | 0.038 | Insert |
| W6 | WRITE | Create a new flashcard deck under a designated topic | 0.162 | 0.134 | 0.128 | 0.141 | Insert |
| W7 | WRITE | Add a new flashcard item with prompt, solution, type, and difficulty | 0.547 | 0.362 | 0.369 | 0.426 | Insert |
| W8 | WRITE | Attach media asset to flashcard | 0.422 | 0.376 | 0.349 | 0.382 | Insert |
| W9 | WRITE | Initialize and start a new study session | 0.557 | 0.902 | 0.790 | 0.750 | Insert |
| W10 | WRITE | Log single card review event telemetry | 0.539 | 0.525 | 0.464 | 0.509 | Insert |
| W11 | WRITE | Upsert spaced repetition state (SM-2 Algorithm mutation) | 0.260 | 0.252 | 0.228 | 0.247 | Insert |
| W12 | WRITE | Finalize study session run with end timestamp | 0.191 | 0.169 | 0.158 | 0.173 | Update, Seq Scan |
| W13 | WRITE | Award milestone badge / achievement unlock to a user | 0.048 | 0.049 | 0.050 | 0.049 | Insert |
| W14 | WRITE | Update user profile details and adjust daily goal minutes | 0.103 | 0.091 | 0.092 | 0.095 | Update, Seq Scan |
| W15 | WRITE | Record security audit event log for sensitive operations | 0.655 | 0.427 | 0.453 | 0.512 | Insert |

---

## 2. Query Analysis & Viva Notes

### A. Index Utilization & Access Paths
- **Effective B-Tree Index Utilization (`Index Scan` & `Bitmap Index Scan`):**
  - **Query R7 (Spaced Repetition Due Queue):** Uses `Bitmap Index Scan` on `idx_card_progress_due_queue (user_id, next_review_due)` and `idx_cards_deck_id (deck_id)` to filter active review cards. Rather than scanning all 1,600 card progress rows, Postgres constructs an in-memory TID bitmap directly from the B-tree leaf pages, yielding an average execution time of **0.106 ms**.
  - **Query R5 (Deck Mastery Breakdown):** Leverages `Bitmap Index Scan` on `idx_cards_deck_id` and the compound index on `card_progress`, achieving **0.101 ms** across multi-state conditional aggregations.
  - **Query R1 (IAM Authentication & Roles):** Performs an `Index Scan` on `roles_pkey` (`roles(role_id)`) to resolve role names in **0.156 ms** with shared buffer hits = 10.
  - **Query R8 (Card Detail & Media Retrieval):** Executes an `Index Scan` via `cards_pkey` to locate the target flashcard before joining media assets, resolving in **0.049 ms**.
  - **Query R6, R9, R10 (Interaction Telemetry & Study Sessions):** Harness `idx_review_logs_session_id` and `idx_review_logs_card_id` to join telemetry logs against sessions without table-wide sequential scans.

### B. Planner Decision-Making: When and Why `Seq Scan` is Optimal
- In relational DBMS engine design, a `Seq Scan` is not inherently slow; it is chosen by the cost-based optimizer (CBO) whenever:
  1. **Small Dimension Tables:** For tables fitting in 1 to 2 disk pages (e.g., `topics` with 10 rows, `achievements` with 10 rows, `user_profiles` with 104 rows), reading contiguous 8 KB blocks sequentially in memory is significantly cheaper than random I/O traversal through B-tree root, interior, and leaf pages (`cost = 0.00..1.50`).
  2. **High Selectivity Threshold:** Queries such as **R11 (Global Leaderboard)** and **R14 (Deck Creator Analytics)** perform multi-table window functions and comprehensive group aggregations across almost the entire dataset. In such cases, an index lookup would require random single-row heap fetches for every entry; sequential page streaming minimizes block reads.

### C. Buffer Hit Ratio & Cache Efficiency
- **Shared Buffer Cache Performance:** In all 30 queries across Runs 2 and 3, the execution plans demonstrate **100% Shared Buffer Hit ratios** (`shared hit` without any disk `read` or `written`).
- **Warm Cache Acceleration:** Initial cold reads (Run 1) require dictionary catalog parsing and page loading into Postgres shared memory (e.g., R1 dropped from **0.224 ms** in Run 1 to **0.122 ms** in Run 3; W7 dropped from **0.547 ms** to **0.369 ms**).

### D. Write Operation Overhead & ACID Integrity
- **Constraint Validation & Index Maintenance:**
  - Write operations (**W1 – W15**) average between **0.038 ms** and **0.750 ms**.
  - Queries inserting into tables with foreign keys and unique constraints (e.g., **W7** inserting a card with deck FK validation; **W9** initiating a study session with user and deck FK checks; **W10** logging review telemetry) incur small, predictable constraint evaluation latencies (**0.30–0.75 ms**).
  - **W11 (SM-2 Spaced Repetition Upsert):** Features an `ON CONFLICT (user_id, card_id) DO UPDATE` clause with ease factor and interval calculation logic. The unique index `uq_user_card_progress` enables instantaneous conflict arbitration in **0.247 ms**.
  - All write runs verified zero rollback leakage, maintaining strict transaction isolation.
