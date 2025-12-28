PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS document_classification (
  hash TEXT PRIMARY KEY,

  document_type TEXT NOT NULL CHECK (
    document_type IN ('book','magazine','comic','non-book')
  ),

  confidence REAL NOT NULL CHECK (
    confidence >= 0.0 AND confidence <= 1.0
  ),

  classified_at TEXT NOT NULL,
  model TEXT NOT NULL,
  notes TEXT,

  FOREIGN KEY (hash) REFERENCES files(hash)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_document_classification_type
  ON document_classification(document_type);

CREATE INDEX IF NOT EXISTS idx_document_classification_confidence
  ON document_classification(confidence);

