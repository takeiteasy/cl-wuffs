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

(defun ascii-octets (string)
  (map '(vector (unsigned-byte 8)) #'char-code string))

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

(test checksum-values
  (let ((octets (ascii-octets "123456789")))
    (is (= #x091E01DE (adler32 octets)))
    (is (= #xCBF43926 (crc32 octets)))))

(test streaming-checksums
  (dolist (algorithm '(:adler32 :crc32))
    (let ((hasher (make-hasher algorithm))
          (octets (ascii-octets "123456789")))
      (unwind-protect
           (progn
             (is (eq hasher (hash-chunk hasher (subseq octets 0 4))))
             (hash-chunk hasher (subseq octets 4))
             (is (= (if (eq algorithm :adler32)
                        (adler32 octets)
                        (crc32 octets))
                    (finish-hasher hasher)))
             (signals hash-error (hash-chunk hasher octets))
             (signals hash-error (finish-hasher hasher)))
        (close-hasher hasher)))))

(test rejects-invalid-hasher-state
  (signals hash-error (make-hasher :unknown))
  (let ((hasher (make-hasher :crc32)))
    (close-hasher hasher)
    (is (null (close-hasher hasher)))
    (signals hash-error (hash-chunk hasher (ascii-octets "x")))))

(test detects-supported-images
  (dolist (fixture '(("lena.bmp" :bmp) ("lena.png" :png) ("lena.tga" :tga)))
    (is (eq (second fixture) (detect-format (fixture-octets (first fixture)))))))

(test decodes-supported-images
  (dolist (name '("lena.bmp" "lena.png" "lena.tga"))
    (let ((image (decode (fixture-octets name))))
      (is (= 512 (image-width image)))
      (is (= 512 (image-height image))))))

(test decodes-animation-frames
  (let* ((animation (decode-animation
                     (hex-octets
                      "47494638396101000100800000ff000000000021ff0b4e45545343415045322e30030100000021f904000a0000002c000000000100010000020244010021f90400140000002c00000000010001000002024c01003b")))
         (frames (animation-frames animation)))
    (is (= 2 (length frames)))
    (is (= 100 (animation-frame-duration-milliseconds (aref frames 0))))
    (is (= 200 (animation-frame-duration-milliseconds (aref frames 1))))
    (is (eq :infinite (animation-loop-count animation)))
    (is (= 1 (image-width (animation-frame-image (aref frames 0)))))))

(defun zip-u16-octets (value)
  (vector (ldb (byte 8 0) value) (ldb (byte 8 8) value)))

(defun zip-u32-octets (value)
  (concatenate '(vector (unsigned-byte 8)) (zip-u16-octets value) (zip-u16-octets (ash value -16))))

(defun test-zip (name payload &key (method 0) (compressed payload) (crc (crc32 payload)))
  (let ((name-octets (ascii-octets name)))
    (flet ((header (signature fields)
             (apply #'concatenate '(vector (unsigned-byte 8))
                    (zip-u32-octets signature) fields)))
      (let ((local (header #x04034B50 (list (zip-u16-octets 20) (zip-u16-octets 0)
                                             (zip-u16-octets method) #(0 0 0 0)
                                             (zip-u32-octets crc) (zip-u32-octets (length compressed))
                                             (zip-u32-octets (length payload)) (zip-u16-octets (length name-octets)) #(0 0))))
            (central (header #x02014B50 (list (zip-u16-octets 20) (zip-u16-octets 20) (zip-u16-octets 0)
                                               (zip-u16-octets method) #(0 0 0 0) (zip-u32-octets crc)
                                               (zip-u32-octets (length compressed)) (zip-u32-octets (length payload))
                                               (zip-u16-octets (length name-octets)) (zip-u16-octets 0) (zip-u16-octets 0)
                                               (zip-u16-octets 0) (zip-u16-octets 0) (zip-u32-octets 0)
                                               (zip-u32-octets 0)))) )
        (let* ((prefix (concatenate '(vector (unsigned-byte 8)) local name-octets compressed))
               (directory (concatenate '(vector (unsigned-byte 8)) central name-octets))
               (eocd (header #x06054B50 (list #(0 0 0 0) (zip-u16-octets 1) (zip-u16-octets 1)
                                                (zip-u32-octets (length directory)) (zip-u32-octets (length prefix)) #(0 0)))))
          (concatenate '(vector (unsigned-byte 8)) prefix directory eocd))))))

(test reads-zip-archives
  (let* ((payload (ascii-octets (format nil "hello wuffs~%")))
         (archive (open-zip (test-zip "hello.txt" payload))))
    (is (= 1 (length (zip-entries archive))))
    (is (string= "hello.txt" (zip-entry-name (aref (zip-entries archive) 0))))
    (is (equalp payload (read-zip-entry archive "hello.txt"))))
  (let ((payload (ascii-octets (format nil "hello wuffs~%")))
        (raw-deflate (hex-octets "cb48cdc9c957282f4d4b2be60200")))
    (is (equalp payload (read-zip-entry (open-zip (test-zip "deflated.txt" payload :method 8 :compressed raw-deflate))
                                         "deflated.txt"))))
  (signals zip-error (open-zip (hex-octets "504b050600000000000000000000000000000000"))))

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

(defun decompress-stream-to-octets (format octets &key literal-width buffer-size)
  (uiop:with-temporary-file (:pathname input :stream input-stream
                             :direction :output
                             :element-type '(unsigned-byte 8))
    (write-sequence octets input-stream)
    (close input-stream)
    (uiop:with-temporary-file (:pathname output :stream output-stream
                               :direction :output
                               :element-type '(unsigned-byte 8))
      (close output-stream)
      (with-open-file (source input :element-type '(unsigned-byte 8))
        (with-open-file (destination output :direction :output :if-exists :supersede
                                          :element-type '(unsigned-byte 8))
          (apply #'decompress-stream format source destination
                 :literal-width literal-width
                 (and buffer-size (list :buffer-size buffer-size)))))
      (with-open-file (result output :element-type '(unsigned-byte 8))
        (let ((octets (make-array (file-length result) :element-type '(unsigned-byte 8))))
          (read-sequence octets result)
          octets)))))

(test stream-decompression
  (let ((expected #(104 101 108 108 111 32 119 117 102 102 115 10)))
    (dolist (fixture '((:bzip2 "425a6839314159265359bfc697df000002d1800010400003448a8020003100302007a406a304d5dde2ee48a70a1217f8d2fbe0")
                       (:deflate "cb48cdc9c957282f4d4b2be60200")
                       (:gzip "1f8b0800000000000213cb48cdc9c957282f4d4b2be60200867537520c000000")
                       (:lzw "00d19461c3e60d883b75cc9899a32020")
                       (:zlib "789ccb48cdc9c957282f4d4b2be602001e6c046a")))
      (is (equalp expected
                  (decompress-stream-to-octets (first fixture) (hex-octets (second fixture))
                                                :literal-width (and (eq (first fixture) :lzw) 8)
                                                :buffer-size 1)))))
  (uiop:with-temporary-file (:stream output :direction :output
                             :element-type '(unsigned-byte 8))
    (signals type-error
      (with-open-file (input (merge-pathnames "lena.zip" *test-directory*)
                             :element-type '(unsigned-byte 8))
        (decompress-stream :gzip input output :buffer-size 0)))))

(test stream-decompression-default-buffer
  (is (equalp #(104 101 108 108 111 32 119 117 102 102 115 10)
              (decompress-stream-to-octets
               :gzip
               (hex-octets "1f8b0800000000000213cb48cdc9c957282f4d4b2be60200867537520c000000")))))

(test stream-decompression-rejects-malformed-input
  (uiop:with-temporary-file (:pathname input :stream input-stream
                             :direction :output
                             :element-type '(unsigned-byte 8))
    (write-sequence (hex-octets "1f8b08") input-stream)
    (close input-stream)
    (uiop:with-temporary-file (:stream output :direction :output
                               :element-type '(unsigned-byte 8))
      (with-open-file (source input :element-type '(unsigned-byte 8))
        (signals decompression-error
          (decompress-stream :gzip source output :buffer-size 1))))))

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
