# Lumina – TODO

This document tracks planned work based on current architecture decisions.

---

## ✅ Completed

### Ingest Phase
- [x] Recursive file discovery
- [x] Hidden file filtering
- [x] Extension filtering
- [x] SHA-256 hashing (streaming)
- [x] SQLite persistence
- [x] Idempotent ingest
- [x] Dry-run support
- [x] Duplicate detection
- [x] Provenance tracking (`file_sources`)
- [x] Audit logging (`operations_log`)
- [x] Database indexes
- [x] Path normalization (`~` expansion)
- [x] CLI validation and REPL testing

---

## 🟡 In Progress / Designed

### Identify Phase (No Code Yet)
- [ ] Create identify DB schema
- [ ] Create AI model pricing table
- [ ] Implement cost estimation logic
- [ ] Implement identify attempt tracking
- [ ] Implement strict prompt contract
- [ ] Implement JSON validation rules
- [ ] Implement confidence scoring
- [ ] Implement identify CLI command
- [ ] Support re-identification
- [ ] Support heuristic-only identification

---

### Organize Phase (No Code Yet)
- [ ] Design `organize_rules.json`
- [ ] Implement path planning
- [ ] Implement filename normalization
- [ ] Implement conflict detection
- [ ] Implement transactional file moves
- [ ] Implement rollback logic
- [ ] Update DB after successful moves
- [ ] Integrate organize audit logging
- [ ] Implement organize CLI command
- [ ] Support rebuild after taxonomy changes
- [ ] Generate user manual for `organize_rules.json` (rules, precedence, examples)

---

## 🔵 Future Enhancements

### Quality & UX
- [ ] `--verbose` per-file output
- [ ] Progress indicators
- [ ] Summary reports (JSON output)
- [ ] Manual override support
- [ ] Confidence-based review queue

### Performance
- [ ] Parallel hashing (optional)
- [ ] Batch AI requests
- [ ] Large-library optimizations (100k+ files)

### Metadata & Formats
- [ ] PDF quality analysis (scan vs original)
- [ ] Multi-language handling
- [ ] Magazine / comic specialization
- [ ] ISBN / DOI extraction
- [ ] Series detection improvements

### Tooling
- [ ] Tests for ingest
- [ ] Tests for identify
- [ ] Tests for organize
- [ ] Schema migration tooling
- [ ] Backup / restore commands

---

## 🧠 Design Constraints (Do Not Violate)

- Ingest never mutates files
- Identify never mutates files
- Organize is transactional
- AI usage must be measurable
- Unknown is better than wrong
- No silent overwrites
- Everything must be replayable

---
