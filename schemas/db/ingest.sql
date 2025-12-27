CREATE TABLE IF NOT EXISTS files (
  hash TEXT PRIMARY KEY,
  hash_algo TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  format TEXT NOT NULL,
  ingested_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS file_sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hash TEXT NOT NULL,
  source_path TEXT NOT NULL,
  original_filename TEXT,
  seen_at TEXT NOT NULL,
  FOREIGN KEY (hash) REFERENCES files(hash)
);

CREATE TABLE IF NOT EXISTS operations_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  occurred_at TEXT NOT NULL,
  phase TEXT NOT NULL,
  operation TEXT NOT NULL,
  file_hash TEXT,
  details TEXT,
  FOREIGN KEY (file_hash) REFERENCES files(hash)
);

