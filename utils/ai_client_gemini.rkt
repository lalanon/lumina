#lang racket

(require net/http-client
         racket/string
         json)

(provide gemini-classify-batch)

;; Gemini REST endpoint (host + path split for http-sendrecv)
(define gemini-host "generativelanguage.googleapis.com")
(define gemini-path
  "/v1beta/models/gemini-3-flash-preview:generateContent")

(define (gemini-classify-batch api-key system-prompt schema-path docs-json)
  ;; Load schema (not enforced yet, but useful for debugging / future validation)
  (define _schema
    (call-with-input-file schema-path read-json))

  ;; Build request payload
  (define payload
    (hash
     'contents
     (list
      (hash
       'role "system"
       'parts (list (hash 'text system-prompt)))
      (hash
       'role "user"
       'parts
       (list
        (hash
         'text
         (jsexpr->string docs-json)))))
     'generationConfig
     (hash
      'responseMimeType "application/json"
      'temperature 0.0)))

  ;; Perform HTTP POST request
  (define-values (status headers in)
    (http-sendrecv
     gemini-host
     gemini-path
     #:ssl? #t
     #:method "POST"
     #:headers
     (list
      "Content-Type: application/json"
      (string-append "x-goog-api-key: " api-key))
     #:data
     (jsexpr->string payload)))

  ;; Read and parse response
  (define response
    (read-json in))

  ;; Extract model output
  (define candidates
    (hash-ref response 'candidates '()))

  (when (null? candidates)
    (error "Gemini returned no candidates" response))

  (define content
    (hash-ref (first candidates) 'content))

  (define parts
    (hash-ref content 'parts))

  (define text
    (hash-ref (first parts) 'text))

  ;; Parse JSON returned by the model
  (string->jsexpr text))