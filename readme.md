# Lumina

Lumina is a **CLI-first ebook library organizer** designed to turn chaotic ebook collections into a coherent, searchable, and durable personal library.

It does **not** trust filenames, folder names, or ad-hoc metadata. Instead, Lumina identifies files by **content hash**, incrementally enriches metadata (optionally with AI assistance), and projects a **user-defined taxonomy** onto a clean, cross-platform filesystem layout.

Lumina is built for **correctness, auditability, and long-term curation**, not for one-click magic.

---

## Core Principles

- **Content over filenames**  
  Filenames are treated as untrusted input. File identity is based on content hashing.

- **Incremental enrichment**  
  Files may start completely unidentified. Metadata is added progressively and can be revised.

- **Controlled vocabularies**  
  Genres, topics, and tags come from explicit JSON taxonomies, not AI hallucinations.

- **Filesystem as a projection**  
  The directory structure is a derived view and can be rebuilt at any time.

- **Safety first**  
  No destructive operations without dry-runs. File moves are transactional and verifiable.

- **CLI-first**  
  The command line is the primary interface. A GUI may come later.

---

## What Lumina Does

- Ingests ebook files (PDF, EPUB, MOBI, etc.) without modifying them
- Computes stable content hashes to identify files across renames and moves
- Tracks provenance and duplicate files safely
- Uses AI-assisted analysis (optional) to identify titles, authors, language, and topics
- Applies a user-defined taxonomy to organize books by subject
- Handles multiple formats, languages, and editions of the same work
- Reorganizes the library automatically when the taxonomy changes
- Provides fast, scriptable search over the curated library

---

## What Lumina Does *Not* Do

- It does not assume filenames are correct
- It does not silently guess metadata
- It does not require a GUI
- It does not lock you into a proprietary database format
- It does not destroy files without explicit confirmation

---

## Project Status

🚧 **Early development**

Current focus:
- CLI ingest pipeline
- Filesystem discovery
- Content hashing
- Safe, idempotent database integration

AI integration, classification, and filesystem projection are planned next.

---

## Technology

- **Language:** Racket
- **Interface:** Command Line (CLI)
- **Database:** SQLite
- **Metadata & taxonomy:** JSON + JSON Schema
- **Platforms:** Linux, macOS, Windows

---

## Example Workflow (planned)

```text
lumina ingest ~/Downloads/ebooks
lumina identify
lumina classify
lumina organize --library-root ~/Library
lumina search "knitting beginner"
