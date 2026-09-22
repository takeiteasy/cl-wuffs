(asdf:defsystem "cl-wuffs/bindings"
  :depends-on ("cffi")
  :serial t
  :author "George Watson"
  :license "MIT"
  :version "0.1.0"
  :components ((:file "bindings/package")
               (:file "bindings/generated")
               (:file "bindings/runtime")))

(asdf:defsystem "cl-wuffs"
  :description "Common Lisp bindings for Wuffs"
  :author "George Watson"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("cl-wuffs/bindings")
  :components ((:file "package")
               (:file "wuffs")))

(asdf:defsystem "cl-wuffs/test"
  :depends-on ("cl-wuffs" "fiveam")
  :serial t
  :author "George Watson"
  :license "GPLv3"
  :version "0.1.0"
  :components ((:file "test/package")
               (:file "test/wuffs"))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call :cl-wuffs.test :run-tests)))
