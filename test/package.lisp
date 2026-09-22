(defpackage #:cl-wuffs.test
  (:use #:cl #:fiveam)
  (:import-from #:cl-wuffs #:adler32 #:decode #:detect-format #:image-height
                #:image-width #:unknown-format)
  (:export #:run-tests))
