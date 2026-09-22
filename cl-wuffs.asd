(asdf:defsystem "cl-wuffs/bindings"
  :depends-on ("cffi")
  :serial t
  :components ((:file "bindings/package")
               (:file "bindings/generated")
               (:file "bindings/runtime")))

(asdf:defsystem "cl-wuffs/core"
  :depends-on ("cl-wuffs/bindings")
  :serial t
  :components ((:file "package")
               (:file "wuffs")))

(asdf:defsystem "cl-wuffs"
  :description "Common Lisp bindings for Wuffs"
  :license "MIT"
  :depends-on ("cl-wuffs/core"))

(asdf:defsystem "cl-wuffs/test"
  :depends-on ("cl-wuffs" "fiveam")
  :serial t
  :components ((:file "test/package")
               (:file "test/wuffs"))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call :cl-wuffs.test :run-tests)))
