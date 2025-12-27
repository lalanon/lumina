#lang racket

(require racket/cmdline
         db
         "utils/sql.rkt")

;; --------------------------------------------------
;; Configuration
;; --------------------------------------------------

(struct classify-config (db-path dry-run? verbose?)
  #:transparent)

(define (parse-classify-args)
  (define db-path "lumina.db")
  (define dry-run? #f)
  (define verbose? #f)

  (command-line
   #:program "lumina classify"
   #:once-each
   [("--db") path "Path to SQLite database"
    (set! db-path path)]
   [("--dry-run") "Do not write classification results"
    (set! dry-run? #t)]
   [("--verbose") "Verbose output"
    (set! verbose? #t)])

  (classify-config db-path dry-run? verbose?))

;; --------------------------------------------------
;; Database
;; --------------------------------------------------

(define (open-db db-path)
  (sqlite3-connect #:database db-path
                   #:mode 'create))

;; --------------------------------------------------
;; Main classify entry point
;; --------------------------------------------------

(define (run-classify config)
  (define conn (open-db (classify-config-db-path config)))

  ;; Ensure classification schema exists
  (execute-sql-file! conn "schemas/db/classification.sql")

  (when (classify-config-verbose? config)
    (printf "Classification schema initialized.\n"))

  ;; Placeholder: real classification logic goes here

  (disconnect conn)

  (when (classify-config-verbose? config)
    (printf "Classification finished.\n")))

;; --------------------------------------------------
;; Program entry
;; --------------------------------------------------

(module+ main
  (define config (parse-classify-args))
  (run-classify config))
