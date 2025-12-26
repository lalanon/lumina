#lang racket
(require racket/cmdline
        racket/path
        racket/file
        racket/list
        racket/string)

(struct discovered-file (path size extension)
  #:transparent)

(struct hashed-file (hash algo size format path)
  #:transparent)

(struct ingest-outcome (hash status message)
  #:transparent)

(struct ingest-config (paths
                       recursive?
                       follow-symlinks?
                       dry-run?
                       db-path
                       verbose?
                       json?)
  #:transparent)

(define (parse-ingest-args)
  (define paths '())
  (define recursive? #t)
  (define follow-symlinks? #f)
  (define dry-run? #f)
  (define db-path "lumina.db")
  (define verbose? #f)
  (define json? #f)

  (command-line
   #:program "lumina ingest"
   #:once-each
   [("--no-recursive") "Do not recurse into directories"
    (set! recursive? #f)]
   [("--follow-symlinks") "Follow symbolic links"
    (set! follow-symlinks? #t)]
   [("--dry-run") "Do not write to the database"
    (set! dry-run? #t)]
   [("--db") path "Path to SQLite database"
    (set! db-path path)]
   [("--verbose") "Verbose output"
    (set! verbose? #t)]
   [("--json") "JSON output"
    (set! json? #t)]
   #:args input-paths
   (set! paths input-paths))

  (ingest-config paths
                 recursive?
                 follow-symlinks?
                 dry-run?
                 db-path
                 verbose?
                 json?))

(define (normalize-input-path p)
  (simplify-path (path->complete-path p)))

(define (run-ingest config)
  (define input-paths
    (map normalize-input-path
         (ingest-config-paths config)))

  (define discovered
    (discover-files input-paths
                    (ingest-config-recursive? config)
                    (ingest-config-follow-symlinks? config)))

  (define candidates
    (filter-candidates discovered))

  (define hashed
    (hash-files candidates))

  (define outcomes
    (process-ingest hashed config))

  (report-outcomes outcomes config))

(define (discover-files paths recursive? follow-symlinks?)
  ;; TODO: walk filesystem, ignore hidden files
  '())

(define (filter-candidates discovered)
  ;; TODO: filter by extension, size
  discovered)

(define (hash-files candidates)
  ;; TODO: stream SHA-256 hashes
  '())

(define (process-ingest hashed-files config)
  ;; TODO: read/write DB unless dry-run
  '())

(define (report-outcomes outcomes config)
  ;; TODO: print summary / JSON
  (void))

(define (hidden-path? p)
  (define name (path->string (file-name-from-path p)))
  (and name
       (positive? (string-length name))
       (char=? (string-ref name 0) #\.)))



(module+ main
  (define config (parse-ingest-args))
  (run-ingest config))
