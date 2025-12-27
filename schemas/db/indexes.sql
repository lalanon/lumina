CREATE INDEX IF NOT EXISTS idx_file_sources_hash
  ON file_sources(hash);

CREATE INDEX IF NOT EXISTS idx_file_sources_source_path
  ON file_sources(source_path);

CREATE INDEX IF NOT EXISTS idx_files_format
  ON files(format);

CREATE INDEX IF NOT EXISTS idx_operations_log_file_hash
  ON operations_log(file_hash);

CREATE INDEX IF NOT EXISTS idx_operations_log_phase
  ON operations_log(phase);

