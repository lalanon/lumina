#lang racket
(require racket/cmdline
         racket/list
         racket/random
         racket/file
         racket/string
         json
         db
         "utils/sql.rkt"
         "utils/ai_config.rkt"
         "utils/ai_client_gemini.rkt"
         "utils/paths.rkt")

;; -------------------------------
;; CLI
;; -------------------------------

(define limit #f)
(define random? #f)
(define dry-run? #f)
(define batch-size 5)
(define verbose? #f)

(command-line
 #:program "lumina classify"
 #:once-each
 [("--limit") n "Limit documents" (set! limit (string->number n))]
 [("--random") "Random selection" (set! random? #t)]
 [("--dry-run") "No DB writes" (set! dry-run? #t)]
 [("--batch-size") n "Batch size" (set! batch-size (string->number n))]
 [("--verbose") "Verbose output" (set! verbose? #t)])

;; -------------------------------
;; DB
;; -------------------------------

(define conn (sqlite3-connect #:database "lumina.db"))

(execute-sql-file! conn "schemas/db/classification.sql")

;; -------------------------------
;; Load candidates
;; -------------------------------

;; NOTE:
;; We now fetch ALL known paths per hash using GROUP_CONCAT
;; instead of assuming a single reachable path.

(define rows
  (query-rows
   conn
   "SELECT f.hash,
           GROUP_CONCAT(fs.source_path),
           f.size_bytes
    FROM files f
    JOIN file_sources fs ON fs.hash = f.hash
    WHERE f.hash NOT IN (
      SELECT hash FROM document_classification
    )
    GROUP BY f.hash"))

(define candidates
  (if random?
      (shuffle rows)
      rows))

(define selected
  (if limit
      (take candidates (min limit (length candidates)))
      candidates))

;; --------------------------------
;; Insert classification result
;; --------------------------------

(define (insert-classification! conn file-hash document-type)
  (query-exec
   conn
   "INSERT OR REPLACE INTO document_classification
      (hash, document_type, confidence, classified_at, model, notes)
    VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?, ?)"
   file-hash
   document-type
   0.90                       ; default confidence for v1
   "gemini-3-flash-preview"
   "ai-classified"))

;; -------------------------------
;; Batching
;; -------------------------------

(define (chunk-list lst n)
  (if (null? lst)
      '()
      (cons (take lst (min n (length lst)))
            (chunk-list (drop lst (min n (length lst))) n))))

(define batches
  (chunk-list selected batch-size))

(define system-prompt
  (file->string "prompts/classify.system.txt"))

(define api-key (get-api-key))

;; -------------------------------
;; Classification
;; -------------------------------

(for ([batch batches])
  (when verbose?
    (printf "Classifying batch of ~a documents...\n" (length batch)))

  (define docs
    (filter
     values
     (for/list ([row batch])
       (match row
         [(vector file-hash paths-str size)
          (define paths (string-split paths-str ","))
          (define path (find-readable-path paths))

          (when (and (not path) verbose?)
            (printf "Skipping ~a: no readable paths\n" file-hash))

          (and path
               (hash
                'hash file-hash
                'filename (path->string (file-name-from-path path))
                'size_bytes size
                'snippet (read-snippet-from-path path)))]))))

  (define payload
    (hash 'documents docs))

  (when (and (not dry-run?) (not (null? docs)))
    (let ([ai-result
           (gemini-classify-batch
            api-key
            system-prompt
            "schemas/ai/classification.schema.json"
            payload)])
      (when verbose?
        (printf "AI result:\n~a\n\n" ai-result))

      ;; Persist results
      (for ([entry ai-result])
        (define file-hash (hash-ref entry 'hash))
        (define doc-type
          (let ([v (hash-ref entry 'classification)])
            (if (symbol? v) (symbol->string v) v)))

        (when (not dry-run?)
          (insert-classification!
           conn
           file-hash
           doc-type))))))

;; --------------------------------
;; Classification summary
;; --------------------------------

(define (print-classification-summary conn)
  (define rows
    (query-rows
     conn
     "SELECT document_type, COUNT(*)
      FROM document_classification
      GROUP BY document_type"))

  (printf "\nClassification summary:\n")
  (for ([row rows])
    (match row
      [(vector doc-type count)
       (printf "  ~a: ~a\n" doc-type count)])))

(when (not dry-run?)
  (print-classification-summary conn))

(disconnect conn)
