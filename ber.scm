;;; Copyright (c) 2004-2005 by Alex Shinn. All rights reserved.
;;; MIT License

(define (read-ber-integer . opt)
  (let-params* opt ((port (current-input-port)))
    (let loop ((acc 0))
      (let ((byte (read-byte port)))
        (cond
          ((eof-object? byte) byte)   ; fail on eof
          ((< byte 128) (+ acc byte)) ; final byte is < 128
          (else
           (loop (arithmetic-shift (+ acc (bitwise-and byte 127)) 7))))))))

(define (write-ber-integer number . opt)
  (assert (integer? number) (not (negative? number)))
  (let-params* opt ((port (current-output-port)))
    (let loop ((n (arithmetic-shift number -7))
               (ls (list (bitwise-and number 127))))
      (if (zero? n)
        (for-each (lambda (b) (write-byte b port)) ls)
        (loop (arithmetic-shift n -7)
              (cons (+ 128 (bitwise-and n 127)) ls))))))
