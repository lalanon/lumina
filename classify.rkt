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
         "utils/ai_client_gemini.rkt")

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

(define rows
  (query-rows conn
              "SELECT f.hash, fs.source_path, f.size_bytes
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

;; -------------------------------
;; Snippet extraction
;; -------------------------------

(define (read-snippet path)
  (with-handlers ([exn:fail? (λ (_) "")])
    (call-with-input-file path
      (λ (in)
        (bytes->string/utf-8
         (read-bytes 4096 in)))
      #:mode 'binary)))

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

(for ([batch batches])
  (when verbose?
    (printf "Classifying batch of ~a\n" (length batch)))

  (define docs
    (for/list ([row batch])
      (match row
        [(vector file-hash path size)
         (hash
          'hash file-hash
          'filename (path->string (file-name-from-path path))
          'size_bytes size
          'snippet (read-snippet path))])))

  (define payload
    (hash 'documents docs))

  (when (not dry-run?)
    (let ([ai-result
       (gemini-classify-batch
        api-key
        system-prompt
        "schemas/ai/classification.schema.json"
        payload)])
  (when verbose?
    (printf "AI result:\n~a\n\n" ai-result)))))

    (disconnect conn)
    