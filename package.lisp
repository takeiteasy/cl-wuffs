(defpackage #:cl-wuffs
  (:use #:cl)
  (:shadow #:inspect)
  (:export #:detect-format #:inspect #:decode #:decode-animation #:adler32 #:crc32
           #:hasher #:make-hasher #:hash-chunk #:finish-hasher #:close-hasher
           #:decompressor #:make-decompressor #:decompress-chunk
           #:finish-decompressor #:close-decompressor #:decompress-stream
           #:image #:image-pixels #:image-width #:image-height #:image-stride
           #:animation #:animation-frames #:animation-loop-count
           #:animation-frame #:animation-frame-image #:animation-frame-duration-milliseconds
           #:zip-archive #:zip-entry #:zip-entries #:zip-entry-name #:zip-entry-compressed-size
           #:zip-entry-decompressed-size #:open-zip #:read-zip-entry #:zip-error
           #:wuffs-error #:unknown-format #:decode-error #:decompression-error #:hash-error))
