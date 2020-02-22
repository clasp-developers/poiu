":" ; : "-*- Lisp -*-" \
; case "${1:-sbcl}" in (sbcl) sbcl --load "$0" \
;; (allegro) alisp -L "$0" \
;; (clasp) clasp -l "$0" \
;; (ccl) ../single-threaded-ccl/stccl --load "$0" \
;; (clisp) clisp -i "$0" \
;; (*) echo "Unrecognized/unsupported Lisp: $1" ; exit 42
;; esac 2>&1 | tee foo ; exit

;; NB:
;; 1- You need to download cxml and its dependencies.
;;    Quicklisp can do it for you: search for Quicklisp below.
;; 2- To check that the tests pass without POIU,
;;    just comment out every line where "poiu" appears below.


;;; First, bootstrap by loading the latest ASDF itself, if not already present.
(in-package :cl-user)

;;;#+clasp(setq core:*echo-repl-read* t)

(setf *load-verbose* nil
      *load-print* nil
      *compile-verbose* nil
      *compile-print* nil)

(ignore-errors (funcall 'require "asdf"))
#-asdf2 (load "../asdf/build/asdf.lisp")

#+(or)(asdf:load-system :asdf)
;;(push #P"/Users/meister/Development/clasp/src/lisp/modules/asdf/uiop/" asdf:*central-registry*)
(in-package :asdf)

;;; Second, some configuration.

;; OVERRIDE THE VARIABLE BELOW TO REFLECT WHERE YOU PUT THE TEST FILES
;; e.g. use a defparameter in cl-user before you load this file, or edit the line below.
#+(or)(defvar cl-user::*bastiat* (uiop:subpathname (user-homedir-pathname) "Development/bastiat.org/"))
;; PS: DO NOT forget the ending / for a directory in Lisp namestring syntax,
;; or you'll have "interesting" problems.

;; Use Quicklisp-loaded libraries when available.
;; NB: You must still prime Quicklisp with (ql:quickload :cxml) to have it download the sources;
;; but you can rm -rf ~/.cache/common-lisp/ afterwards to clean away the fasls.
(if-let (qldir (probe-file (subpathname (user-homedir-pathname) "quicklisp/setup.lisp")))
  (load qldir))


;;; Third, load POIU.

(asdf:load-asd "/Users/meister/Development/poiu/poiu.asd")
(asdf:load-system :poiu)
(format *error-output* "~&ASDF ~A  POIU ~A~%" (asdf-version) (component-version (find-system "poiu")))
(assert (poiu/fork:can-fork-p))

(setf *load-verbose* t
      *load-print* t
      *compile-verbose* t
      *compile-print* t)

;;; Fourth, enable some debugging.
;; uiop-directory assumes UIOP 3.3.2.5 or later, despite an initial ASDF possibly earlier than that.
#-clasp(uiop:uiop-debug :utility-file (uiop:subpathname (uiop:uiop-directory) "contrib/debug.lisp"))

#+(or)
(trace
 record-dependency operate make-plan perform-plan
 action-status (setf action-status) action-already-done-p
 mark-as-done
 poiu/background-process::process-return poiu/background-process::process-result ;; action-result-file
 input-files output-files file-write-date
 component-operation-time mark-operation-done
 poiu/background-process::call-queue/forking poiu/background-process::posix-waitpid
 perform perform-with-restarts
 compile-file load
 poiu::call-recording-breadcrumbs
)
;;#+allegro (trace posix-fork posix-wexitstatus posix-waitpid excl::getpid quit)
;;#+clisp (trace asdf::read-file-form asdf::read-file-forms)

;;; Fifth, run the actual test
(block nil
  (handler-bind ((error #'(lambda (condition)
                            (format! t "~&ERROR:~%~A~%" condition)
                            (print-backtrace :stream *standard-output*)
                            (format! t "~&ERROR:~%~A~%" condition)
                            (return))))
    (load-system
     :cxml ;; :verbose t
     :plan-class 'poiu:parallel-plan :breadcrumbs-to "/tmp/breadcrumbs.text"
     :force :all)
    (funcall (uiop:find-symbol* :process-command-line :exscribe)
             `("-I" ,(namestring cl-user::*bastiat*)
               "-o" "-" "-H" ,(namestring (subpathname cl-user::*bastiat* "en/index.scr"))))))

;;; Sixth and lastly, print some statistics and quit.
(format t "~&~S~%" (uiop:implementation-identifier))
(format t "~&Compiled with as many as ~D forked subprocesses~%" poiu/fork:*max-actual-forks*)

(quit 0)
