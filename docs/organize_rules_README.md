# 📁 Lumina `organize_rules.json`
### User Guide & Examples

---

## What is `organize_rules.json`?

`organize_rules.json` controls **how Lumina organizes files on disk** during the **Organize phase**.

It defines:

- folder structure
- filename formats
- how series are handled
- language subfolders
- format preferences
- conflict resolution
- user-specific overrides

It is **fully customizable**, validated against a strict JSON Schema, and safe to edit.

> **Important:**  
> Organize rules affect **filesystem layout only**.  
> They do **not** change metadata or identification.

---

## Core Principles

- Identify decides **what a book is**
- Organize decides **where it goes**
- Rules are applied **deterministically**
- No files are overwritten silently
- Dry-run shows exactly what will happen
- You can reorganize your entire library at any time

---

## Minimal Example

A very simple rule set:

```json
{
  "version": "1.0",
  "library_root": "/Library",

  "path_templates": {
    "default": "{root}/{taxonomy_path}/{author}/{title}"
  },

  "filename_templates": {
    "default": "{title} - {author}"
  },

  "normalization": {
    "replace_unsafe_chars": "_"
  },

  "conflict_resolution": {
    "on_path_exists": "compare_hash",
    "on_same_hash": "skip",
    "on_different_hash": "suffix"
  }
}
```

---

## Path Templates

Path templates define **folder layout**.

### Available placeholders

| Placeholder | Meaning |
|-----------|--------|
| `{root}` | Library root |
| `{taxonomy_path}` | Full taxonomy path |
| `{taxonomy_rest}` | Taxonomy path minus first level |
| `{author}` | Primary author |
| `{series}` | Series name |
| `{title}` | Work title |

---

## Subject Overrides  
### Example: Music as a Top-Level Folder

```json
{
  "match": { "taxonomy_prefix": "Music" },
  "path_template": "{root}/Music/{taxonomy_rest}/{author}/{title}"
}
```

---

## Series Rules

### Fiction: group series together

```json
{
  "match": {
    "work_type": "book",
    "taxonomy_prefix": "Literature (Fiction)"
  },
  "behavior": "group_by_series"
}
```

### Non-Fiction: ignore publisher series (For Dummies)

```json
{
  "match": {
    "series_name_contains": "For Dummies"
  },
  "behavior": "ignore_series"
}
```

---

## Programming Books Exception

```json
{
  "match": {
    "taxonomy_prefix": "Computers/Programming"
  },
  "behavior": "ignore_series"
}
```

---

## Language Rules

```json
"language_rules": {
  "primary_language": "en",
  "secondary_language_subdir": true
}
```

---

## Format Rules

```json
"format_rules": {
  "preferred_order": ["epub", "pdf", "mobi"],
  "keep_multiple": ["epub", "pdf"]
}
```

---

## Normalization Rules

```json
"normalization": {
  "unicode": "NFC",
  "replace_unsafe_chars": "_",
  "collapse_whitespace": true,
  "max_path_length": 240
}
```

---

## Conflict Resolution

```json
"conflict_resolution": {
  "on_path_exists": "compare_hash",
  "on_same_hash": "skip",
  "on_different_hash": "suffix",
  "suffix_format": " ({n})"
}
```

---

## Dry-Run (Always Use First)

```bash
lumina organize --dry-run
```

---

## Rebuilding the Library

```bash
lumina organize --rebuild
```

---

**Lumina favors correctness over cleverness.**
