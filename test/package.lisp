(defpackage #:cl-wuffs.test
  (:use #:cl #:fiveam)
  (:import-from #:cl-wuffs #:adler32 #:close-decompressor #:decode
                #:decompress-chunk #:decompression-error #:detect-format
                #:finish-decompressor #:image-height #:image-width
                #:make-decompressor #:unknown-format)
  (:export #:run-tests))
