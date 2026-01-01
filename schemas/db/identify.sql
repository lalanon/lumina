CREATE TABLE IF NOT EXISTS identified_metadata (
  hash TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  author TEXT,
  series TEXT,
  volume TEXT,
  language TEXT,
  root_category TEXT NOT NULL,
  second_level_category TEXT NOT NULL,
  confidence REAL NOT NULL,
  reasoning TEXT,
  identified_at TEXT NOT NULL,
  model TEXT NOT NULL,
  token_cost INTEGER
);

CREATE TABLE IF NOT EXISTS file_tags (
  hash TEXT NOT NULL,
  tag TEXT NOT NULL,
  PRIMARY KEY (hash, tag)
);
