(in-package #:cl-wuffs)

(define-condition wuffs-error (error)
  ((message :initarg :message :reader wuffs-error-message))
  (:report (lambda (condition stream) (write-string (wuffs-error-message condition) stream))))

(define-condition unknown-format (wuffs-error) ())
(define-condition decode-error (wuffs-error) ())
(define-condition decompression-error (wuffs-error) ())
(define-condition hash-error (wuffs-error) ())
(define-condition zip-error (wuffs-error) ())

(defstruct image
  (pixels (make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (*)))
  (width 0 :type (unsigned-byte 32))
  (height 0 :type (unsigned-byte 32))
  (stride 0 :type (unsigned-byte 32)))

(defstruct animation-frame
  image
  (duration-milliseconds 0 :type (unsigned-byte 64)))

(defstruct animation
  (frames #() :type vector)
  loop-count)

(defstruct zip-entry
  name
  (flags 0 :type (unsigned-byte 16))
  (method 0 :type (unsigned-byte 16))
  (crc32 0 :type (unsigned-byte 32))
  (compressed-size 0 :type (unsigned-byte 32))
  (decompressed-size 0 :type (unsigned-byte 32))
  (local-offset 0 :type (unsigned-byte 32)))

(defstruct zip-archive
  octets
  entries
  max-compressed-size
  max-decompressed-size
  max-total-decompressed-size)

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

(defun copy-foreign-image (foreign-image)
  (let* ((length (cl-wuffs.bindings:foreign-image-length foreign-image))
         (pixels (make-array length :element-type '(unsigned-byte 8))))
    (when (plusp length)
      (cffi:with-pointer-to-vector-data (destination pixels)
        (cffi:foreign-funcall "memcpy" :pointer destination
                              :pointer (cl-wuffs.bindings:foreign-image-pixels foreign-image)
                              :size length :pointer)))
    (make-image :pixels pixels
                :width (cl-wuffs.bindings:foreign-image-width foreign-image)
                :height (cl-wuffs.bindings:foreign-image-height foreign-image)
                :stride (cl-wuffs.bindings:foreign-image-stride foreign-image))))

(defun decode-animation (input)
  (let ((octets (ensure-octets (input-octets input))))
    (multiple-value-bind (foreign-animation status message)
        (cl-wuffs.bindings:decode-animation octets)
      (unless (zerop status)
        (error (if (= status 1) 'unknown-format 'decode-error)
               :message (or message "Wuffs could not decode the animation.")))
      (unwind-protect
           (let* ((count (cffi:foreign-slot-value foreign-animation
                                                   '(:struct cl-wuffs.bindings::foreign-animation)
                                                   'cl-wuffs.bindings::frame-count))
                  (frames-pointer (cffi:foreign-slot-value foreign-animation
                                                           '(:struct cl-wuffs.bindings::foreign-animation)
                                                           'cl-wuffs.bindings::frames))
                  (durations-pointer (cffi:foreign-slot-value foreign-animation
                                                              '(:struct cl-wuffs.bindings::foreign-animation)
                                                              'cl-wuffs.bindings::durations-milliseconds))
                  (frames (make-array count)))
             (loop for index below count
                   for foreign-image = (cffi:mem-aptr frames-pointer
                                                       '(:struct cl-wuffs.bindings::foreign-image) index)
                   do (setf (aref frames index)
                            (make-animation-frame
                             :image (copy-foreign-image foreign-image)
                             :duration-milliseconds (cffi:mem-aref durations-pointer :uint64 index))))
             (make-animation :frames frames
                             :loop-count (let ((loops (cffi:foreign-slot-value foreign-animation
                                                                                  '(:struct cl-wuffs.bindings::foreign-animation)
                                                                                  'cl-wuffs.bindings::loop-count)))
                                           (if (and (= loops 0) (> count 1)) :infinite loops))))
        (cl-wuffs.bindings:free-animation foreign-animation)))))

(defun zip-u16 (octets offset)
  (logior (aref octets offset) (ash (aref octets (+ offset 1)) 8)))

(defun zip-u32 (octets offset)
  (logior (zip-u16 octets offset) (ash (zip-u16 octets (+ offset 2)) 16)))

(defun zip-octets-string (octets start length)
  (map 'string #'code-char (subseq octets start (+ start length))))

(defun zip-fail (format-control &rest arguments)
  (error 'zip-error :message (apply #'format nil format-control arguments)))

(defun zip-check-range (octets start length)
  (unless (and (<= 0 start) (<= 0 length) (<= (+ start length) (length octets)))
    (zip-fail "ZIP record exceeds archive bounds.")))

(defun zip-find-eocd (octets)
  (loop for offset downfrom (- (length octets) 22) to (max 0 (- (length octets) 65557))
        when (= #x06054B50 (zip-u32 octets offset)) return offset
        finally (zip-fail "ZIP end-of-central-directory record is missing.")))

(defun open-zip (input &key (max-entries 10000) (max-compressed-size (* 64 1024 1024))
                           (max-decompressed-size (* 256 1024 1024))
                           (max-total-decompressed-size (* 1024 1024 1024)))
  (let* ((octets (ensure-octets (input-octets input)))
         (eocd (zip-find-eocd octets)))
    (zip-check-range octets eocd 22)
    (let ((disk (zip-u16 octets (+ eocd 4)))
          (central-disk (zip-u16 octets (+ eocd 6)))
          (entries (zip-u16 octets (+ eocd 10)))
          (central-size (zip-u32 octets (+ eocd 12)))
          (central-offset (zip-u32 octets (+ eocd 16))))
      (when (or (/= disk 0) (/= central-disk 0)) (zip-fail "Multi-disk ZIP archives are unsupported."))
      (when (or (= entries #xFFFF) (= central-size #xFFFFFFFF) (= central-offset #xFFFFFFFF)
                (and (>= eocd 20) (= #x07064B50 (zip-u32 octets (- eocd 20)))))
        (zip-fail "Zip64 archives are unsupported."))
      (when (> entries max-entries) (zip-fail "ZIP entry count exceeds the configured limit."))
      (zip-check-range octets central-offset central-size)
      (let ((cursor central-offset) (total 0) (result (make-array entries)))
        (loop for index below entries do
          (zip-check-range octets cursor 46)
          (unless (= #x02014B50 (zip-u32 octets cursor)) (zip-fail "Invalid ZIP central-directory entry."))
          (let* ((flags (zip-u16 octets (+ cursor 8)))
                 (method (zip-u16 octets (+ cursor 10)))
                 (crc (zip-u32 octets (+ cursor 16)))
                 (compressed (zip-u32 octets (+ cursor 20)))
                 (decompressed (zip-u32 octets (+ cursor 24)))
                 (name-length (zip-u16 octets (+ cursor 28)))
                 (extra-length (zip-u16 octets (+ cursor 30)))
                 (comment-length (zip-u16 octets (+ cursor 32)))
                 (local-offset (zip-u32 octets (+ cursor 42)))
                 (record-length (+ 46 name-length extra-length comment-length)))
            (zip-check-range octets cursor record-length)
            (when (logbitp 0 flags) (zip-fail "Encrypted ZIP entries are unsupported."))
            (unless (member method '(0 8)) (zip-fail "Unsupported ZIP compression method ~D." method))
            (when (> compressed max-compressed-size) (zip-fail "ZIP entry compressed size exceeds the configured limit."))
            (when (> decompressed max-decompressed-size) (zip-fail "ZIP entry decompressed size exceeds the configured limit."))
            (incf total decompressed)
            (when (> total max-total-decompressed-size) (zip-fail "ZIP total decompressed size exceeds the configured limit."))
            (setf (aref result index)
                  (make-zip-entry :name (zip-octets-string octets (+ cursor 46) name-length)
                                  :flags flags :method method :crc32 crc :compressed-size compressed
                                  :decompressed-size decompressed :local-offset local-offset))
            (incf cursor record-length)))
        (make-zip-archive :octets octets :entries result :max-compressed-size max-compressed-size
                          :max-decompressed-size max-decompressed-size
                          :max-total-decompressed-size max-total-decompressed-size)))))

(defun zip-entry-by-name (archive name)
  (or (find name (zip-archive-entries archive) :key #'zip-entry-name :test #'string=)
      (zip-fail "ZIP entry ~S does not exist." name)))

(defun zip-entries (archive)
  (unless (typep archive 'zip-archive) (error 'type-error :datum archive :expected-type 'zip-archive))
  (zip-archive-entries archive))

(defun read-zip-entry (archive entry-or-name)
  (unless (typep archive 'zip-archive) (error 'type-error :datum archive :expected-type 'zip-archive))
  (let* ((entry (if (typep entry-or-name 'zip-entry) entry-or-name
                    (zip-entry-by-name archive entry-or-name)))
         (octets (zip-archive-octets archive))
         (offset (zip-entry-local-offset entry)))
    (zip-check-range octets offset 30)
    (unless (= #x04034B50 (zip-u32 octets offset)) (zip-fail "Invalid ZIP local-file header."))
    (let* ((name-length (zip-u16 octets (+ offset 26)))
           (extra-length (zip-u16 octets (+ offset 28)))
           (data-offset (+ offset 30 name-length extra-length))
           (compressed-size (zip-entry-compressed-size entry)))
      (zip-check-range octets data-offset compressed-size)
      (let ((compressed (subseq octets data-offset (+ data-offset compressed-size))))
        (let ((output (if (= (zip-entry-method entry) 0)
                          compressed
                          (let ((decoder (make-decompressor :deflate)))
                            (unwind-protect
                                 (apply #'concatenate '(vector (unsigned-byte 8))
                                        (append (loop for octet across compressed
                                                      collect (decompress-chunk decoder
                                                                                (make-array 1 :element-type '(unsigned-byte 8)
                                                                             :initial-contents (list octet))))
                                                (list (finish-decompressor decoder))))
                              (close-decompressor decoder))))))
          (unless (= (length output) (zip-entry-decompressed-size entry))
            (zip-fail "ZIP entry decompressed size does not match its directory."))
          (unless (= (crc32 output) (zip-entry-crc32 entry))
            (zip-fail "ZIP entry CRC-32 does not match its directory."))
          output)))))

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
