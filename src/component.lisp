(in-package #:virality.engine)

(defclass component (queryable)
  ((%type :reader component-type
          :initarg :type)
   (%state :accessor state
           :initarg :state
           :initform :initialize)
   (%actor :accessor actor
           :initarg :actor
           :initform nil)
   (%ttl :accessor ttl
         :initarg :ttl
         :initform 0)
   (%initializer :accessor initializer
                 :initarg :initializer
                 :initform nil)
   (%attach/detach-event-queue :accessor attach/detach-event-queue
                               :initarg :attach/detach-event-queue
                               :initform (queues:make-queue :simple-queue)))
  (:metaclass component-class))

(v::clear-annotations 'component)

(defun qualify-component (core component-type)
  "This function tries to resolve the COMPONENT-TYPE symbol into a potentially
different packaged symbol of the same name that corresponds to a component
definition in that package. The packages are searched in the order they are are
defined in a toposort of the graph category COMPONENT-PACKAGE-ORDER. The result
should be a symbol suitable for MAKE-INSTANCE in all cases, but in the case of
mixin superclasses, it might not be desireable.

NOTE: If the component-type is a mixin class/component that is a superclass to a
component, then the first external to the package superclass definition found in
the package search order will be returned as the package qualified symbol.

NOTE: This function can not confirm that a symbol is a component defined by
DEFINE-COMPONENT. It can only confirm that the symbol passed to it is a
superclass of a DEFINE-COMPONENT form (up to but not including the COMPONENT
superclass type all components have), or a component created by the
DEFINE-COMPONENT form."
  (let ((search-table (component-search-table (tables core)))
        (component-type/class (find-class component-type nil))
        (base-component-type/class (find-class 'component))
        (graph (u:href (analyzed-graphs core) 'component-package-order)))
    (u:when-found (pkg-symbol (u:href search-table component-type))
      (return-from qualify-component pkg-symbol))
    (if (or (null component-type/class)
            (not (subtypep (class-name component-type/class)
                           (class-name base-component-type/class))))
        (dolist (potential-package (toposort graph))
          (let ((potential-package-name (second potential-package)))
            (dolist (pkg-to-search (u:href (pattern-matched-packages
                                            (annotation graph))
                                           potential-package-name))
              (u:mvlet ((symbol kind (find-symbol (symbol-name component-type)
                                                  pkg-to-search)))
                (when (and (eq kind :external)
                           (find-class symbol nil))
                  (setf (u:href search-table component-type) symbol)
                  (return-from qualify-component symbol))))))
        component-type)))

(defmethod make-component (context component-type &rest args)
  (a:if-let ((type (qualify-component (core context) component-type)))
    (apply #'make-instance type :type type :context context args)
    (error "Could not qualify the component type ~s." component-type)))

(defmethod initialize-instance :after ((instance component) &key)
  (register-object-uuid instance)
  (register-object-id instance))

(defun component/preinit->init (component)
  (a:when-let ((thunk (initializer component)))
    (funcall thunk)
    (setf (initializer component) nil))
  (let* ((core (core (context component)))
         (type (canonicalize-component-type (component-type component)
                                            core)))
    (with-slots (%tables) core
      (type-table-drop component type (component-preinit-by-type-view %tables))
      (setf (type-table type (component-init-by-type-view %tables))
            component))))

(defun component/init->active (component)
  (let* ((core (core (context component)))
         (type (canonicalize-component-type (component-type component) core)))
    (with-slots (%tables) core
      (type-table-drop component type (component-init-by-type-view %tables))
      (setf (state component) :active
            (type-table type (component-active-by-type-view %tables))
            component))))

(defmethod destroy-after-time ((thing component) &key (ttl 0))
  (let* ((core (core (context thing)))
         (table (u:href (component-predestroy-view (tables core)))))
    (setf (ttl thing) (and ttl (max 0 ttl)))
    (if ttl
        (setf (u:href table thing) thing)
        ;; If the TTL is stopped, we want to remove the component from the
        ;; pre-destroy view!
        (remhash thing table))))

(defun component/init-or-active->destroy (component)
  (let* ((core (core (context component)))
         (type (canonicalize-component-type (component-type component) core)))
    (unless (plusp (ttl component))
      (with-slots (%tables) core
        (setf (state component) :destroy
              (type-table type (component-destroy-by-type-view %tables))
              component)
        (remhash component (component-predestroy-view %tables))
        (unless (type-table-drop component
                                 type
                                 (component-active-by-type-view %tables))
          (type-table-drop component
                           type
                           (component-preinit-by-type-view %tables)))))))

(defun component/destroy->released (component)
  (let* ((core (core (context component)))
         (type (canonicalize-component-type (component-type component) core)))
    (type-table-drop component
                     type
                     (component-destroy-by-type-view (tables core)))
    (detach-component (actor component) component)
    (deregister-object-uuid component)
    (deregister-object-id component)))

(defun component/countdown-to-destruction (component)
  (when (plusp (ttl component))
    (decf (ttl component) (frame-time (context component)))))

(defun enqueue-attach-event (component actor)
  (queues:qpush (attach/detach-event-queue component) (list :attached actor)))

(defun enqueue-detach-event (component actor)
  (queues:qpush (attach/detach-event-queue component) (list :detached actor)))

(defun dequeue-attach/detach-event (component)
  ;; NOTE: Returns NIL, which is not in our domain, when empty.
  (queues:qpop (attach/detach-event-queue component)))

(defun component/invoke-attach/detach-events (component)
  (loop :for (event-kind actor) = (queues:qpop (attach/detach-event-queue
                                                component))
        :while event-kind
        :do (ecase event-kind
              (:attached
               (on-component-attach component actor))
              (:detached
               (on-component-detach component actor)))))

(defun attach-component (actor component)
  (let* ((core (core (context actor)))
         (qualified-type (qualify-component core (component-type component))))
    (detach-component actor component)
    (enqueue-attach-event component actor)
    (setf (actor component) actor
          (u:href (actor::components actor) component) component)
    (push component (u:href (actor::components-by-type actor) qualified-type))))

(defun attach-components (actor &rest components)
  (dolist (component components)
    (attach-component actor component)))

(defun detach-component (actor component)
  "If COMPONENT is contained in the ACTOR. Remove it. Otherwise, do nothing."
  (when (remhash component (actor::components actor))
    (symbol-macrolet ((typed-components
                        (u:href (actor::components-by-type actor)
                                (component-type component))))
      (enqueue-detach-event component actor)
      (setf (actor component) nil)
      (setf typed-components
            (remove-if (lambda (x) (eq x component)) typed-components)))))

(defun components-by-type (actor component-type)
  "Get a list of all components of type COMPONENT-TYPE for the given ACTOR."
  (u:href (actor::components-by-type actor)
          (qualify-component (core (context actor)) component-type)))

(defun component-by-type (actor component-type)
  "Get the first component of type COMPONENT-TYPE for the given ACTOR.
Returns the rest of the components as a secondary value if there are more than
one of the same type."
  (let* ((core (core (context actor)))
         (qualified-type (qualify-component core component-type))
         (components (components-by-type actor qualified-type)))
    (values (first components)
            (rest components))))

;;; User protocol

(defgeneric shared-storage-metadata (component-name &optional namespace)
  (:method ((component-name symbol) &optional namespace)
    (declare (ignore namespace))))
