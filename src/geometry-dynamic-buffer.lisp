(in-package #:virality.geometry)

(defgeneric get-group-buffer-names (spec group))

(defmethod get-group-buffer-names (spec (group group/interleaved))
  (list (name group)))

(defmethod get-group-buffer-names (spec (group group/separate))
  (let (names)
    (u:do-hash-keys (k (attributes group))
      (push (a:format-symbol :keyword "~a/~a" (name group) k) names))
    (nreverse names)))

(defun make-buffers (geometry)
  (with-slots (%layout %buffers %buffer-names) geometry
    (with-slots (%groups %group-order) %layout
      (setf %buffers (make-array 0 :fill-pointer 0 :adjustable t))
      (dolist (group-name %group-order)
        (let ((group (u:href %groups group-name)))
          (dolist (name (get-group-buffer-names %layout group))
            (let ((buffer (gl:gen-buffer)))
              (setf (u:href %buffer-names name) buffer)
              (vector-push-extend buffer %buffers))))))))

(defun configure-buffers (geometry)
  (with-slots (%groups %group-order) (layout geometry)
    (let ((buffer-offset 0)
          (attr-offset 0))
      (dolist (group-name %group-order)
        (let* ((group (u:href %groups group-name))
               (buffer-count (get-group-buffer-count group))
               (group-buffers (make-array
                               buffer-count
                               :displaced-to (buffers geometry)
                               :displaced-index-offset buffer-offset))
               (attr-count (length (attribute-order group))))
          (dotimes (i attr-count)
            (gl:enable-vertex-attrib-array (+ attr-offset i)))
          (configure-group group attr-offset group-buffers)
          (incf buffer-offset buffer-count)
          (incf attr-offset attr-count))))))

(defun get-buffer-size (buffer)
  (* (length buffer)
     (etypecase buffer
       ((simple-array (signed-byte 8) *) 1)
       ((simple-array (unsigned-byte 8) *) 1)
       ((simple-array (signed-byte 16) *) 2)
       ((simple-array (unsigned-byte 16) *) 2)
       ((simple-array (signed-byte 32) *) 4)
       ((simple-array (unsigned-byte 32) *) 4)
       ((simple-array single-float *) 4)
       ((simple-array double-float *) 8))))

(defmacro with-buffer ((ptr size vector) &body body)
  (a:with-gensyms (sv)
    `(static-vectors:with-static-vector
         (,sv (length ,vector)
              :element-type (array-element-type ,vector)
              :initial-contents ,vector)
       (let ((,size (get-buffer-size ,vector))
             (,ptr (static-vectors:static-vector-pointer ,sv)))
         ,@body))))

(defun fill-geometry-buffer (geometry buffer-name data
                             &key (usage :dynamic-draw))
  (with-buffer (ptr size (u:flatten-numbers data))
    (let ((buffer (u:href (buffer-names geometry) buffer-name)))
      (gl:bind-buffer :array-buffer buffer)
      (%gl:buffer-data :array-buffer size ptr usage))))
