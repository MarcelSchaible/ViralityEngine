(in-package #:virality.engine)

(defstruct (uuid (:constructor %make-uuid))
  version
  (variant :rfc-4122)
  (low 0 :type (unsigned-byte 64))
  (high 0 :type (unsigned-byte 64)))

(u:define-printer (uuid stream)
  (format stream "~a" (uuid->string uuid)))

(defmacro write-uuid-chunk (string count offset bits word)
  `(setf
    ,@(loop :for i :below count
            :collect `(aref ,string ,(+ offset i))
            :collect `(aref "0123456789ABCDEF"
                            (ldb (byte 4 ,(- bits (* i 4))) ,word)))))

(defun uuid->string (uuid)
  (declare (optimize speed))
  (check-type uuid uuid)
  (let ((high (uuid-high uuid))
        (low (uuid-low uuid))
        (string (make-string 36 :element-type 'base-char)))
    (locally (declare (optimize (safety 0)))
      (psetf (aref string 8) #\-
             (aref string 13) #\-
             (aref string 18) #\-
             (aref string 23) #\-)
      (write-uuid-chunk string 8 0 60 high)
      (write-uuid-chunk string 4 9 28 high)
      (write-uuid-chunk string 4 14 12 high)
      (write-uuid-chunk string 4 19 60 low)
      (write-uuid-chunk string 12 24 44 low))
    string))

(defun string->uuid (string)
  (check-type string (simple-string 36))
  (flet ((parse-variant (bits)
           (cond
             ((not (logbitp 2 bits))
              :reserved/ncs)
             ((not (logbitp 1 bits))
              :rfc-4122)
             ((not (logbitp 0 bits))
              :reserved/microsoft)
             (t
              :reserved/future))))
    (declare (inline parse-variant %make-uuid))
    (let* ((string (remove #\- string))
           (high (parse-integer string :end 16 :radix 16))
           (low (parse-integer string :start 16 :radix 16)))
      (declare (type (unsigned-byte 64) high low))
      (%make-uuid :version (ldb (byte 4 12) high)
                  :variant (parse-variant (ldb (byte 3 61) low))
                  :low low
                  :high high))))

(defun make-uuid/v4 ()
  (declare (optimize speed)
           (inline %make-uuid))
  (symbol-macrolet ((rand (random #.(expt 2 64)
                                  (load-time-value (make-random-state t)))))
    (%make-uuid :version 4
                :low (dpb #b100 (byte 3 61) rand)
                :high (dpb 4 (byte 4 12) rand))))

(defun make-uuid/nil ()
  (declare (optimize speed)
           (inline %make-uuid))
  (%make-uuid))

(defun make-uuid (&key (version 4))
  (declare (optimize speed))
  (case version
    (4 (make-uuid/v4))
    (t (make-uuid/nil))))
