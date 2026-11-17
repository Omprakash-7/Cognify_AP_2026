-- ============================================================================
-- Advanced Programming (AP) — Database Management Systems (DBMS)
-- Project: Cognify — Adaptive Cognitive Training & Spaced-Repetition Platform
-- Team: T0004 · Section: D · Academic Year: 2026
-- Deliverable: Checkpoint 2 (CP2) — Relational Database Schema
-- File: dbms/03_schema.sql
-- Target DBMS: PostgreSQL 15+
-- ============================================================================

DROP SCHEMA IF EXISTS cognify CASCADE;
CREATE SCHEMA cognify;
SET search_path TO cognify, public;

-- Enable UUID generation support
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. IDENTITY & ACCESS MANAGEMENT (IAM)
-- ============================================================================

-- Table 1: users
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_username_format CHECK (username ~ '^[a-zA-Z0-9_\.\-]+$'),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Table 2: user_credentials
CREATE TABLE user_credentials (
    user_id UUID PRIMARY KEY,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(64) NOT NULL,
    mfa_secret VARCHAR(128) NULL,
    password_last_changed TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_credentials_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Table 3: roles
CREATE TABLE roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(50) NOT NULL UNIQUE,
    role_description TEXT NOT NULL
);

-- Table 4: user_roles
CREATE TABLE user_roles (
    user_id UUID NOT NULL,
    role_id UUID NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, role_id),

    CONSTRAINT fk_user_roles_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role_id 
        FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE RESTRICT
);

-- ============================================================================
-- 2. PROFILES & COGNITIVE BASELINES
-- ============================================================================

-- Table 5: user_profiles
CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    daily_goal_minutes SMALLINT NOT NULL DEFAULT 20,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_profiles_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_daily_goal_minutes 
        CHECK (daily_goal_minutes > 0)
);

-- Table 6: cognitive_baselines
CREATE TABLE cognitive_baselines (
    user_id UUID PRIMARY KEY,
    working_memory_capacity NUMERIC(4,2) NOT NULL,
    processing_speed_ms INT NOT NULL,
    baseline_assessed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_baselines_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_working_memory_capacity 
        CHECK (working_memory_capacity BETWEEN 1.0 AND 10.0),
    CONSTRAINT chk_processing_speed_ms 
        CHECK (processing_speed_ms > 0)
);

-- ============================================================================
-- 3. CONTENT TAXONOMY & FLASHCARD HIERARCHY
-- ============================================================================

-- Table 7: topics
CREATE TABLE topics (
    topic_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_name VARCHAR(100) NOT NULL,
    topic_slug VARCHAR(120) NOT NULL UNIQUE,
    topic_category VARCHAR(50) NOT NULL,
    description TEXT NULL
);

-- Table 8: decks
CREATE TABLE decks (
    deck_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    deck_title VARCHAR(150) NOT NULL,
    deck_slug VARCHAR(180) NOT NULL,
    deck_visibility VARCHAR(20) NOT NULL DEFAULT 'PRIVATE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_decks_topic_id 
        FOREIGN KEY (topic_id) REFERENCES topics(topic_id) ON DELETE RESTRICT,
    CONSTRAINT fk_decks_owner_id 
        FOREIGN KEY (owner_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT uq_deck_owner_slug 
        UNIQUE (owner_user_id, deck_slug),
    CONSTRAINT chk_deck_visibility 
        CHECK (deck_visibility IN ('PUBLIC', 'PRIVATE', 'SHARED'))
);

-- Table 9: cards
CREATE TABLE cards (
    card_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deck_id UUID NOT NULL,
    front_prompt TEXT NOT NULL,
    back_solution TEXT NOT NULL,
    card_type VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    card_difficulty SMALLINT NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cards_deck_id 
        FOREIGN KEY (deck_id) REFERENCES decks(deck_id) ON DELETE CASCADE,
    CONSTRAINT chk_card_type 
        CHECK (card_type IN ('STANDARD', 'CLOZE', 'TIMED_RECALL')),
    CONSTRAINT chk_card_difficulty 
        CHECK (card_difficulty BETWEEN 1 AND 5)
);

-- Table 10: card_media
CREATE TABLE card_media (
    media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL,
    media_url VARCHAR(500) NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    file_size_bytes INT NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_card_media_card_id 
        FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE,
    CONSTRAINT chk_media_type 
        CHECK (media_type IN ('IMAGE_PNG', 'IMAGE_JPEG', 'AUDIO_MP3', 'LATEX_SVG')),
    CONSTRAINT chk_media_file_size_positive 
        CHECK (file_size_bytes > 0)
);

-- ============================================================================
-- 4. ADAPTIVE LEARNING & SPACED REPETITION ENGINE (SM-2 / FSRS)
-- ============================================================================

-- Table 11: card_progress
CREATE TABLE card_progress (
    progress_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    card_id UUID NOT NULL,
    repetition_count INT NOT NULL DEFAULT 0,
    ease_factor NUMERIC(4,2) NOT NULL DEFAULT 2.50,
    interval_days INT NOT NULL DEFAULT 0,
    next_review_due TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    retention_state VARCHAR(20) NOT NULL DEFAULT 'NEW',
    last_reviewed_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_progress_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_progress_card_id 
        FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE,
    CONSTRAINT uq_user_card_progress 
        UNIQUE (user_id, card_id),
    CONSTRAINT chk_repetition_count 
        CHECK (repetition_count >= 0),
    CONSTRAINT chk_ease_factor 
        CHECK (ease_factor >= 1.30),
    CONSTRAINT chk_interval_days 
        CHECK (interval_days >= 0),
    CONSTRAINT chk_retention_state 
        CHECK (retention_state IN ('NEW', 'LEARNING', 'REVIEW', 'RELEARNING'))
);

-- ============================================================================
-- 5. STUDY SESSIONS & INTERACTION TELEMETRY
-- ============================================================================

-- Table 12: study_sessions
CREATE TABLE study_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    deck_id UUID NOT NULL,
    session_start TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_end TIMESTAMPTZ NULL,
    session_mode VARCHAR(30) NOT NULL DEFAULT 'NORMAL',
    device_info VARCHAR(100) NULL,

    CONSTRAINT fk_sessions_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_sessions_deck_id 
        FOREIGN KEY (deck_id) REFERENCES decks(deck_id) ON DELETE CASCADE,
    CONSTRAINT chk_session_mode 
        CHECK (session_mode IN ('NORMAL', 'CRAM', 'TIMED_DRILL')),
    CONSTRAINT chk_session_end 
        CHECK (session_end IS NULL OR session_end >= session_start)
);

-- Table 13: review_logs
CREATE TABLE review_logs (
    review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    card_id UUID NOT NULL,
    rating SMALLINT NOT NULL,
    reaction_time_ms INT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    review_timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reviews_session_id 
        FOREIGN KEY (session_id) REFERENCES study_sessions(session_id) ON DELETE CASCADE,
    CONSTRAINT fk_reviews_card_id 
        FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE,
    CONSTRAINT chk_rating 
        CHECK (rating BETWEEN 0 AND 5),
    CONSTRAINT chk_reaction_time_ms 
        CHECK (reaction_time_ms >= 0),
    CONSTRAINT uq_session_card_timestamp 
        UNIQUE (session_id, card_id, review_timestamp)
);

-- ============================================================================
-- 6. GAMIFICATION, BADGES & AUDIT LOGS
-- ============================================================================

-- Table 14: achievements
CREATE TABLE achievements (
    achievement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    badge_name VARCHAR(100) NOT NULL UNIQUE,
    badge_slug VARCHAR(120) NOT NULL UNIQUE,
    badge_tier VARCHAR(20) NOT NULL,
    xp_value INT NOT NULL,
    criteria_description TEXT NOT NULL,

    CONSTRAINT chk_badge_tier 
        CHECK (badge_tier IN ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM')),
    CONSTRAINT chk_xp_value 
        CHECK (xp_value > 0)
);

-- Table 15: user_achievements
CREATE TABLE user_achievements (
    user_achievement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    achievement_id UUID NOT NULL,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_user_achievements_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_achievements_achievement_id 
        FOREIGN KEY (achievement_id) REFERENCES achievements(achievement_id) ON DELETE RESTRICT,
    CONSTRAINT uq_user_achievement 
        UNIQUE (user_id, achievement_id)
);

-- Table 16: audit_logs
CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NULL,
    action_type VARCHAR(100) NOT NULL,
    target_entity VARCHAR(100) NOT NULL,
    ip_address INET NULL,
    user_agent TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_logs_user_id 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- ============================================================================
-- 7. OPERATIONAL INDEXES
-- ============================================================================

CREATE INDEX idx_decks_topic_id ON decks(topic_id);
CREATE INDEX idx_cards_deck_id ON cards(deck_id);
CREATE INDEX idx_card_progress_due_queue ON card_progress(user_id, next_review_due);
CREATE INDEX idx_review_logs_session_id ON review_logs(session_id);
CREATE INDEX idx_review_logs_card_id ON review_logs(card_id);
CREATE INDEX idx_audit_logs_user_timestamp ON audit_logs(user_id, created_at DESC);
