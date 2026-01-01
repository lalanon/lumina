#lang racket
(require racket/cmdline
         racket/list
         racket/random
         racket/string
         racket/path
         racket/file
         json
         db
         "utils/sql.rkt"
         "utils/paths.rkt"
         "utils/ai_client_gemini.rkt"
         "utils/ai_config.rkt")

;; --------------------------------------------------
;; CLI
;; --------------------------------------------------

(define limit #f)
(define batch-size 5)
(define random? #f)
(define verbose? #f)

(command-line
 #:program "lumina identify"
 #:once-each
 [("--limit") n "Limit total files processed"
  (set! limit (string->number n))]
 [("--batch-size") n "Files per AI call"
  (set! batch-size (string->number n))]
 [("--random") "Randomize file order"
  (set! random? #t)]
 [("--verbose") "Verbose output"
  (set! verbose? #t)])

;; --------------------------------------------------
;; DB
;; --------------------------------------------------

(define conn (sqlite3-connect #:database "lumina.db"))
(execute-sql-file! conn "schemas/db/identify.sql")

;; --------------------------------------------------
;; Load candidates
;; --------------------------------------------------

(define rows
  (query-rows
   conn
   "SELECT f.hash,
           GROUP_CONCAT(fs.source_path)
    FROM files f
    JOIN file_sources fs ON fs.hash = f.hash
    JOIN document_classification dc ON dc.hash = f.hash
    WHERE f.hash NOT IN (
      SELECT hash FROM identified_metadata
    )
    GROUP BY f.hash"))

(define candidates
  (if random? (shuffle rows) rows))

(define selected
  (if limit
      (take candidates (min limit (length candidates)))
      candidates))

;; --------------------------------------------------
;; Prompts + vocabularies
;; --------------------------------------------------

(define system-prompt
  (file->string "prompts/identify_system.txt"))

(define user-template
  (file->string "prompts/identify_user.txt"))

(define taxonomy-json
  (call-with-input-file "config/taxonomy.json" read-json))

(define allowed-tags-json
  (call-with-input-file "config/allowed_tags.json" read-json))

(define api-key (get-api-key))

;; --------------------------------------------------
;; Helpers
;; --------------------------------------------------

(define (string-replace* str replacements)
  (for/fold ([s str])
            ([(k v) (in-hash replacements)])
    (string-replace s k v)))

(define (non-empty-string? v)
  (and (string? v) (not (string=? v ""))))

(define (confidence-ok? r)
  (let ([c (hash-ref r 'confidence #f)])
    (and (number? c) (>= c 0.40))))

(define (bibliographic-anchor-ok? r)
  (and (non-empty-string? (hash-ref r 'title #f))
       (or (non-empty-string? (hash-ref r 'author #f))
           (non-empty-string? (hash-ref r 'series #f)))))

(define (->sql v)
  (cond
    [(or (false? v) (eq? v 'null)) sql-null]
    [else v]))

;; --------------------------------------------------
;; Processing
;; --------------------------------------------------

(for ([row selected]
      [i (in-naturals)]
      #:when (or (not limit) (< i limit)))

  (match row
    [(vector file-hash paths-str)
     (define path
       (find-readable-path (string-split paths-str ",")))

     (cond
       [(not path)
        (when verbose?
          (printf "Skipping ~a: no readable paths\n" file-hash))]

       [else
        (define filename
          (path->string (file-name-from-path path)))

        (define snippet
          (read-snippet-from-path path #:bytes 65536))

        (when verbose?
          (printf "→ ~a (~a)\n" filename file-hash))

        (define user-prompt
          (string-replace*
           user-template
           (hash
            "{{HASH}}" file-hash
            "{{FILENAME}}" filename
            "{{SNIPPET}}" snippet
            "{{TAXONOMY_JSON}}" (jsexpr->string taxonomy-json)
            "{{ALLOWED_TAGS_JSON}}" (jsexpr->string allowed-tags-json))))

        (define results
          (gemini-classify-batch
           api-key
           system-prompt
           "schemas/ai/identify_output.schema.json"
           user-prompt))

        (define r (first results))
        (define status (hash-ref r 'status "reject"))

        (when verbose?
          (printf "  result: ~a → ~a (~a)\n"
                  file-hash
                  status
                  (hash-ref r 'confidence #f)))

        ;; -------- Option A: reject if title is null --------
        (define title-val (hash-ref r 'title #f))
        (when (and (member status '("identified" "partial"))
                   (confidence-ok? r)
                   (bibliographic-anchor-ok? r)
                   (non-empty-string? title-val))

          (define root-category
            (let ([v (hash-ref r 'root_category #f)])
              (if (or (false? v) (eq? v 'null)) "unknown" v)))

          (define second-category
            (let ([v (hash-ref r 'second_level_category #f)])
              (if (or (false? v) (eq? v 'null)) "unknown" v)))

          (query-exec
           conn
           "INSERT OR REPLACE INTO identified_metadata
              (hash, title, author, series, volume, language,
               root_category, second_level_category,
               confidence, reasoning, identified_at, model, token_cost)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?)"
           file-hash
           title-val
           (->sql (hash-ref r 'author #f))
           (->sql (hash-ref r 'series #f))
           (->sql (hash-ref r 'volume #f))
           (->sql (hash-ref r 'language #f))
           root-category
           second-category
           (->sql (hash-ref r 'confidence #f))
           (->sql (hash-ref r 'reasoning #f))
           (let ([v (hash-ref r 'model #f)])
             (if (or (false? v) (eq? v 'null))
                 "gemini-3-flash-preview"
                 v))
           (->sql (hash-ref r 'token_cost #f)))

          (let ([tags (hash-ref r 'tags '())])
            (when (list? tags)
              (for ([tag tags])
                (when (string? tag)
                  (query-exec
                   conn
                   "INSERT OR IGNORE INTO file_tags (hash, tag)
                    VALUES (?, ?)"
                   file-hash
                   tag))))))])]))

(disconnect conn)
