#lang racket

(require racket/cmdline
         racket/list
         racket/string
         racket/file
         racket/path
         json
         db
         "utils/sql.rkt"
         "utils/paths.rkt"
         "utils/ai_config.rkt"
         "utils/ai_client_gemini.rkt")

;; --------------------------------
;; CLI options
;; --------------------------------

(define limit #f)
(define verbose? #f)
(define dry-run? #f)

(command-line
 #:program "lumina extract"
 #:once-each
 [("--limit") n "Limit number of files" (set! limit (string->number n))]
 [("--verbose") "Verbose output" (set! verbose? #t)]
 [("--dry-run") "Do not write to DB" (set! dry-run? #t)])

;; --------------------------------
;; DB connection
;; --------------------------------

(define conn (sqlite3-connect #:database "lumina.db"))

(execute-sql-file! conn "schemas/db/extracted_metadata.sql")

;; --------------------------------
;; Candidate selection
;; EXACTLY matches classify / identify logic
;; --------------------------------

(define rows
  (query-rows
   conn
   "
   SELECT f.hash, fs.source_path, f.size_bytes
   FROM files f
   JOIN file_sources fs ON fs.hash = f.hash
   WHERE f.hash NOT IN (
     SELECT hash FROM document_classification
   )
   GROUP BY f.hash
   "))

(define candidates
  (if limit
      (take rows (min limit (length rows)))
      rows))

;; --------------------------------
;; Helpers
;; --------------------------------

(define (log fmt . args)
  (when verbose?
    (apply printf fmt args)))

(define (safe-string v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [(eq? v 'null) #f]
    [else #f]))

(define (extension path)
  (define ext (path-get-extension path))
  (and ext (string-downcase (bytes->string/utf-8 ext))))

;; --------------------------------
;; Local metadata extraction (v1)
;; --------------------------------

(define (extract-local path)
  ;; very conservative v1 extraction
  ;; filename-based only, zero AI
  (define name (path->string (file-name-from-path path)))
  (hash
   'title name
   'author #f
   'language #f))

;; --------------------------------
;; Classification + metadata via AI
;; --------------------------------

(define api-key (get-api-key))
(define system-prompt (file->string "prompts/identify_system.txt"))

(for ([row candidates])
  (match row
  [(vector file-hash source-path _)
   (define path (find-readable-path (list source-path)))

     (if (not path)
         (log "Skipping ~a: no readable paths\n" file-hash)
         (let* ([local (extract-local path)]
                [payload
                 (hash
                  'hash file-hash
                  'filename (path->string (file-name-from-path path))
                  'local_metadata local)]
                [ai-result
                 (gemini-classify-batch
                  api-key
                  system-prompt
                  "schemas/ai/identify_output.schema.json"
                  (hash 'documents (list payload)))]
                [result (first ai-result)]
                [confidence (hash-ref result 'confidence 0.0)]
                [title (safe-string (hash-ref result 'title #f))])

           (log "→ ~a (~a)\n"
                (path->string (file-name-from-path path))
                file-hash)

           (cond
             [(not title)
              (log "  result: ~a → reject (no title)\n" file-hash)]

             [(< confidence 0.4)
              (log "  result: ~a → reject (~a)\n" file-hash confidence)]

             [else
              (log "  result: ~a → identified (~a)\n" file-hash confidence)

              (unless dry-run?
                (query-exec
                 conn
                 "
                 INSERT OR REPLACE INTO document_classification
                   (hash, document_type, confidence, classified_at, model, notes)
                 VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?, ?)
                 "
                 file-hash
                 (safe-string (hash-ref result 'work_type "book"))
                 confidence
                 (safe-string (hash-ref result 'model "unknown"))
                 "extracted"))])))]))

(disconnect conn)
