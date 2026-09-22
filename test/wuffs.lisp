(in-package #:cl-wuffs.test)

(def-suite cl-wuffs)
(in-suite cl-wuffs)

(defparameter *test-directory*
  (asdf:system-relative-pathname "cl-wuffs/test" "test/"))

(defun fixture-octets (name)
  (let ((path (merge-pathnames name *test-directory*)))
    (with-open-file (stream path :element-type '(unsigned-byte 8))
      (let ((octets (make-array (file-length stream) :element-type '(unsigned-byte 8))))
        (read-sequence octets stream)
        octets))))

(test adler32-checksum
  (is (= 1 (adler32 (make-array 0 :element-type '(unsigned-byte 8))))))

(test detects-supported-images
  (dolist (fixture '(("lena.bmp" :bmp) ("lena.png" :png) ("lena.tga" :tga)))
    (is (eq (second fixture) (detect-format (fixture-octets (first fixture)))))))

(test decodes-supported-images
  (dolist (name '("lena.bmp" "lena.png" "lena.tga"))
    (let ((image (decode (fixture-octets name))))
      (is (= 512 (image-width image)))
      (is (= 512 (image-height image))))))

(test rejects-unsupported-images
  (dolist (name '("lena.jpg" "lena.qoi" "lena.zip"))
    (signals unknown-format (decode (fixture-octets name)))))

(defun run-tests ()
  (unless (run! 'cl-wuffs)
    (error "FiveAM tests failed.")))
