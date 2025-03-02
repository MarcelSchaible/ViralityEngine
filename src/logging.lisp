(in-package #:virality.engine)

(defun enable-logging (core)
  (let ((context (context core)))
    (unless (log:thread log:*global-controller*)
      (log:start log:*global-controller*))
    (when (option context :log-repl-enabled)
      (setf (log:repl-level) (option context :log-level)
            (log:repl-categories) (option context :log-repl-categories)))
    (a:when-let ((log-debug (find-resource context :log-debug)))
      (ensure-directories-exist log-debug)
      (log:define-pipe ()
        (log:level-filter :level :debug)
        (log:file-faucet :file log-debug)))
    (a:when-let ((log-error (find-resource context :log-error)))
      (ensure-directories-exist log-error)
      (log:define-pipe ()
        (log:level-filter :level :error)
        (log:file-faucet :file log-error)))))
