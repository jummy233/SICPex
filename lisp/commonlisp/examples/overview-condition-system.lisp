;;;; condition system

;; Three components of a condition system
;; 1. signaling a condition
;; 2. handling a condition
;; 3. recover from a condition

;;; condition system is a more powerful try catch mechanism.
;;; try catch allows you to attempt execute a block of code,
;;; if some situation happen, the block can voluntarily throw
;;; an exception. The exception will propagage upward to it's
;;; caller until a catch block is found.
;;; Then, the control flow is hand over to that catch block,
;;; code in the block get executed, and the original stack frame
;;; get unwind.
;;; Getting unwind means the stack get destroyed. But all resources
;;; will be released before destroy everything in the stack.

;;; Common lisp is different from ordinary languages in the sense that
;;; it heavily use the repl feature to develop interactively. It has
;;; the mechanism called restart, whenever something exceptions happen,
;;; the repl will bring you to the restrat menu, which gives you a list
;;; of possible way to handle this situation. Options in the list are either
;;; predefined or defined by the user.
;;; You decide how to handle the condition, and the repl will restart the
;;; function again.

;;; To have a error catching mechansim that supports this concept of
;;; restarting, common lisp's condition system made several differemt
;;; design choces.

;;; First, like most other languages, conditions (exceptions) are object.
;;; more specficially it's a CLOS object with arbitrary slots. We can carry
;;; various information with condition, change a condition at runtime, and
;;; do everything else we can do with an object.

;;; The most basic way to throwing a condition is to call (error 'condt ..)
;;; this will throw a condtion and propagate upwards like in a conventional
;;; expcetion system.
;;; If the expression is controled by a (handler-case e c .. ) somewhere
;;; in it's backtrace, and the condtion is capture by the handler-case
;;; expression, the corresponding handler code will be executed. After
;;; that's done, the orgina lstack is unwinded. This works like normal
;;; try catch.
;;; Note in this case the handler code is defined in the handler-case
;;; expression, in another word, the caller defines what to do.

;;; Not like convential exception handling, in condition system we can
;;; define the counter action in the callee as well. To do so
;;; we define possible "restarts" in a (restart-case) expression
;;; in the callee. A restart-case can define several restarts, each with
;;; a unique name. Note restart-case doesn't bind restart to a particular
;;; condition, it just define the possible reaction.
;;; To use these restarts defined in the callee, we use handler-bind and
;;; invoke-restart from the caller.
;;; The mechanism is similar to handler-case, we match on the case for
;;; handling the condition, and call (invoke-restart 'restart) to choose
;;; the restart provided by the callee.

;;; What's the benefit of this more complex system comparing with a simple
;;; try catch system?
;;; Try-catch separate the exception signaling and exception handling into
;;; two parts. While condition system breaks it into three parts:
;;;   1. signaling a condition
;;;        this happens at the callee level. When situations emerge
;;;        we call (error), a new condition get created and propagated
;;;   2. handling a condition
;;;        for handler-case:
;;;           execute the handling code, unwind stack
;;;
;;;        for handler-bind:
;;;           execute the handling code, doesn't unwind the stack
;;;   3. recover from a condition
;;;        for handler-case:
;;;           keep going, doesn't recover from the exception
;;;        for handler-bind:
;;;           use invoke-restart to choose a restart to run.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ignore an error
(ignore-errors (/ 3 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; catching a condition (handler-case)

;;; (handler-case (code that errors out)
;;;   (condition-type (the-condition) (code)
;;;   (condition-type (the-condition) (code)
;;;   ...
;;;   )
;;; It's like typecase but work for conditions.

(handler-case (/ 3 0)
  (error (c)  ; error is the general condion, c is the conditon itself
         (format t "We caught a condition. ~&")
         (values 0 c)))   ; return value

;;; some examples of catching the most generic errors
(defun division-1 (a b)
  (handler-case (/ a b) ; note if no exception happens it just return
    (division-by-zero
      (c)
      (format t "Division by zero! ~%")
      (values 0 c))
    (error
      (c)
      (format t "Some generic errors ~%")
      (values 0 c))))
(division-1 2 1) ;; 2
(division-1 2 0) ;; error caught

(defun index (xs n)
  (check-type xs sequence)
  (handler-case (elt xs n)
    (error
      (c)
      (format t "error when trying  to index the sequence")
      (values n c))))
(index '(1 2 3) 2)  ;; 3
(index '(1 2 3) 10) ;; error caught

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; handler-bind (actually use the restart mechansim)
;;; handler bind does not unwind the stack!

(define-condition my-div-by-zero (error)
  (:documentation "my division by zero condition")
  ((dividend :initarg :dividend   ;; a condtion can have any slots
             :initform nil
             :reader dividend)))  ;; :reader create a getter

;; a condition generally behaves like an object
(let ((con (make-condition 'my-div-by-zero :dividend 3)))
  (equal (dividend con) 3))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; signaling (throwing) (error, warn, signal)

;;; error
;;; error is a `overloaded` functions (optional param)
;;;   1. (error "asd) singal a 'simple-error
;;;   2. (error 'error-type :message "Error message") throw a constom error

(defun my-div (a b)
  (if (= b 0)
    (error 'my-div-by-zero :dividend a)
    (/ a b)))

(handler-case (my-div 3 0)
  (my-div-by-zero
    (c)
    (format t "on I caught my own error")
    (values 0 c)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; restart

;;; assert
(defun not-1 (x)
  (assert (not (= x 1)))  ; this throw a condition that bring to restart
  x)

(defun not-2 (x &optional (y 0))
  (assert (not (= x 2))
          (y)             ;; optional arg in restart menu
          "You cannot be 2")
  x)

;;; restart-case

(defun div-restart (x y)
  (restart-case (/ x y)   ;; we define cases in restart-case
    (return-zero () ;; create a new restart called "return-zero"
                 :report "Return 0"
                 0)
    (divide-by-one ()
                   :report "Divide by 1"
                   (/ x 1))
    (set-new-divisor (value)
                     :report "Enter a new divisor"
                     :interactive (lambda ()
                                    (prompt-new-value "Please enter: "))
                     (div-restart x value))))

(defun prompt-new-value (prompt)
  (format *query-io* prompt)  ;; special stream to make user query
  (force-output *query-io*)
  (list (read *query-io*)))

(div-restart 3 0)


;;; restart prorammatically (handler-bind, invoke-restart)
;;; process:
;;;   1. invoke div-restart
;;;   2. restart cases get defined in div-restart
;;;   3. div-restart throw a condtion 'division-by-zero
;;;   4. it's propagated to div-and-handle-error, bind to
;;;      the corresponding case, invoke the 'divide-by-one
;;;      restart.
(defun div-and-handle-error (x y)
  (handler-bind     ;; capture restart conditons and choose what to do.
    ((division-by-zero
       (lambda (c)
         (format t "Got error ~a~%" c)
         (format t "will divide by 1 ~%")
         (invoke-restart 'divide-by-one))))
    (div-restart x y)))
(div-and-handle-error 3 0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some examples
;; (in-package :error-handling)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; define two errors
;;; Note that a new condition is a new type that can be checked
;;; by typep at the runtime.

(define-condition file-io-error (error)
  ((message :initarg :message :reader message)))

(define-condition another-file-io-error (error)
  ((message :initarg :message :reader message)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; handler-bind

;; simulate an io operation that might fail.
;; it throws like a normal language with try/catch, there is
;; no condition handler defined with the code, all error recovering
;; code are from the caller.
(defun fake-io (&key (fail nil fail-p) (message "Error!"))
  (cond
    ((not fail-p)
     (if (evenp (random 100))
         (error 'file-io-error :message "message")
         "success"))
    (fail (error 'another-file-io-error :message "message"))
    (t "success")))


;;; flush the io buffer:
;; finish-output, force-output, and clear-output

;;; lisp has muli value output
;; to obtain multiple values as a list you can wrap the function in
;; multiple-value-list. Similary to destruct multiple values reutrned
;; you can use multiple-value-bind to bind values with a name.

;; define a restart function
(defun read-new-value ()
  (format t "Enter a new value: ")
  (force-output)
  (multiple-value-list (eval (read))))

;; use restart when error happens.
;; these cases will be added into the debugger options so you can invoke.
;; (restart-case (form) (restart1) (restart2) ...)
(let ((fail t))
     (restart-case
       (fake-io :fail fail)  ;; expression to run
       ;; first handler we define
       (retry-without-errors (new-fail)
                             :report "Pass in a fail value"
                             :interactive read-new-value (setf fail new-fail)
                             (fake-io :fail fail))
       ;; second handler simply do nothing
       (do-nothing ()
                   :report "don't handle the error"
                   "done with it!")))
(fake-io)
(fake-io :fail t)
(fake-io :fail nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; we want to define handler to automatically handle
;;;; handler-case behaves like try-catch in other languages.
;; catching any conditions
(handler-case (/ 3 0)
  (error (c) (format t "We caught a condition ~&")
         (values 0 c)))

;; another way to catch all conditions with t
(handler-case
  (progn
    (format t "This won't work~&")
    (/ 3 0))
  (t (c)
     (format t "Got a condition ~a~%" c)
     (values 0 c) ) )

;; catching specific conditions
(handler-case (/ 3 0)
  (division-by-zero (c)
                    (format t "caught a division by zero condition  ~a~%" c)
                    (values 0 c)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; we define a new condition here
(define-condition on-zero-denominator (error)
  ((message :initarg :message :reader message)))

;; reciprocal will decide what conditon to throw, also it defines
;; some handler for that condition.
(defun reciprocal (n)
  (restart-case
    (if (/= n 0)
        (/ 1 n)
        (error 'on-zero-denominator :message "can't divide by zero"))
    (return-zero () :report "Just return 0" 0)
    (return-value (r) :report "Return another value" r)
    (recalc-using (v) :report "recalculate" (reciprocal v))
    (return-nil () nil)))

;; in this function we choose to ignore condition
;; but we also provide another possible way to handle any possible
;; condition, namely `just continue`
(defun list-of-reciprocals (array)
  (restart-case
    (mapcar #'reciprocal array)
    (just-continue () nil)))''

;; here we 'bind on-zero-denominator with a lambda handler.
;; in the handler it calls the lower level handler provided by reciprocol.
;; in this case, we choose to just return 0.
(defun print-reciprocals (array)
  (handler-bind
    ((on-zero-denominator
       #'(lambda (c)
           (format t "error signaled: ~a~%" (message c))
           (invoke-restart 'return-value 0))))
    (let (r)
      (setf r (list-of-reciprocal array))
      (dolist (x r)
        (format t "Reciprocal: ~a~%" x)))))
