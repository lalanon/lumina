CREATE TABLE IF NOT EXISTS identify_attempts (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,

    -- What we attempted to identify
    hash                TEXT NOT NULL,
    format              TEXT NOT NULL,

    -- Evidence description (human-readable, compact)
    evidence_summary    TEXT NOT NULL,

    -- Snippet metadata (important!)
    snippet_bytes       INTEGER NOT NULL,
    snippet_format      TEXT NOT NULL,
    snippet_warning     TEXT NOT NULL,
    -- e.g.:
    -- "Partial file header only. Not a complete document.
    --  Treat as raw EPUB/PDF data. Do not assume completeness."

    -- AI / heuristic metadata
    method              TEXT NOT NULL,
    -- 'ai', 'heuristic', 'manual'

    model               TEXT,
    model_version       TEXT,

    -- Cost & token accounting
    prompt_tokens       INTEGER,
    completion_tokens   INTEGER,
    estimated_cost      REAL,
    actual_cost         REAL,
    currency            TEXT DEFAULT 'USD',

    -- Attempt result
    status              TEXT NOT NULL,
    -- 'success', 'failed', 'invalid', 'rejected', 'cost_exceeded'

    error_message       TEXT,

    -- Raw AI output (for audit/debug/replay)
    raw_response        TEXT,

    created_at          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (hash) REFERENCES files(hash)
);

CREATE TABLE IF NOT EXISTS identified_works (
    hash            TEXT PRIMARY KEY,

    title           TEXT NOT NULL,
    language        TEXT,
    work_type       TEXT NOT NULL,
    -- 'book', 'magazine', 'comic'

    confidence      REAL NOT NULL,
    status          TEXT NOT NULL,
    -- 'accepted', 'tentative', 'rejected'

    source_attempt  INTEGER NOT NULL,

    updated_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (hash) REFERENCES files(hash),
    FOREIGN KEY (source_attempt) REFERENCES identify_attempts(id)
);

CREATE TABLE IF NOT EXISTS identified_authors (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    hash            TEXT NOT NULL,

    name            TEXT NOT NULL,
    role            TEXT DEFAULT 'author',
    -- 'author', 'editor', 'translator'

    position        INTEGER,
    -- author order if relevant

    FOREIGN KEY (hash) REFERENCES identified_works(hash)
);

CREATE TABLE IF NOT EXISTS identified_series (
    hash            TEXT PRIMARY KEY,

    series_name     TEXT NOT NULL,
    volume          TEXT,
    volume_index    INTEGER,

    FOREIGN KEY (hash) REFERENCES identified_works(hash)
);

CREATE TABLE IF NOT EXISTS identified_tags (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    hash            TEXT NOT NULL,

    tag             TEXT NOT NULL,
    -- e.g. "genre:fantasy"

    FOREIGN KEY (hash) REFERENCES identified_works(hash)
);

CREATE INDEX IF NOT EXISTS idx_identify_attempts_hash
    ON identify_attempts(hash);

CREATE INDEX IF NOT EXISTS idx_identify_attempts_status
    ON identify_attempts(status);

CREATE INDEX IF NOT EXISTS idx_identified_works_status
    ON identified_works(status);

CREATE INDEX IF NOT EXISTS idx_identified_subjects_taxonomy
    ON identified_subjects(taxonomy_path);

CREATE INDEX IF NOT EXISTS idx_identified_tags_tag
    ON identified_tags(tag);

