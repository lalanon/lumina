#lang racket
(require racket/file
         racket/string
         json)

(provide get-api-key)

(define config-dir
  (build-path (find-system-path 'home-dir) ".lumina"))

(define config-file
  (build-path config-dir "config.json"))

(define (get-api-key)
  (when (not (directory-exists? config-dir))
    (make-directory* config-dir))

  (define cfg
    (if (file-exists? config-file)
        (call-with-input-file config-file read-json)
        (hash)))

  (define key (hash-ref cfg 'api_key #f))

   (if key
      key
      (begin
        (display "Enter Gemini API key: ")
        (flush-output)
        (let ([entered (string-trim (read-line))])
          (call-with-output-file config-file
            (λ (out)
              (write-json (hash 'api_key entered) out))
            #:exists 'replace)
          entered))))

