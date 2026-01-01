#lang racket

(require racket/cmdline
         racket/list
         racket/string
         db)

;; -------------------------------
;; CLI
;; -------------------------------

(define verbose? #f)

(command-line
 #:program "lumina stats"
 #:once-each
 [("--verbose") "Verbose output" (set! verbose? #t)])

;; -------------------------------
;; DB
;; -------------------------------

(define conn (sqlite3-connect #:database "lumina.db"))

;; -------------------------------
;; Helpers
;; -------------------------------

(define (print-section title)
  (printf "\n== ~a ==\n" title))

;; -------------------------------
;; Identify statistics
;; -------------------------------

(print-section "Identification Overview")

(for ([row (query-rows conn
                       "SELECT
                          COUNT(*) AS total,
                          ROUND(AVG(confidence), 3) AS avg_conf,
                          MIN(confidence),
                          MAX(confidence)
                        FROM identified_metadata")])
  (match row
    [(vector total avg minc maxc)
     (printf "Total identified: ~a\n" total)
     (printf "Average confidence: ~a\n" avg)
     (printf "Confidence range: ~a – ~a\n" minc maxc)]))

(print-section "Identification Confidence Bands")

(for ([row (query-rows conn
                       "SELECT label, COUNT(*)
                        FROM (
                          SELECT
                            CASE
                              WHEN confidence >= 0.9 THEN '>= 0.9'
                              WHEN confidence >= 0.7 THEN '0.7 – 0.89'
                              ELSE '< 0.7'
                            END AS label
                          FROM identified_metadata
                        )
                        GROUP BY label
                        ORDER BY label DESC")])
  (match row
    [(vector label count)
     (printf "  ~a: ~a\n" label count)]))

(print-section "Taxonomy Coverage")

(for ([row (query-rows conn
                       "SELECT
                          SUM(CASE
                                WHEN root_category != 'unknown'
                                 AND second_level_category != 'unknown'
                                THEN 1 ELSE 0 END) AS with_taxonomy,
                          SUM(CASE
                                WHEN root_category = 'unknown'
                                  OR second_level_category = 'unknown'
                                THEN 1 ELSE 0 END) AS without_taxonomy
                        FROM identified_metadata")])
  (match row
    [(vector with without)
     (printf "With taxonomy: ~a\n" with)
     (printf "Without taxonomy: ~a\n" without)]))

(print-section "Top Root Categories")

(for ([row (query-rows conn
                       "SELECT root_category, COUNT(*)
                        FROM identified_metadata
                        GROUP BY root_category
                        ORDER BY COUNT(*) DESC
                        LIMIT 10")])
  (match row
    [(vector cat count)
     (printf "  ~a: ~a\n" cat count)]))

(print-section "Top Root → Second-Level Categories")

(for ([row (query-rows conn
                       "SELECT root_category, second_level_category, COUNT(*)
                        FROM identified_metadata
                        GROUP BY root_category, second_level_category
                        ORDER BY COUNT(*) DESC
                        LIMIT 10")])
  (match row
    [(vector root sub count)
     (printf "  ~a / ~a: ~a\n" root sub count)]))

(print-section "Tag Usage")

(for ([row (query-rows conn
                       "SELECT tag, COUNT(*)
                        FROM file_tags
                        GROUP BY tag
                        ORDER BY COUNT(*) DESC
                        LIMIT 20")])
  (match row
    [(vector tag count)
     (printf "  ~a: ~a\n" tag count)]))

;; -------------------------------
;; Existing ingest stats (unchanged)
;; -------------------------------

(when verbose?
  (print-section "Ingest Activity (operations_log)")

  (for ([row (query-rows conn
                         "SELECT operation, COUNT(*)
                          FROM operations_log
                          WHERE phase = 'ingest'
                          GROUP BY operation
                          ORDER BY COUNT(*) DESC")])
    (match row
      [(vector op count)
       (printf "  ~a: ~a\n" op count)])))

(disconnect conn)
