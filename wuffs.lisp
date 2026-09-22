(in-package #:cl-wuffs)

(define-condition wuffs-error (error)
  ((message :initarg :message :reader wuffs-error-message))
  (:report (lambda (condition stream) (write-string (wuffs-error-message condition) stream))))

(define-condition unknown-format (wuffs-error) ())
(define-condition decode-error (wuffs-error) ())

(defstruct image
  (pixels (make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (*)))
  (width 0 :type (unsigned-byte 32))
  (height 0 :type (unsigned-byte 32))
  (stride 0 :type (unsigned-byte 32)))

(defun ensure-octets (octets)
  (unless (typep octets '(array (unsigned-byte 8) (*)))
    (error 'type-error :datum octets :expected-type '(array (unsigned-byte 8) (*))))
  octets)

(defun fourcc-keyword (fourcc)
  (intern (string-right-trim " "
                             (map 'string (lambda (shift)
                                           (code-char (ldb (byte 8 shift) fourcc)))
                                  '(24 16 8 0)))
          :keyword))

(defun detect-format (octets)
  (let* ((data (ensure-octets octets))
         (fourcc (cl-wuffs.bindings:detect-format data)))
    (if (plusp fourcc)
        (fourcc-keyword fourcc)
        (error 'unknown-format :message "Unsupported or unrecognized data."))))

(defun inspect (octets)
  (list :format (detect-format octets)))

(defun decode (octets)
  (progn
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
