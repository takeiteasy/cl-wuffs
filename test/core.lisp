(in-package #:cl-wuffs.test)

(defun octets (&rest values)
  (make-array (length values) :element-type '(unsigned-byte 8) :initial-contents values))

(defun run ()
  (assert (= 1 (adler32 (octets))))
  (assert (eq :png (detect-format (octets 137 80 78 71 13 10 26 10))))
  (let ((image (cl-wuffs:decode (octets 137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82
                                         0 0 0 1 0 0 0 1 8 6 0 0 0 31 21 196 137
                                         0 0 0 13 73 68 65 84 8 215 99 248 207 192
                                         240 31 0 5 0 1 255 137 153 61 29 0 0 0 0
                                         73 69 78 68 174 66 96 130))))
    (assert (= 1 (cl-wuffs:image-width image)))
    (assert (= 1 (cl-wuffs:image-height image))))
  (handler-case (detect-format (octets 0 1 2 3))
    (unknown-format () t)))
