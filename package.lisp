(defpackage #:cl-wuffs
  (:use #:cl)
  (:shadow #:inspect)
  (:export #:detect-format #:inspect #:decode #:adler32 #:crc32
           #:hasher #:make-hasher #:hash-chunk #:finish-hasher #:close-hasher
           #:decompressor #:make-decompressor #:decompress-chunk
           #:finish-decompressor #:close-decompressor #:decompress-stream
           #:image #:image-pixels #:image-width #:image-height #:image-stride
           #:wuffs-error #:unknown-format #:decode-error #:decompression-error #:hash-error))
