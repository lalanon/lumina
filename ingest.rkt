#lang racket
(require racket/cmdline
        racket/path
        racket/file
        racket/list
        racket/string
        file/sha1)

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
  (define results '())

  (for ([df (in-list candidates)])
    (with-handlers ([exn:fail?
                     (lambda (e)
                       ;; Skip file on error, continue with others
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
