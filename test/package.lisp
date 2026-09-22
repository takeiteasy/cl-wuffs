(defpackage #:cl-wuffs.test
  (:use #:cl #:fiveam)
  (:import-from #:cl-wuffs #:adler32 #:close-decompressor #:close-hasher #:crc32
                #:decode #:decompress-chunk #:decompression-error #:decompress-stream
                #:detect-format #:finish-decompressor #:finish-hasher #:hash-chunk
                #:hash-error #:image-height #:image-width #:make-decompressor
                #:make-hasher #:unknown-format)
  (:export #:run-tests))
