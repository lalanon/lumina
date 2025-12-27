-- Speed up document type filtering (book vs non-book)
CREATE INDEX IF NOT EXISTS idx_document_classification_type
  ON document_classification(document_type);

-- Speed up confidence threshold checks
CREATE INDEX IF NOT EXISTS idx_document_classification_confidence
  ON document_classification(confidence);

-- Speed up reprocessing and auditing
CREATE INDEX IF NOT EXISTS idx_document_classification_method
  ON document_classification(method);

-- Speed up time-based operations (reclassification, audits)
CREATE INDEX IF NOT EXISTS idx_document_classification_classified_at
  ON document_classification(classified_at);

