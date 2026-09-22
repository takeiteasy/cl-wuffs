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

(defparameter +format-map+
  '((1112363040 . :bmp) (1195984416 . :gif) (1313420576 . :nie)
    (1347307296 . :png) (1413564448 . :tga) (1463966288 . :wbmp)
    (1113215520 . :bz2) (1197031456 . :gz) (1514942786 . :zlib)))

(defun ensure-octets (octets)
  (unless (typep octets '(array (unsigned-byte 8) (*)))
    (error 'type-error :datum octets :expected-type '(array (unsigned-byte 8) (*))))
  octets)

(defun detect-format (octets)
  (let* ((data (ensure-octets octets))
         (fourcc (cl-wuffs.bindings:detect-format data))
         (format (cdr (assoc fourcc +format-map+))))
    (or format (error 'unknown-format :message "Unsupported or unrecognized data."))))

(defun inspect (octets)
  (list :format (detect-format octets)))

(defun decode (octets)
  (let ((format (detect-format octets)))
    (unless (member format '(:bmp :gif :nie :png :tga :wbmp))
      (error 'decode-error :message "The detected format is not an image decoder."))
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
