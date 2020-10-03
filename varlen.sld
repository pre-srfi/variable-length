(define-library (varlen)
  (export skip-varint-tail
          skip-varint
          skip-varbytes
          skip-netstring
          write-unsigned-varint
          write-signed-varint
          read-unsigned-varint
          read-signed-varint
          read-varbytes
          read-netstring-bytes
          write-varbytes
          write-netstring-bytes
          read-varstring
          read-netstring
          write-varstring
          write-netstring)
  (import (scheme base))
  (cond-expand
    ((library (srfi 151))
     (import (srfi 151)))
    (gambit
     (import (only (gambit)
                   arithmetic-shift bit-set? bitwise-and bitwise-ior))))
  (begin

    ;;; Helpers

    (define (skip-bytevector n port)
      (let* ((cap 128) (bytes (make-bytevector cap)))
        (let loop ((n n))
          (when (> n 0)
            (let* ((g (min n cap)) (r (read-bytevector! bytes port 0 g)))
              (if (or (eof-object? r) (< r g)) (error "Too few")
                  (loop (- n g))))))))

    (define (skip-terminator port terminator)
      (and terminator
           (let ((byte (read-u8 port)))
             (if (and (< byte 128) (char=? terminator (integer->char byte)))
                 #f
                 (error "No terminator")))))

    (define (write-terminator port terminator)
      (and terminator
           (let ((byte (char->integer terminator)))
             (if (< byte 128) (write-u8 byte port)
                 (error "Terminator not ASCII" terminator)))))

    (define (read-netstring-length port)
      (let ((zero #x30) (nine #x39) (colon #x3A))
        (let loop ((n 0))
          (let ((byte (read-u8 port)))
            (cond ((eof-object? byte) (error "Too few"))
                  ((<= zero byte nine) (loop (+ (* 10 n) (- byte zero))))
                  ((= colon byte) n)
                  (else (error "Too few")))))))

    (define (write-netstring-length n port)
      (let ((colon #x3A))
        (write-bytevector (string->utf8 (number->string n)) port)
        (write-u8 colon port)))

    (define (internal-read-varbytes port max-bytes nbytes)
      (when (and max-bytes (> nbytes max-bytes)) (error "Too large"))
      (let* ((bytes (read-bytevector nbytes port))
             (nread (if (eof-object? bytes) 0 (bytevector-length bytes))))
        (if (= nbytes nread) bytes (error "Wanted; got" nbytes nread))))

    ;;; Skip things

    (define (skip-varint-tail port)
      (let loop ((n 0))
        (let ((byte (peek-u8 port)))
          (if (or (eof-object? byte) (bit-set? 7 byte))
              (and (> n 0) n)
              (loop (+ n 1))))))

    (define (skip-varint port)
      (let loop ((n 0))
        (let ((byte (peek-u8 port)))
          (cond ((eof-object? byte) (error "Trailing byte expected"))
                ((bit-set? 7 byte) (loop (+ n 1)))
                (else (+ n 1) )))))

    (define (skip-varbytes port)
      (let ((nbytes (read-unsigned-varint port)))
        (skip-bytevector nbytes port)
        nbytes))

    (define (skip-netstring port terminator)
      (let ((nbytes (read-netstring-length port)))
        (skip-bytevector nbytes port)
        (skip-terminator port terminator)
        nbytes))

    ;;; Write varints

    (define (write-unsigned-varint u port)
      (unless (and (integer? u) (exact-integer? u) (>= u 0)) (error "Bad"))
      (let loop ((u u))
        (cond ((< u 128) (write-u8 u port) #f)
              (else (write-u8 (bitwise-ior 128 (bitwise-and u 127))
                              port)
                    (loop (arithmetic-shift u -7))))))

    (define (write-signed-varint x port)
      (let ((u (if (>= x 0) x (+ 1 (* 2 (- (+ x 1)))))))
        (write-unsigned-varint u port)))

    ;;; Read varints

    (define (read-unsigned-varint port max-value)
      (let loop ((x 0) (shift 0))
        (let* ((byte (read-u8 port))
               (x (bitwise-ior
                   x (arithmetic-shift (bitwise-and 127 byte) shift))))
          (if (not (= 0 (bitwise-and 128 byte)))
              (loop x (+ shift 7))
              (cond ((and max-value (> x max-value)) (error "Too large"))
                    (else x))))))

    (define (read-signed-varint port min-value max-value)
      (let* ((u (read-unsigned-varint port #f))
             (x (if (even? u) (truncate-quotient u 2)
                    (- (- (truncate-quotient (- u 1) 2)) 1))))
        (cond ((and min-value (< x min-value)) (error "Too small"))
              ((and max-value (> x max-value)) (error "Too large"))
              (else x))))

    ;;; Bytevector procedures

    (define (read-varbytes port max-bytes)
      (let ((bytes (internal-read-varbytes
                    port max-bytes (read-unsigned-varint port #f))))
        bytes))

    (define (read-netstring-bytes port max-bytes terminator)
      (let ((bytes (internal-read-varbytes
                    port max-bytes (read-netstring-length port))))
        (skip-terminator port terminator)
        bytes))

    (define (write-varbytes bytes port start end)
      (let* ((start (or start 0))
             (end (or end (bytevector-length bytes)))
             (nbytes (- end start)))
        (when (< nbytes 0) (error "Negative"))
        (write-unsigned-varint nbytes port)
        (write-bytevector bytes port start end)))

    (define (write-netstring-bytes bytes port start end terminator)
      (let* ((start (or start 0))
             (end (or end (bytevector-length bytes)))
             (nbytes (- end start)))
        (when (< nbytes 0) (error "Negative"))
        (write-netstring-length nbytes port)
        (write-bytevector bytes port start end)
        (write-terminator port terminator)))

    ;;; String procedures

    (define (read-varstring port max-bytes
                            #;encoding #;invalid)
      (utf8->string (read-varbytes port max-bytes)))

    (define (read-netstring port max-bytes terminator
                            #;encoding #;invalid)
      (utf8->string (read-netstring-bytes port max-bytes terminator)))

    (define (write-varstring string port start end
                             #;encoding #;invalid)
      (let* ((start (or start 0))
             (end (or end (string-length string)))
             (bytes (string->utf8 string start end)))
        (write-varbytes bytes port #f #f)))

    (define (write-netstring string port start end terminator
                             #;encoding #;invalid)
      (let* ((start (or start 0))
             (end (or end (string-length string)))
             (bytes (string->utf8 string start end)))
        (write-netstring-bytes bytes port #f #f terminator)))))
