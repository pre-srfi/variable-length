(import (scheme base) (scheme write) (varlen))

(define (writeln x) (write x) (newline))

(define (test-signed-varint-io x)
  (let ((out (open-output-bytevector)))
    (write-signed-varint x out)
    (let ((in (open-input-bytevector (get-output-bytevector out))))
      (read-signed-varint in #f #f))))

(define (test-varstring-io string)
  (let ((out (open-output-bytevector)))
    (write-varstring string out #f #f)
    (let ((in (open-input-bytevector (get-output-bytevector out))))
      (read-varstring in #f))))

(define (test-netstring-io string)
  (let ((out (open-output-bytevector)))
    (write-netstring string out #f #f #\,)
    (let ((in (open-input-bytevector (get-output-bytevector out))))
      (read-netstring in #f #\,))))

(writeln (test-signed-varint-io -1234567890))
(writeln (test-varstring-io "hello world"))
(writeln (test-netstring-io "hello world"))
