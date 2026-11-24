-- ============================================================================
-- Advanced Programming (AP) — Database Management Systems (DBMS)
-- Project: Cognify — Adaptive Cognitive Training & Spaced-Repetition Platform
-- Team: T0004 · Section: D · Academic Year: 2026
-- Deliverable: Checkpoint 3 (CP3) — Application SQL Queries & Workloads
-- File: dbms/04_queries.sql
-- Target DBMS: PostgreSQL 15+
-- ============================================================================
--
-- This script contains all 30 production SQL queries powering the Cognify platform
-- across all 6 core subsystems:
--   1. IAM (Identity & Access Management): users, credentials, roles
--   2. Profiles & Psychometric Baseline: user_profiles, cognitive_baselines
--   3. Content Hierarchy: topics, decks, cards, card_media
--   4. Spaced Repetition Engine (SM-2): card_progress
--   5. Interaction Telemetry & Study Sessions: study_sessions, review_logs
--   6. Gamification & Security Auditing: achievements, user_achievements, audit_logs
--
-- Standards Enforced:
--   - Explicit JOINs across relational boundaries (no implicit cross-joins or N+1 patterns)
--   - Tagged identifiers: -- R<N> -- READ: <description> and -- W<N> -- WRITE: <description>
--   - Idempotency & transactional safety via ON CONFLICT clauses
-- ============================================================================

SET search_path TO cognify, public;

-- ============================================================================
-- PART 1: READ WORKLOADS (R1 – R15)
-- ============================================================================

-- R1 -- READ: Authenticate user by email or username, verify active status, and aggregate assigned roles
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.is_active,
    c.password_hash,
    c.salt,
    c.mfa_secret,
    COALESCE(ARRAY_AGG(r.role_name ORDER BY r.role_name) FILTER (WHERE r.role_name IS NOT NULL), '{}') AS roles
FROM users u
INNER JOIN user_credentials c ON u.user_id = c.user_id
LEFT JOIN user_roles ur ON u.user_id = ur.user_id
LEFT JOIN roles r ON ur.role_id = r.role_id
WHERE (u.email = 'alex.smith@cognify.io' OR u.username = 'alexsmith')
  AND u.is_active = TRUE
GROUP BY u.user_id, u.username, u.email, u.is_active, c.password_hash, c.salt, c.mfa_secret;

-- R2 -- READ: Fetch user dashboard profile, timezone, daily study goal, and cognitive assessment status
SELECT 
    u.user_id,
    u.username,
    u.email,
    p.first_name,
    p.last_name,
    p.timezone,
    p.daily_goal_minutes,
    cb.working_memory_capacity,
    cb.processing_speed_ms,
    cb.baseline_assessed_at
FROM users u
INNER JOIN user_profiles p ON u.user_id = p.user_id
LEFT JOIN cognitive_baselines cb ON u.user_id = cb.user_id
WHERE u.user_id = '00000000-0000-0000-0000-000000000001'::uuid;

-- R3 -- READ: Fetch user psychometric cognitive baseline metrics and compute readiness score
SELECT 
    u.user_id,
    u.username,
    cb.working_memory_capacity,
    cb.processing_speed_ms,
    cb.baseline_assessed_at,
    ROUND((cb.working_memory_capacity * 10.0) + (1000.0 / GREATEST(cb.processing_speed_ms, 100)), 2) AS cognitive_readiness_score
FROM users u
INNER JOIN cognitive_baselines cb ON u.user_id = cb.user_id
WHERE u.user_id = '00000000-0000-0000-0000-000000000001'::uuid;

-- R4 -- READ: Browse public decks filtered by topic category with creator attribution and total card count
SELECT 
    t.topic_category,
    t.topic_name,
    t.topic_slug,
    d.deck_id,
    d.deck_title,
    d.deck_slug,
    d.deck_visibility,
    u.username AS creator_username,
    COUNT(c.card_id) AS total_cards,
    d.created_at
FROM decks d
INNER JOIN topics t ON d.topic_id = t.topic_id
INNER JOIN users u ON d.owner_user_id = u.user_id
LEFT JOIN cards c ON d.deck_id = c.deck_id
WHERE d.deck_visibility = 'PUBLIC'
  AND (t.topic_category = 'Computer Science' OR 'Computer Science' IS NULL)
GROUP BY t.topic_category, t.topic_name, t.topic_slug, d.deck_id, d.deck_title, d.deck_slug, d.deck_visibility, u.username, d.created_at
ORDER BY d.created_at DESC;

-- R5 -- READ: Deck mastery breakdown for a learner across retention states (NEW, LEARNING, REVIEW, RELEARNING)
SELECT 
    d.deck_id,
    d.deck_title,
    COUNT(c.card_id) AS total_deck_cards,
    COUNT(CASE WHEN cp.retention_state = 'NEW' OR cp.retention_state IS NULL THEN 1 END) AS count_new,
    COUNT(CASE WHEN cp.retention_state = 'LEARNING' THEN 1 END) AS count_learning,
    COUNT(CASE WHEN cp.retention_state = 'REVIEW' THEN 1 END) AS count_review,
    COUNT(CASE WHEN cp.retention_state = 'RELEARNING' THEN 1 END) AS count_relearning,
    ROUND(AVG(COALESCE(cp.ease_factor, 2.50)), 2) AS average_ease_factor
FROM decks d
INNER JOIN cards c ON d.deck_id = c.deck_id
LEFT JOIN card_progress cp ON c.card_id = cp.card_id AND cp.user_id = '00000000-0000-0000-0000-000000000001'::uuid
WHERE d.deck_id = '00000000-0000-0000-0000-000000001001'::uuid
GROUP BY d.deck_id, d.deck_title;

-- R6 -- READ: Check active unfinalized study session for a learner
SELECT 
    s.session_id,
    s.user_id,
    s.deck_id,
    d.deck_title,
    s.session_start,
    s.session_mode,
    s.device_info,
    COUNT(r.review_id) AS cards_reviewed_in_session
FROM study_sessions s
INNER JOIN decks d ON s.deck_id = d.deck_id
LEFT JOIN review_logs r ON s.session_id = r.session_id
WHERE s.user_id = '00000000-0000-0000-0000-000000000001'::uuid
  AND s.session_end IS NULL
GROUP BY s.session_id, s.user_id, s.deck_id, d.deck_title, s.session_start, s.session_mode, s.device_info;

-- R7 -- READ: Spaced Repetition (SM-2) due queue for a user in a target deck, prioritized by state and due date
SELECT 
    c.card_id,
    c.deck_id,
    c.front_prompt,
    c.back_solution,
    c.card_type,
    c.card_difficulty,
    COALESCE(cp.repetition_count, 0) AS repetition_count,
    COALESCE(cp.ease_factor, 2.50) AS ease_factor,
    COALESCE(cp.interval_days, 0) AS interval_days,
    COALESCE(cp.retention_state, 'NEW') AS retention_state,
    cp.next_review_due
FROM cards c
INNER JOIN decks d ON c.deck_id = d.deck_id
LEFT JOIN card_progress cp ON c.card_id = cp.card_id AND cp.user_id = '00000000-0000-0000-0000-000000000001'::uuid
WHERE c.deck_id = '00000000-0000-0000-0000-000000001001'::uuid
  AND (cp.next_review_due IS NULL OR cp.next_review_due <= CURRENT_TIMESTAMP)
ORDER BY 
    CASE 
        WHEN cp.retention_state = 'RELEARNING' THEN 1
        WHEN cp.retention_state = 'LEARNING' THEN 2
        WHEN cp.retention_state IS NULL OR cp.retention_state = 'NEW' THEN 3
        ELSE 4
    END,
    cp.next_review_due ASC NULLS FIRST,
    c.card_difficulty DESC
LIMIT 20;

-- R8 -- READ: Fetch flashcard details with all attached multimedia assets
SELECT 
    c.card_id,
    c.deck_id,
    d.deck_title,
    c.front_prompt,
    c.back_solution,
    c.card_type,
    c.card_difficulty,
    m.media_id,
    m.media_url,
    m.media_type,
    m.file_size_bytes
FROM cards c
INNER JOIN decks d ON c.deck_id = d.deck_id
LEFT JOIN card_media m ON c.card_id = m.card_id
WHERE c.card_id = '00000000-0000-0000-0000-000000002001'::uuid;

-- R9 -- READ: Chronological card review telemetry history and latency trend for a learner
SELECT 
    r.review_id,
    r.session_id,
    s.session_mode,
    c.card_id,
    c.front_prompt,
    r.rating,
    r.reaction_time_ms,
    r.is_correct,
    r.review_timestamp
FROM review_logs r
INNER JOIN study_sessions s ON r.session_id = s.session_id
INNER JOIN cards c ON r.card_id = c.card_id
WHERE s.user_id = '00000000-0000-0000-0000-000000000001'::uuid
  AND c.card_id = '00000000-0000-0000-0000-000000002001'::uuid
ORDER BY r.review_timestamp DESC
LIMIT 50;

-- R10 -- READ: Comprehensive study session performance report with duration, accuracy rate, and average latency
SELECT 
    s.session_id,
    s.user_id,
    d.deck_title,
    s.session_start,
    s.session_end,
    EXTRACT(EPOCH FROM (COALESCE(s.session_end, CURRENT_TIMESTAMP) - s.session_start))::INT AS session_duration_seconds,
    COUNT(r.review_id) AS total_reviews,
    COUNT(CASE WHEN r.is_correct = TRUE THEN 1 END) AS correct_reviews,
    ROUND(
        (COUNT(CASE WHEN r.is_correct = TRUE THEN 1 END)::NUMERIC / NULLIF(COUNT(r.review_id), 0)) * 100.0, 
        2
    ) AS accuracy_percentage,
    ROUND(AVG(r.reaction_time_ms), 0) AS avg_reaction_time_ms
FROM study_sessions s
INNER JOIN decks d ON s.deck_id = d.deck_id
LEFT JOIN review_logs r ON s.session_id = r.session_id
WHERE s.session_id = '00000000-0000-0000-0000-000000003001'::uuid
GROUP BY s.session_id, s.user_id, d.deck_title, s.session_start, s.session_end;

-- R11 -- READ: Global student leaderboard ranked by total earned XP and completed reviews
WITH xp_by_user AS (
    SELECT ua.user_id,
           SUM(a.xp_value) AS total_xp,
           COUNT(*) AS badges_unlocked
    FROM user_achievements ua
    INNER JOIN achievements a ON a.achievement_id = ua.achievement_id
    GROUP BY ua.user_id
), reviews_by_user AS (
    SELECT s.user_id,
           COUNT(r.review_id) AS total_cards_reviewed
    FROM study_sessions s
    INNER JOIN review_logs r ON r.session_id = s.session_id
    GROUP BY s.user_id
), leaderboard AS (
    SELECT u.user_id,
           u.username,
           p.first_name || ' ' || p.last_name AS full_name,
           COALESCE(x.total_xp, 0) AS total_xp,
           COALESCE(x.badges_unlocked, 0) AS badges_unlocked,
           COALESCE(rv.total_cards_reviewed, 0) AS total_cards_reviewed
    FROM users u
    INNER JOIN user_profiles p ON p.user_id = u.user_id
    LEFT JOIN xp_by_user x ON x.user_id = u.user_id
    LEFT JOIN reviews_by_user rv ON rv.user_id = u.user_id
    WHERE u.is_active = TRUE
)
SELECT DENSE_RANK() OVER (
           ORDER BY total_xp DESC, total_cards_reviewed DESC
       ) AS rank,
       user_id,
       username,
       full_name,
       total_xp,
       badges_unlocked,
       total_cards_reviewed
FROM leaderboard
ORDER BY rank ASC
LIMIT 25;

-- R12 -- READ: Fetch user unlocked achievements, tiers, XP values, and unlock timestamps
SELECT 
    a.achievement_id,
    a.badge_name,
    a.badge_slug,
    a.badge_tier,
    a.xp_value,
    a.criteria_description,
    ua.awarded_at
FROM user_achievements ua
INNER JOIN achievements a ON ua.achievement_id = a.achievement_id
WHERE ua.user_id = '00000000-0000-0000-0000-000000000001'::uuid
ORDER BY ua.awarded_at DESC;

-- R13 -- READ: Fetch locked achievements available for a learner to earn
SELECT 
    a.achievement_id,
    a.badge_name,
    a.badge_slug,
    a.badge_tier,
    a.xp_value,
    a.criteria_description
FROM achievements a
LEFT JOIN user_achievements ua 
    ON a.achievement_id = ua.achievement_id 
   AND ua.user_id = '00000000-0000-0000-0000-000000000001'::uuid
WHERE ua.user_achievement_id IS NULL
ORDER BY a.xp_value ASC;

-- R14 -- READ: Deck creator analytics measuring learner engagement, total reviews, and average rating
SELECT 
    d.deck_id,
    d.deck_title,
    t.topic_name,
    COUNT(DISTINCT s.user_id) AS unique_learners,
    COUNT(r.review_id) AS total_reviews_conducted,
    ROUND(AVG(r.rating), 2) AS average_review_rating,
    ROUND(AVG(r.reaction_time_ms), 0) AS average_reaction_time_ms
FROM decks d
INNER JOIN topics t ON d.topic_id = t.topic_id
LEFT JOIN study_sessions s ON d.deck_id = s.deck_id
LEFT JOIN review_logs r ON s.session_id = r.session_id
WHERE d.owner_user_id = '00000000-0000-0000-0000-000000000001'::uuid
GROUP BY d.deck_id, d.deck_title, t.topic_name
ORDER BY total_reviews_conducted DESC;

-- R15 -- READ: Security audit trail inspection with IP address, user agent, and action classification
SELECT 
    al.log_id,
    al.user_id,
    COALESCE(u.username, 'ANONYMOUS') AS username,
    al.action_type,
    al.target_entity,
    al.ip_address,
    al.user_agent,
    al.created_at
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.user_id
WHERE (al.user_id = '00000000-0000-0000-0000-000000000001'::uuid OR '00000000-0000-0000-0000-000000000001'::uuid IS NULL)
ORDER BY al.created_at DESC
LIMIT 50;


-- ============================================================================
-- PART 2: WRITE WORKLOADS (W1 – W15)
-- ============================================================================

-- W1 -- WRITE: Register a new user account without raising on any unique-key duplicate
INSERT INTO users (user_id, username, email, is_active, created_at)
VALUES (
    '00000000-0000-0000-0000-000000000003'::uuid, 
    'david_tennant', 
    'david.tennant@cognify.io', 
    TRUE, 
    CURRENT_TIMESTAMP
)
ON CONFLICT DO NOTHING;

-- W2 -- WRITE: Store secure password hash and salt for user credentials
INSERT INTO user_credentials (user_id, password_hash, salt, mfa_secret, password_last_changed)
VALUES (
    '00000000-0000-0000-0000-000000000002'::uuid,
    '$2b$12$e80yvI8mR1UqgYcO3v6hZeNlPq.aF7oM1uYxZ4g1p2w8r4t0a.5e2',
    'f3c9a1b4d8e20f17',
    NULL,
    CURRENT_TIMESTAMP
)
ON CONFLICT (user_id) DO UPDATE 
SET password_hash = EXCLUDED.password_hash,
    salt = EXCLUDED.salt,
    password_last_changed = CURRENT_TIMESTAMP;

-- W3 -- WRITE: Initialize or provision a user profile with timezone and daily study goal
INSERT INTO user_profiles (user_id, first_name, last_name, timezone, daily_goal_minutes, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000002'::uuid,
    'Clara',
    'Oswald',
    'America/New_York',
    25,
    CURRENT_TIMESTAMP
)
ON CONFLICT (user_id) DO UPDATE 
SET first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    timezone = EXCLUDED.timezone,
    daily_goal_minutes = EXCLUDED.daily_goal_minutes,
    updated_at = CURRENT_TIMESTAMP;

-- W4 -- WRITE: Record initial or updated cognitive baseline psychometric assessment
INSERT INTO cognitive_baselines (user_id, working_memory_capacity, processing_speed_ms, baseline_assessed_at)
VALUES (
    '00000000-0000-0000-0000-000000000002'::uuid,
    7.50,
    340,
    CURRENT_TIMESTAMP
)
ON CONFLICT (user_id) DO UPDATE 
SET working_memory_capacity = EXCLUDED.working_memory_capacity,
    processing_speed_ms = EXCLUDED.processing_speed_ms,
    baseline_assessed_at = CURRENT_TIMESTAMP;

-- W5 -- WRITE: Assign access role to a user
INSERT INTO user_roles (user_id, role_id, assigned_at)
VALUES (
    '00000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000000101'::uuid,
    CURRENT_TIMESTAMP
)
ON CONFLICT (user_id, role_id) DO NOTHING;

-- W6 -- WRITE: Create a new flashcard deck under a designated topic
INSERT INTO decks (deck_id, topic_id, owner_user_id, deck_title, deck_slug, deck_visibility, created_at)
VALUES (
    '00000000-0000-0000-0000-000000001002'::uuid,
    '00000000-0000-0000-0000-000000000501'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    'Distributed Systems Fundamentals',
    'distributed-systems-fundamentals',
    'PUBLIC',
    CURRENT_TIMESTAMP
)
ON CONFLICT (owner_user_id, deck_slug) DO UPDATE 
SET deck_title = EXCLUDED.deck_title,
    deck_visibility = EXCLUDED.deck_visibility;

-- W7 -- WRITE: Add a new flashcard item with prompt, solution, type, and difficulty
INSERT INTO cards (card_id, deck_id, front_prompt, back_solution, card_type, card_difficulty, created_at)
VALUES (
    '00000000-0000-0000-0000-000000002003'::uuid,
    '00000000-0000-0000-0000-000000001002'::uuid,
    'What guarantees does linearizability provide in distributed consensus?',
    'Linearizability provides strong recency guarantees: all operations appear to execute atomically at a specific point in time between invocation and response.',
    'STANDARD',
    4,
    CURRENT_TIMESTAMP
)
ON CONFLICT (card_id) DO NOTHING;

-- W8 -- WRITE: Attach media asset to flashcard
INSERT INTO card_media (media_id, card_id, media_url, media_type, file_size_bytes, uploaded_at)
VALUES (
    '00000000-0000-0000-0000-000000002502'::uuid,
    '00000000-0000-0000-0000-000000002002'::uuid,
    'https://assets.cognify.io/media/consensus_timeline.svg',
    'LATEX_SVG',
    45120,
    CURRENT_TIMESTAMP
);

-- W9 -- WRITE: Initialize and start a new study session
INSERT INTO study_sessions (session_id, user_id, deck_id, session_start, session_end, session_mode, device_info)
VALUES (
    '00000000-0000-0000-0000-000000003003'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000001002'::uuid,
    CURRENT_TIMESTAMP,
    NULL,
    'NORMAL',
    'macOS Chrome 130.0'
);

-- W10 -- WRITE: Log single card review event telemetry
INSERT INTO review_logs (review_id, session_id, card_id, rating, reaction_time_ms, is_correct, review_timestamp)
VALUES (
    '00000000-0000-0000-0000-000000004001'::uuid,
    '00000000-0000-0000-0000-000000003002'::uuid,
    '00000000-0000-0000-0000-000000002002'::uuid,
    4,
    1420,
    TRUE,
    CURRENT_TIMESTAMP
);

-- W11 -- WRITE: Upsert spaced repetition state (SM-2 Algorithm mutation)
INSERT INTO card_progress (
    progress_id, 
    user_id, 
    card_id, 
    repetition_count, 
    ease_factor, 
    interval_days, 
    next_review_due, 
    retention_state, 
    last_reviewed_at
)
VALUES (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000002002'::uuid,
    1,
    2.50,
    1,
    CURRENT_TIMESTAMP + INTERVAL '1 day',
    'LEARNING',
    CURRENT_TIMESTAMP
)
ON CONFLICT (user_id, card_id) DO UPDATE 
SET repetition_count = card_progress.repetition_count + 1,
    ease_factor = GREATEST(1.30, card_progress.ease_factor + (0.1 - (5 - 4) * (0.08 + (5 - 4) * 0.02))),
    interval_days = CASE 
        WHEN card_progress.repetition_count = 0 THEN 1 
        WHEN card_progress.repetition_count = 1 THEN 6 
        ELSE ROUND(card_progress.interval_days * card_progress.ease_factor)::INT 
    END,
    next_review_due = CURRENT_TIMESTAMP + (
        CASE 
            WHEN card_progress.repetition_count = 0 THEN INTERVAL '1 day'
            WHEN card_progress.repetition_count = 1 THEN INTERVAL '6 days'
            ELSE (ROUND(card_progress.interval_days * card_progress.ease_factor)::TEXT || ' days')::INTERVAL
        END
    ),
    retention_state = 'REVIEW',
    last_reviewed_at = CURRENT_TIMESTAMP;

-- W12 -- WRITE: Finalize study session run with end timestamp
UPDATE study_sessions
SET session_end = CURRENT_TIMESTAMP
WHERE session_id = '00000000-0000-0000-0000-000000003002'::uuid
  AND session_end IS NULL;

-- W13 -- WRITE: Award milestone badge / achievement unlock to a user
INSERT INTO user_achievements (user_achievement_id, user_id, achievement_id, awarded_at)
VALUES (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000005001'::uuid,
    CURRENT_TIMESTAMP
)
ON CONFLICT (user_id, achievement_id) DO NOTHING;

-- W14 -- WRITE: Update user profile details and adjust daily goal minutes
UPDATE user_profiles
SET timezone = 'Asia/Kolkata',
    daily_goal_minutes = 35,
    updated_at = CURRENT_TIMESTAMP
WHERE user_id = '00000000-0000-0000-0000-000000000002'::uuid;

-- W15 -- WRITE: Record security audit event log for sensitive operations
INSERT INTO audit_logs (log_id, user_id, action_type, target_entity, ip_address, user_agent, created_at)
VALUES (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000002'::uuid,
    'AUTH_PASSWORD_CHANGE',
    'user_credentials',
    '192.168.1.105'::inet,
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
    CURRENT_TIMESTAMP
);
