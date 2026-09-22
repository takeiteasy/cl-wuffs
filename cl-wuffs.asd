(asdf:defsystem "cl-wuffs/bindings"
  :depends-on ("cffi")
  :serial t
  :components ((:file "lisp/bindings/package")
               (:file "lisp/bindings/generated")
               (:file "lisp/bindings/runtime")))

(asdf:defsystem "cl-wuffs/core"
  :depends-on ("cl-wuffs/bindings")
  :serial t
  :components ((:file "lisp/package")
               (:file "lisp/core")))

(asdf:defsystem "cl-wuffs/adler32" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/crc32" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/bmp" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/gif" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/nie" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/png" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/tga" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/wbmp" :depends-on ("cl-wuffs/core"))

(asdf:defsystem "cl-wuffs/image"
  :depends-on ("cl-wuffs/bmp" "cl-wuffs/gif" "cl-wuffs/nie" "cl-wuffs/png"
               "cl-wuffs/tga" "cl-wuffs/wbmp"))
(asdf:defsystem "cl-wuffs/hash" :depends-on ("cl-wuffs/adler32" "cl-wuffs/crc32"))
(asdf:defsystem "cl-wuffs/bzip2" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/deflate" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/gzip" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/lzw" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/zlib" :depends-on ("cl-wuffs/core"))
(asdf:defsystem "cl-wuffs/compression"
  :depends-on ("cl-wuffs/bzip2" "cl-wuffs/deflate" "cl-wuffs/gzip"
               "cl-wuffs/lzw" "cl-wuffs/zlib"))

(asdf:defsystem "cl-wuffs"
  :depends-on ("cl-wuffs/image" "cl-wuffs/hash" "cl-wuffs/compression"))

(asdf:defsystem "cl-wuffs/test"
  :depends-on ("cl-wuffs")
  :serial t
  :components ((:file "test/package")
               (:file "test/core")))
