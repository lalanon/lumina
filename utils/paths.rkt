#lang racket

(require racket/file
         racket/path
         racket/port)

(provide
 find-readable-path
 read-snippet-from-path)

;; --------------------------------------------------
;; Find the first readable path from a list
;; --------------------------------------------------

(define (readable-file? path)
  (with-handlers ([exn:fail? (λ (_) #f)])
    (and (file-exists? path)
         (call-with-input-file path (λ (_) #t)))))

(define (find-readable-path paths)
  (for/first ([p paths]
              #:when (and (string? p)
                          (readable-file? p)))
    p))

;; --------------------------------------------------
;; Read a snippet safely from a path
;; --------------------------------------------------

(define (read-snippet-from-path path #:bytes [n 4096])
  (with-handlers ([exn:fail? (λ (_) "")])
    (call-with-input-file path
      (λ (in)
        (bytes->string/utf-8
         (read-bytes n in)))
      #:mode 'binary)))
