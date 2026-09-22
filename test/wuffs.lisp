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

(defun hex-octets (string)
  (let ((octets (make-array (/ (length string) 2) :element-type '(unsigned-byte 8))))
    (loop for index below (length octets)
          do (setf (aref octets index)
                   (parse-integer string :start (* index 2) :end (* (1+ index) 2) :radix 16)))
    octets))

(defun decompress-in-chunks (format octets &key literal-width)
  (let ((decompressor (make-decompressor format :literal-width literal-width)))
    (unwind-protect
         (let ((parts (loop for octet across octets
                            collect (decompress-chunk decompressor
                                                      (make-array 1 :element-type '(unsigned-byte 8)
                                                                   :initial-contents (list octet))))))
           (apply #'concatenate '(vector (unsigned-byte 8))
                  (append parts (list (finish-decompressor decompressor)))))
      (close-decompressor decompressor))))

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

(test accepts-pathnames-and-binary-streams
  (let ((path (merge-pathnames "lena.png" *test-directory*)))
    (is (eq :png (detect-format path)))
    (is (equal '(:format :png) (cl-wuffs:inspect path)))
    (is (= 512 (image-width (decode path))))
    (with-open-file (stream path :element-type '(unsigned-byte 8))
      (is (eq :png (detect-format stream))))
    (with-open-file (stream path :element-type '(unsigned-byte 8))
      (is (= 512 (image-width (decode stream))))
      (is (= (file-length stream) (file-position stream)))
      (is (open-stream-p stream)))))

(test rejects-unsupported-images
  (dolist (name '("lena.jpg" "lena.qoi" "lena.zip"))
    (signals unknown-format (decode (fixture-octets name)))))

(test streaming-decompression
  (let ((expected #(104 101 108 108 111 32 119 117 102 102 115 10)))
    (dolist (fixture '((:bzip2 "425a6839314159265359bfc697df000002d1800010400003448a8020003100302007a406a304d5dde2ee48a70a1217f8d2fbe0")
                       (:deflate "cb48cdc9c957282f4d4b2be60200")
                       (:gzip "1f8b0800000000000213cb48cdc9c957282f4d4b2be60200867537520c000000")
                       (:lzw "00d19461c3e60d883b75cc9899a32020")
                       (:zlib "789ccb48cdc9c957282f4d4b2be602001e6c046a")))
      (is (equalp expected (decompress-in-chunks (first fixture) (hex-octets (second fixture))
                                                :literal-width (and (eq (first fixture) :lzw) 8)))))))

(test rejects-invalid-decompression-state
  (signals type-error (make-decompressor :lzw))
  (signals decompression-error
    (let ((decompressor (make-decompressor :gzip)))
      (unwind-protect (finish-decompressor decompressor)
        (close-decompressor decompressor))))
  (let ((decompressor (make-decompressor :gzip)))
    (unwind-protect
         (progn
           (decompress-chunk decompressor
                               (hex-octets "1f8b0800000000000213cb48cdc9c957282f4d4b2be60200867537520c000000"))
           (finish-decompressor decompressor)
           (signals decompression-error (finish-decompressor decompressor)))
      (close-decompressor decompressor))))

(defun run-tests ()
  (unless (run! 'cl-wuffs)
    (error "FiveAM tests failed.")))
