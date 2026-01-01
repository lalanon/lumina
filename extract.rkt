#lang racket

(require racket/cmdline
         racket/list
         racket/string
         racket/file
         racket/path
         racket/port
         racket/hash
         file/unzip
         xml
         db
         "utils/sql.rkt"
         "utils/paths.rkt")

;; =========================================================
;; CLI options
;; =========================================================

(define limit #f)
(define verbose? #f)
(define dry-run? #f)

(command-line
 #:program "extract.rkt"
 #:once-each
 [("--limit") n "Limit number of files"
  (set! limit (string->number n))]
 [("--verbose") "Verbose output"
  (set! verbose? #t)]
 [("--dry-run") "Do not write to database"
  (set! dry-run? #t)])

(define (logv fmt . args)
  (when verbose?
    (apply printf fmt args)
    (newline)))

;; =========================================================
;; Time helper
;; =========================================================

(define (now-str)
  (define d (seconds->date (current-seconds)))
  (format "~a-~a-~a ~a:~a:~a"
          (date-year d)
          (date-month d)
          (date-day d)
          (date-hour d)
          (date-minute d)
          (date-second d)))

;; =========================================================
;; SQL NULL helper
;; =========================================================

(define (->sql-null v)
  (if (or (eq? v #f) (void? v))
      sql-null
      v))

;; =========================================================
;; Filename metadata (SAFE FALLBACK)
;; =========================================================

(define (filename-metadata path)
  (define base (path->string (file-name-from-path path)))
  (define name (regexp-replace #rx"\\.[^.]+$" base ""))
  (hash 'title name
        'confidence 0.2))

;; =========================================================
;; EPUB extraction (unchanged logic, safe)
;; =========================================================

(define (extract-epub path)
  (define tmp (make-temporary-file "lumina-epub~a" 'directory))
  (begin0
    (with-handlers ([exn:fail? (lambda (_) #f)])
      (define container (build-path tmp "container.xml"))
      (call-with-input-file path
        (lambda (in)
          (unzip-entry in "META-INF/container.xml" container)))
      (define cx
        (call-with-input-file container
          (lambda (in)
            (xml->xexpr
             (document-element (read-xml in))))))
      (define opf-rel
        (let find ([x cx])
          (cond
            [(and (list? x) (eq? (car x) 'rootfile))
             (define p (assoc 'full-path (cadr x)))
             (and p (cdr p))]
            [(list? x) (for/or ([e x]) (find e))]
            [else #f])))
      (unless opf-rel #f)
      (define opf-path (build-path tmp "content.opf"))
      (call-with-input-file path
        (lambda (in)
          (unzip-entry in opf-rel opf-path)))
      (define ox
        (call-with-input-file opf-path
          (lambda (in)
            (xml->xexpr
             (document-element (read-xml in))))))
      (define (dc tag)
        (let loop ([x ox])
          (cond
            [(and (list? x) (eq? (car x) tag)) (cadr x)]
            [(list? x) (for/or ([e x]) (loop e))]
            [else #f])))
      (hash
       'title (dc 'dc:title)
       'author (dc 'dc:creator)
       'language (dc 'dc:language)
       'confidence 0.8))
    (delete-directory/files tmp)))

;; =========================================================
;; Comic extraction (SCOPE FIXED)
;; =========================================================

(define (extract-comic path)
  (define tmp (make-temporary-file "lumina-comic~a" 'directory))
  (begin0
    (with-handlers ([exn:fail? (lambda (_) #f)])
      (define info (build-path tmp "ComicInfo.xml"))
      (call-with-input-file path
        (lambda (in)
          (unzip-entry in "ComicInfo.xml" info)))
      (define cx
        (call-with-input-file info
          (lambda (in)
            (xml->xexpr
             (document-element (read-xml in))))))
      (define (tag n)
        (let loop ([x cx])
          (cond
            [(and (list? x) (eq? (car x) n)) (cadr x)]
            [(list? x) (for/or ([e x]) (loop e))]
            [else #f])))
      (hash
       'title (tag 'Title)
       'series (tag 'Series)
       'volume (tag 'Number)
       'author (tag 'Writer)
       'language (tag 'Language)
       'confidence 0.75))
    (delete-directory/files tmp)))

;; =========================================================
;; Dispatcher
;; =========================================================

(define (file-extension p)
  (define s (path->string (file-name-from-path p)))
  (define m (regexp-match #rx"\\.([^./]+)$" s))
  (and m (string-downcase (list-ref m 1))))

(define (extract-local path)
  (define ext (file-extension path))
  (cond
    [(equal? ext "epub") (extract-epub path)]
    [(member ext '("cbz" "cbr")) (extract-comic path)]
    [else (filename-metadata path)]))

;; =========================================================
;; Main
;; =========================================================

(define conn (sqlite3-connect #:database "lumina.db"))

(define rows
  (if limit
      (query-rows
       conn
       "SELECT f.hash, fs.paths
        FROM files f
        JOIN (
          SELECT hash,
                 group_concat(source_path, char(31)) AS paths
          FROM file_sources
          GROUP BY hash
        ) fs ON fs.hash = f.hash
        LEFT JOIN document_classification dc ON dc.hash = f.hash
        LEFT JOIN extracted_metadata em ON em.hash = f.hash
        WHERE dc.hash IS NULL
          AND em.hash IS NULL
        LIMIT ?"
       limit)
      (query-rows
       conn
       "SELECT f.hash, fs.paths
        FROM files f
        JOIN (
          SELECT hash,
                 group_concat(source_path, char(31)) AS paths
          FROM file_sources
          GROUP BY hash
        ) fs ON fs.hash = f.hash
        LEFT JOIN document_classification dc ON dc.hash = f.hash
        LEFT JOIN extracted_metadata em ON em.hash = f.hash
        WHERE dc.hash IS NULL
          AND em.hash IS NULL")))

(for ([row rows])
  (define hash (vector-ref row 0))
  (define paths
    (string-split (vector-ref row 1)
                  (string (integer->char 31))))
  (define readable (find-readable-path paths))
  (when readable
    (define meta (extract-local readable))
    (when meta
      (logv "Extracted ~a from ~a" hash readable)
      (unless dry-run?
        (query-exec
         conn
         "INSERT OR REPLACE INTO extracted_metadata
          (hash, format, source,
           title, author, series, volume, language,
           isbn, is_periodical,
           confidence_hint, extracted_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
         hash
         (->sql-null (file-extension readable))
         "local"
         (->sql-null (hash-ref meta 'title #f))
         (->sql-null (hash-ref meta 'author #f))
         (->sql-null (hash-ref meta 'series #f))
         (->sql-null (hash-ref meta 'volume #f))
         (->sql-null (hash-ref meta 'language #f))
         (->sql-null (hash-ref meta 'isbn #f))
         (->sql-null (hash-ref meta 'is_periodical #f))
         (hash-ref meta 'confidence 0.1)
         (now-str))))))

(disconnect conn)
