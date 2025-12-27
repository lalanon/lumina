CREATE TABLE IF NOT EXISTS document_classification (
  hash TEXT PRIMARY KEY,

  -- High-level document kind
  document_type TEXT NOT NULL
    CHECK (document_type IN ('book', 'magazine', 'comic', 'non-book')),

  -- Optional refinement for non-book or edge cases
  subtype TEXT,

  -- AI or heuristic confidence (0.0 – 1.0)
  confidence REAL NOT NULL
    CHECK (confidence >= 0.0 AND confidence <= 1.0),

  -- How this classification was produced
  method TEXT NOT NULL
    CHECK (method IN ('heuristic', 'ai', 'manual')),

  -- Timestamp of classification
  classified_at TEXT NOT NULL,

  -- Optional explanation or notes
  notes TEXT
);

