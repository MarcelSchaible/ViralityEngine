(in-package #:virality.engine)

;;;; This file handles the framework for querying actors and components by the
;;;; different ID types, such is ID, UUID, and DISPLAY-ID.

;;; Class definition
;;; This is a superclass that can be added to any object to bring in slots for
;;; identifying the object with one of the various types of identification
;;; types. Currently, this is applied to actors and components.

(defclass queryable ()
  ((%context :reader context
             :initarg :context)
   (%id :reader id
        :initarg :id
        :initform nil)
   (%uuid :reader uuid
          :initform (make-uuid))
   (%display-id :accessor display-id
                :initarg :display-id
                :initform "No name")))

(u:define-printer (queryable stream)
  (format stream "~a" (display-id queryable)))

;;; Query table management

(defun register-object-uuid (object)
  (a:if-let ((table (objects-by-uuid (tables (core (context object)))))
             (uuid (uuid object)))
    (symbol-macrolet ((found (u:href table uuid)))
      (u:if-found (found (u:href table uuid))
                  (error "A UUID collision occured between the following ~
                           objects:~%~s~%~s."
                         found object)
                  (setf (u:href table uuid) object)))
    (error "Object ~s has no UUID. This is a bug and should be reported."
           object)))

(defmethod register-object-id ((object actor:actor))
  (a:when-let ((table (actors-by-id (tables (core (context object)))))
               (id (id object)))
    (unless (u:href table id)
      (setf (u:href table id) (u:dict)))
    (setf (u:href table id object) object)))

(defmethod register-object-id ((object component))
  (a:when-let ((table (components-by-id (tables (core (context object)))))
               (id (id object)))
    (unless (u:href table id)
      (setf (u:href table id) (u:dict)))
    (setf (u:href table id object) object)))

(defun deregister-object-uuid (object)
  (remhash (uuid object)
           (objects-by-uuid (tables (core (context object))))))

(defmethod deregister-object-id ((self actor:actor))
  (a:when-let ((table (actors-by-id (tables (core (context self)))))
               (id (id self)))
    (symbol-macrolet ((actors (u:href table id)))
      (remhash self actors)
      (unless (plusp (hash-table-count actors))
        (remhash id table)))))

(defmethod deregister-object-id ((self component))
  (a:when-let ((table (components-by-id (tables (core (context self)))))
               (id (id self)))
    (symbol-macrolet ((components (u:href table id)))
      (remhash self components)
      (unless (plusp (hash-table-count components))
        (remhash id table)))))

;;; Public API

(defmethod (setf id) (value (object queryable))
  "Change the ID of a queryable object."
  (with-slots (%id) object
    (when %id
      (deregister-object-id object))
    (setf %id value)
    (register-object-id object)))

(defmethod find-by-uuid (context (uuid uuid))
  "Return the object instance with the given `UUID` object."
  (let ((table (objects-by-uuid (tables (core context)))))
    (u:href table uuid)))

(defmethod find-by-uuid (context (uuid string))
  "Return the object instance with the given `UUID` string representation."
  (let ((table (objects-by-uuid (tables (core context)))))
    (u:href table (string->uuid uuid))))

(defun find-actors-by-id (context id)
  "Return a list of all actor instances with the given `ID`."
  (a:when-let* ((table (actors-by-id (tables (core context))))
                (by-id (u:href table id)))
    (u:hash-values by-id)))

(defun find-components-by-id (context id)
  "Return a list of all component instances with the given `ID`."
  (a:when-let* ((table (components-by-id (tables (core context))))
                (by-id (u:href table id)))
    (u:hash-values by-id)))
