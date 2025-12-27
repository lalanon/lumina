CREATE TABLE IF NOT EXISTS document_classification (
  hash TEXT PRIMARY KEY,
  document_type TEXT NOT NULL CHECK (
    document_type IN ('book','magazine','comic','non-book')
  ),
  confidence REAL NOT NULL,
  classified_at TEXT NOT NULL,
  model TEXT NOT NULL,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_document_classification_type
  ON document_classification(document_type);
