organized_files (
  hash TEXT PRIMARY KEY,
  library_path TEXT NOT NULL,
  filename TEXT NOT NULL,
  organized_at TEXT NOT NULL,
  rule_applied TEXT
);

