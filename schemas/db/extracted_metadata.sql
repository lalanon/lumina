-- =========================================================
-- Extracted (local) metadata
-- This table stores metadata extracted WITHOUT AI
-- =========================================================

CREATE TABLE IF NOT EXISTS extracted_metadata (
    hash TEXT PRIMARY KEY,

    -- Basic format info
    format TEXT NOT NULL,                 -- epub | pdf | comic | etc.
    source TEXT NOT NULL,                 -- opf | pdfinfo | filename

    -- Bibliographic fields (best-effort)
    title TEXT,
    author TEXT,
    series TEXT,
    volume TEXT,
    language TEXT,
    publisher TEXT,
    isbn TEXT,

    -- Content / structure
    page_count INTEGER,
    is_periodical INTEGER DEFAULT 0,      -- 0/1 boolean

    -- Quality signal for downstream AI
    confidence_hint REAL NOT NULL DEFAULT 0.0,

    -- Audit
    extracted_at TEXT NOT NULL
        DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
);

-- =========================================================
-- Indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_extracted_metadata_format
    ON extracted_metadata (format);

CREATE INDEX IF NOT EXISTS idx_extracted_metadata_title
    ON extracted_metadata (title);

CREATE INDEX IF NOT EXISTS idx_extracted_metadata_author
    ON extracted_metadata (author);
