#lang racket

(require racket/string
         racket/file
         db)

(provide execute-sql-file!)

;; --------------------------------------------------
;; Execute all SQL statements from a file.
;;
;; - Statements are separated by semicolons.
;; - Empty statements are ignored.
;; - Designed for SQLite + Racket (query-exec limitation).
;; - SQL files must be idempotent (CREATE IF NOT EXISTS).
;; --------------------------------------------------

(define (execute-sql-file! conn path)
  (define sql
    (call-with-input-file path
      (lambda (in)
        (port->string in))
      #:mode 'text))

  (for ([stmt (in-list (string-split sql ";"))])
    (define trimmed (string-trim stmt))
    (unless (string=? trimmed "")
      (query-exec conn trimmed))))