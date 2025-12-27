#lang racket
(require racket/cmdline
        racket/path
        racket/file
        racket/list
        racket/string
        file/sha1
        db)

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

(define (expand-user-path p)
  (cond
    [(and (string? p)
          (regexp-match? #rx"^~(/|$)" p))
     (build-path (find-system-path 'home-dir)
                 (substring p 2))]
    [else p]))

(define (normalize-input-path p)
  (define expanded (expand-user-path p))
  (simplify-path
   (path->complete-path expanded)))


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

(define (file-extension p)
  (define s (path->string p))
  (define parts (string-split s "."))
  (cond
    [(< (length parts) 2) ""]
    [else (string-downcase (last parts))]))


(define (discover-files paths recursive? follow-symlinks?)
  (define results '())

  (define (visit-path p)
    (cond
      ;; Ignore hidden files/directories
      [(hidden-path? p)
       (void)]

      ;; Regular file
      [(file-exists? p)
       (define size (file-size p))
       (define ext (file-extension p))
       (set! results
             (cons (discovered-file p size ext)
                   results))]

      ;; Directory
      [(directory-exists? p)
       (when recursive?
         (for ([child (in-list (directory-list p))])
           (visit-path (build-path p child))))]

      ;; Everything else (symlink, socket, etc.)
      [else
       (void)]))

  ;; Entry point
  (for ([p (in-list paths)])
    (visit-path p))

  (reverse results))

(define allowed-extensions
  '("pdf" "epub" "mobi" "azw" "azw3" "djvu" "cbz" "cbr"))

(define (allowed-extension? ext)
  (member ext allowed-extensions))


(define (filter-candidates discovered)
  (define results '())

  (for ([df (in-list discovered)])
    (define ext (discovered-file-extension df))
    (define size (discovered-file-size df))

    (cond
      ;; Reject zero-byte files
      [(zero? size)
       (void)]

      ;; Reject unknown extensions
      [(not (allowed-extension? ext))
       (void)]

      ;; Accept candidate
      [else
       (set! results (cons df results))]))

  (reverse results))

(define (sha256-file p)
  (call-with-input-file p
    (lambda (in)
      (sha256-bytes in))
    #:mode 'binary))




(define (hash-files candidates)
  (define total (length candidates))
  (define count 0)
  (define results '())

  (when (> total 0)
    (printf "Hashing ~a files...\n" total)
    (flush-output))

  (for ([df (in-list candidates)])
    (set! count (add1 count))

    ;; Progress every 50 files
    (when (or (= count total)
              (= (modulo count 50) 0))
      (printf "  hashed ~a / ~a\n" count total)
      (flush-output))

    (with-handlers ([exn:fail?
                     (lambda (e)
                       (set! results
                             (cons (hashed-file
                                    #f
                                    "sha256"
                                    (discovered-file-size df)
                                    (discovered-file-extension df)
                                    (discovered-file-path df))
                                   results)))])
      (define p (discovered-file-path df))
      (define digest-bytes (sha256-file p))
      (define digest-hex (bytes->hex-string digest-bytes))

      (set! results
            (cons (hashed-file
                   digest-hex
                   "sha256"
                   (discovered-file-size df)
                   (discovered-file-extension df)
                   p)
                  results))))

  (reverse results))

(define (ensure-schema! conn)
  (query-exec conn
    "CREATE TABLE IF NOT EXISTS files (
       hash TEXT PRIMARY KEY,
       hash_algo TEXT NOT NULL,
       size_bytes INTEGER NOT NULL,
       format TEXT NOT NULL,
       ingested_at TEXT NOT NULL
     );")

  (query-exec conn
    "CREATE TABLE IF NOT EXISTS file_sources (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       hash TEXT NOT NULL,
       source_path TEXT NOT NULL,
       original_filename TEXT,
       seen_at TEXT NOT NULL,
       FOREIGN KEY (hash) REFERENCES files(hash)
     );"))


(define (open-db db-path)
  (sqlite3-connect #:database db-path
                   #:mode 'create))

(define (hash-exists? conn hash)
  (query-maybe-value
   conn
   "SELECT 1 FROM files WHERE hash = ? LIMIT 1"
   hash))

(define (insert-file! conn hf)
  (query-exec
   conn
   "INSERT INTO files (hash, hash_algo, size_bytes, format, ingested_at)
    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)"
   (hashed-file-hash hf)
   (hashed-file-algo hf)
   (hashed-file-size hf)
   (hashed-file-format hf)))

(define (insert-file-source! conn hf)
  (query-exec
   conn
   "INSERT INTO file_sources (hash, source_path, original_filename, seen_at)
    VALUES (?, ?, ?, CURRENT_TIMESTAMP)"
   (hashed-file-hash hf)
   (path->string (hashed-file-path hf))
   (path->string (file-name-from-path (hashed-file-path hf)))))

(define (process-ingest hashed-files config)
  (define outcomes '())

  (define conn
    (and (not (ingest-config-dry-run? config))
         (open-db (ingest-config-db-path config))))

  (when conn
    (ensure-schema! conn)
    (query-exec conn "BEGIN"))

  (for ([hf (in-list hashed-files)])
    (with-handlers ([exn:fail?
                     (lambda (e)
                       (set! outcomes
                             (cons (ingest-outcome
                                    (hashed-file-hash hf)
                                    'failed
                                    (exn-message e))
                                   outcomes)))])
      (cond
        ;; Hashing failed earlier
        [(not (hashed-file-hash hf))
         (set! outcomes
               (cons (ingest-outcome
                      #f
                      'failed
                      "Hashing failed")
                     outcomes))]

        ;; Dry-run: read-only
        [(ingest-config-dry-run? config)
         (define exists?
           (hash-exists?
            (open-db (ingest-config-db-path config))
            (hashed-file-hash hf)))

         (set! outcomes
               (cons (ingest-outcome
                      (hashed-file-hash hf)
                      (if exists? 'duplicate 'new)
                      "Dry-run")
                     outcomes))]

        ;; Real ingest
        [else
         (define exists?
           (hash-exists? conn (hashed-file-hash hf)))

         (unless exists?
           (insert-file! conn hf))

         (insert-file-source! conn hf)

         (set! outcomes
               (cons (ingest-outcome
                      (hashed-file-hash hf)
                      (if exists? 'duplicate 'new)
                      "Ingested")
                     outcomes))])))

  (when conn
    (query-exec conn "COMMIT")
    (disconnect conn))

  (reverse outcomes))


(define (report-outcomes outcomes config)
  (define new 0)
  (define dup 0)
  (define failed 0)

  (for ([o (in-list outcomes)])
    (case (ingest-outcome-status o)
      [(new) (set! new (add1 new))]
      [(duplicate) (set! dup (add1 dup))]
      [(failed) (set! failed (add1 failed))]
      [else (void)]))

  (printf "\nIngest summary:\n")
  (printf "  new:       ~a\n" new)
  (printf "  duplicate: ~a\n" dup)
  (printf "  failed:    ~a\n" failed)
  (flush-output))


(define (hidden-path? p)
  (define fname (file-name-from-path p))
  (cond
    [(not fname) #f] ;; root or no filename → not hidden
    [else
     (define name (path->string fname))
     (and (positive? (string-length name))
          (char=? (string-ref name 0) #\.))]))




(module+ main
  (define config (parse-ingest-args))
  (run-ingest config))
