(in-package #:cl-wuffs)

(define-condition wuffs-error (error)
  ((message :initarg :message :reader wuffs-error-message))
  (:report (lambda (condition stream) (write-string (wuffs-error-message condition) stream))))

(define-condition unknown-format (wuffs-error) ())
(define-condition decode-error (wuffs-error) ())
(define-condition decompression-error (wuffs-error) ())
(define-condition hash-error (wuffs-error) ())

(defstruct image
  (pixels (make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (*)))
  (width 0 :type (unsigned-byte 32))
  (height 0 :type (unsigned-byte 32))
  (stride 0 :type (unsigned-byte 32)))

(defun ensure-octets (octets)
  (unless (typep octets '(array (unsigned-byte 8) (*)))
    (error 'type-error :datum octets :expected-type '(array (unsigned-byte 8) (*))))
  octets)

(defun read-octets (stream)
  (let ((chunk (make-array 8192 :element-type '(unsigned-byte 8)))
        (octets (make-array 0 :element-type '(unsigned-byte 8)
                              :adjustable t :fill-pointer 0)))
    (loop for length = (read-sequence chunk stream)
          while (plusp length)
          do (loop for index below length
                   do (vector-push-extend (aref chunk index) octets)))
    (let ((result (make-array (length octets) :element-type '(unsigned-byte 8))))
      (replace result octets)
      result)))

(defun input-octets (input)
  (cond ((typep input '(array (unsigned-byte 8) (*))) input)
        ((pathnamep input)
         (with-open-file (stream input :element-type '(unsigned-byte 8))
           (read-octets stream)))
        ((typep input 'stream) (read-octets input))
        (t (error 'type-error :datum input
                  :expected-type '(or (array (unsigned-byte 8) (*)) pathname stream)))))

(defun fourcc-keyword (fourcc)
  (intern (string-right-trim " "
                             (map 'string (lambda (shift)
                                           (code-char (ldb (byte 8 shift) fourcc)))
                                  '(24 16 8 0)))
          :keyword))

(defun detect-format (input)
  (let* ((data (ensure-octets (input-octets input)))
         (fourcc (cl-wuffs.bindings:detect-format data)))
    (if (plusp fourcc)
        (fourcc-keyword fourcc)
        (error 'unknown-format :message "Unsupported or unrecognized data."))))

(defun inspect (input)
  (list :format (detect-format input)))

(defun decode (input)
  (let ((octets (ensure-octets (input-octets input))))
    (detect-format octets)
    (multiple-value-bind (foreign-image status message)
        (cl-wuffs.bindings:decode-image (ensure-octets octets))
      (unless (zerop status)
        (error (if (= status 1) 'unknown-format 'decode-error)
               :message (or message "Wuffs could not decode the image.")))
      (unwind-protect
           (let* ((length (cl-wuffs.bindings:foreign-image-length foreign-image))
                  (pixels (make-array length :element-type '(unsigned-byte 8))))
             (cffi:with-pointer-to-vector-data (destination pixels)
               (cffi:foreign-funcall "memcpy" :pointer destination
                                     :pointer (cl-wuffs.bindings:foreign-image-pixels foreign-image)
                                     :size length :pointer))
             (make-image :pixels pixels
                         :width (cl-wuffs.bindings:foreign-image-width foreign-image)
                         :height (cl-wuffs.bindings:foreign-image-height foreign-image)
                         :stride (cl-wuffs.bindings:foreign-image-stride foreign-image)))
        (cl-wuffs.bindings:free-image foreign-image)))))

(defun adler32 (octets)
  (cl-wuffs.bindings:adler32 (ensure-octets octets)))

(defun crc32 (octets)
  (cl-wuffs.bindings:crc32 (ensure-octets octets)))

(defstruct (hasher (:constructor %make-hasher (handle)))
  handle
  (state :open))

(defun hash-algorithm (algorithm)
  (case algorithm
    (:adler32 1)
    (:crc32 2)
    (otherwise
     (error 'hash-error :message "Unsupported hash algorithm."))))

(defun make-hasher (algorithm)
  (multiple-value-bind (handle status message)
      (cl-wuffs.bindings:hasher-create (hash-algorithm algorithm))
    (unless (zerop status)
      (error 'hash-error :message (or message "Could not create hasher.")))
    (%make-hasher handle)))

(defun ensure-open-hasher (hasher)
  (unless (and (typep hasher 'hasher)
               (eq (hasher-state hasher) :open))
    (error 'hash-error :message "Hasher is not open."))
  hasher)

(defun hash-chunk (hasher octets)
  (ensure-open-hasher hasher)
  (multiple-value-bind (digest status message)
      (cl-wuffs.bindings:hasher-update (hasher-handle hasher) (ensure-octets octets))
    (declare (ignore digest))
    (unless (zerop status)
      (error 'hash-error :message (or message "Hashing failed.")))
    hasher))

(defun finish-hasher (hasher)
  (ensure-open-hasher hasher)
  (multiple-value-bind (digest status message)
      (cl-wuffs.bindings:hasher-update (hasher-handle hasher)
                                        (make-array 0 :element-type '(unsigned-byte 8)))
    (unless (zerop status)
      (error 'hash-error :message (or message "Hashing failed.")))
    (setf (hasher-state hasher) :finished)
    digest))

(defun close-hasher (hasher)
  (when (and (typep hasher 'hasher)
             (hasher-handle hasher))
    (cl-wuffs.bindings:hasher-free (hasher-handle hasher))
    (setf (hasher-handle hasher) nil
          (hasher-state hasher) :closed))
  nil)

(defstruct (decompressor (:constructor %make-decompressor (handle)))
  handle
  (state :open))

(defun compression-format (format)
  (ecase format
    (:bzip2 1)
    (:deflate 2)
    (:gzip 3)
    (:lzw 4)
    (:zlib 5)))

(defun make-decompressor (format &key literal-width)
  (when (and (eq format :lzw) (null literal-width))
    (error 'type-error :datum literal-width :expected-type '(integer 2 8)))
  (when (and (not (eq format :lzw)) literal-width)
    (error 'type-error :datum literal-width :expected-type 'null))
  (multiple-value-bind (handle status message)
      (cl-wuffs.bindings:decompressor-create (compression-format format)
                                              (or literal-width 0))
    (unless (zerop status)
      (error 'decompression-error :message (or message "Could not create decompressor.")))
    (%make-decompressor handle)))

(defun ensure-open-decompressor (decompressor)
  (unless (and (typep decompressor 'decompressor)
               (eq (decompressor-state decompressor) :open))
    (error 'decompression-error :message "Decompressor is not open."))
  decompressor)

(defun decompress-chunk (decompressor octets)
  (ensure-open-decompressor decompressor)
  (multiple-value-bind (output status message)
      (cl-wuffs.bindings:decompressor-process (decompressor-handle decompressor)
                                               (ensure-octets octets) nil)
    (unless (zerop status)
      (error 'decompression-error :message (or message "Decompression failed.")))
    output))

(defun finish-decompressor (decompressor)
  (ensure-open-decompressor decompressor)
  (multiple-value-bind (output status message)
      (cl-wuffs.bindings:decompressor-process (decompressor-handle decompressor)
                                               (make-array 0 :element-type '(unsigned-byte 8)) t)
    (unless (zerop status)
      (error 'decompression-error :message (or message "Decompression failed.")))
    (setf (decompressor-state decompressor) :finished)
    output))

(defun close-decompressor (decompressor)
  (when (and (typep decompressor 'decompressor)
             (decompressor-handle decompressor))
    (cl-wuffs.bindings:decompressor-free (decompressor-handle decompressor))
    (setf (decompressor-handle decompressor) nil
          (decompressor-state decompressor) :closed))
  nil)

(defun decompress-stream (format input output &key literal-width (buffer-size 8192))
  (unless (typep buffer-size '(integer 1))
    (error 'type-error :datum buffer-size :expected-type '(integer 1)))
  (let ((buffer (make-array buffer-size :element-type '(unsigned-byte 8)))
        (decompressor (make-decompressor format :literal-width literal-width)))
    (unwind-protect
         (progn
           (loop for length = (read-sequence buffer input)
                 while (plusp length)
                 do (write-sequence
                     (decompress-chunk decompressor
                                       (if (= length buffer-size)
                                           buffer
                                           (subseq buffer 0 length)))
                     output))
           (write-sequence (finish-decompressor decompressor) output))
      (close-decompressor decompressor))
    nil))
