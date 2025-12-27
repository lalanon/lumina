# Lumina

**Lumina** is a CLI-first, offline-friendly ebook library organizer designed for large, messy collections.

It ingests unorganized ebook files, identifies them using deterministic hashing and optional AI-assisted metadata extraction, and organizes them into a clean, stable library structure based on a user-defined taxonomy.

Lumina is designed to be:
- safe (no silent data loss)
- auditable (every action logged)
- cost-aware (AI usage is explicit and estimated)
- replayable (taxonomy changes do not require re-identification)
- cross-platform (Linux, macOS, Windows)

---

## Core Concepts

Lumina is built around **three strictly separated phases**:

### 1. Ingest
- Discovers files in one or more source directories
- Ignores hidden files
- Filters supported formats (PDF, EPUB, MOBI, etc.)
- Computes a cryptographic hash (SHA-256) for each file
- Uses the hash as the **permanent identity**
- Stores provenance (original paths) in SQLite
- Is idempotent and safe to re-run
- Supports `--dry-run`

👉 Ingest never renames, moves, or modifies files.

---

### 2. Identify
- Operates on ingested hashes, not raw files
- Extracts metadata from file content (first N KB)
- Optionally uses AI models (Gemini, OpenAI, etc.)
- Uses **strict prompts and validation**
- Never invents taxonomy or tags
- Allows unknown values (no forced guessing)
- Tracks AI usage, token counts, and cost estimates
- Stores AI attempts and confidence scores
- Fully replayable and auditable

👉 Identify never touches the filesystem.

---

### 3. Organize
- Uses identified metadata and user rules
- Plans filesystem paths deterministically
- Renames and moves files transactionally:
  - copy → verify → delete → verify
- Resolves conflicts safely
- Supports dry-run
- Logs every operation
- Can rebuild the entire library after taxonomy changes

👉 Organize is the only phase that mutates the filesystem.

---

## Technology Stack

Lumina is implemented in **Racket 9.x**, using only the **standard Racket libraries** and SQLite.

- Language: **Racket 9**
- Runtime: Racket (no custom runtime, no FFI required)
- Libraries:
  - Standard Racket libraries (`racket/*`)
  - `db` (SQLite backend)
- Database: SQLite (single-file, portable, durable)

No non-standard Racket packages are required.

This design choice ensures:
- long-term stability
- easy installation
- reproducible builds
- excellent REPL-driven development
- portability across Linux, macOS, and Windows

---

## Database Design

Lumina uses SQLite as a durable system of record.

Key tables include:
- `files` – unique content hashes
- `file_sources` – provenance tracking
- `operations_log` – append-only audit trail
- `identified_works`, `identified_authors`, etc. – metadata
- `identify_attempts` – AI usage & cost tracking

All schema changes are idempotent and safe to re-run.

---

## AI Usage & Cost Control

AI usage is:
- optional
- explicit
- measurable
- estimated before execution

Lumina:
- estimates token usage before calling models
- supports multiple providers
- avoids repeated AI calls for the same content
- stores raw responses for audit and reuse

The goal is **zero surprise costs**.

---

## Philosophy

Lumina is intentionally:
- CLI-first
- boringly correct
- transparent
- resistant to hallucinations
- safe for irreplaceable libraries

It prefers *unknown* over *wrong*.

---

## Status

- Ingest: **implemented and stable**
- Identify: **designed**
- Organize: **designed**
- GUI: **planned (optional)**

---

## License

TBD
