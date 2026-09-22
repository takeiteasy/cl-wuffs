(defpackage #:cl-wuffs
  (:use #:cl)
  (:shadow #:inspect)
  (:export #:detect-format #:inspect #:decode #:adler32
           #:image #:image-pixels #:image-width #:image-height #:image-stride
           #:wuffs-error #:unknown-format #:decode-error))
