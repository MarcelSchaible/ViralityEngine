(in-package #:virality.gpu)

(defclass shader-block ()
  ((%id :reader id
        :initarg :id)
   (%name :reader name
          :initarg :name)
   (%type :reader block-type
          :initarg :type)
   (%layout :reader layout
            :initarg :layout)
   (%program :reader program
             :initarg :program)
   (%binding-point :reader binding-point
                   :initform 0)))

(u:define-printer (shader-block stream :type nil)
  (format stream "BLOCK ~s" (id shader-block)))

(defun get-block-type (struct)
  (cond
    ((has-qualifier-p struct :ubo)
     (values :uniform :ubo))
    ((has-qualifier-p struct :ssbo)
     (values :buffer :ssbo))))

(defun make-block (program layout)
  (let* ((uniform (uniform layout))
         (id (ensure-keyword (varjo:name uniform)))
         (name (varjo.internals:safe-glsl-name-string id))
         (type (varjo:v-type-of uniform)))
    (u:mvlet ((block-type buffer-type (get-block-type type)))
      (setf (u:href (blocks program) (cons block-type id))
            (make-instance 'shader-block
                           :id id
                           :name (format nil "_~a_~a" buffer-type name)
                           :type block-type
                           :layout layout
                           :program program)))))

(defun create-block-alias (block-type block-id program-name block-alias)
  (let* ((program-name (name (find-program program-name)))
         (aliases (v::meta 'block-aliases))
         (block (%find-block program-name block-type block-id)))
    (if (u:href aliases block-alias)
        (error "The block alias ~s is already in use." block-alias)
        (setf (u:href aliases block-alias) block))))

(defun delete-block-alias (block-alias &key unbind-block)
  (when unbind-block
    (unbind-block block-alias))
  (remhash block-alias (v::meta 'block-aliases)))

(defun store-blocks (program stage)
  (dolist (layout (collect-layouts stage))
    (make-block program layout)))

(defun %find-block (program-name block-type block-id)
  (if (keywordp block-id)
      (a:when-let ((program (find-program program-name)))
        (u:href (blocks program) (cons block-type block-id)))
      (error "Block ID must be a keyword symbol: ~a" block-id)))

(defun find-block (block-alias)
  (let ((aliases (v::meta 'block-aliases)))
    (u:href aliases block-alias)))

(defun block-binding-valid-p (block binding-point)
  (let ((bindings (v::meta 'block-bindings)))
    (every
     (lambda (x)
       (varjo:v-type-eq
        (varjo:v-type-of (uniform (layout block)))
        (varjo:v-type-of (uniform (layout x)))))
     (u:href bindings (block-type block) binding-point))))

(defmethod %bind-block ((block-type (eql :uniform)) block binding-point)
  (let* ((program-id (id (program block)))
         (index (%gl:get-uniform-block-index program-id (name block))))
    (%gl:uniform-block-binding program-id index binding-point)))

(defmethod %bind-block ((block-type (eql :buffer)) block binding-point)
  (let* ((program-id (id (program block)))
         (index (gl:get-program-resource-index
                 program-id :shader-storage-block (name block))))
    (%gl:shader-storage-block-binding program-id index binding-point)))

(defun bind-block (block-alias binding-point)
  "Bind a block referenced by BLOCK-ALIAS to a binding point."
  (let* ((bindings (v::meta 'block-bindings))
         (block (find-block block-alias)))
    (or (block-binding-valid-p block binding-point)
        (error "Cannot bind a block to a binding point with existing blocks of ~
                a different layout."))
    (pushnew block (u:href bindings (block-type block) binding-point))
    (%bind-block (block-type block) block binding-point)
    (setf (slot-value block '%binding-point) binding-point)))

(defun unbind-block (block-alias)
  "Unbind a block with the alias BLOCK-ALIAS."
  (bind-block block-alias 0))

(defun rebind-blocks (programs)
  "Rebind all blocks that are members of PROGRAMS."
  (flet ((rebind (block-type)
           (let* ((bindings (v::meta 'block-bindings))
                  (table (u:href bindings block-type)))
             (u:do-hash-values (blocks table)
               (dolist (block blocks)
                 (with-slots (%program %binding-point) block
                   (when (member (name %program) programs)
                     (%bind-block :buffer block %binding-point))))))))
    (rebind :uniform)
    (rebind :buffer)
    (u:noop)))
