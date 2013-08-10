;;; tiny.el --- Quickly generate linear ranges in Emacs

;; Copyright (C) 2013  Oleh Krehel

;; Author: Oleh Krehel <ohwoeowho@gmail.com>
;; URL: https://github.com/abo-abo/tiny
;; Version: 0.1

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Setup:
;; In ~/.emacs:
;;     (require 'tiny)
;;     (tiny-setup-default)
;;
;; Usage:
;; This extension's main command is `tiny-expand'.
;; It's meant to quickly generate linear ranges, e.g. 5, 6, 7, 8.
;; Some elisp proficiency is an advantage, since you can transform
;; your numeric range with an elisp expression.
;;
;; There's also some emphasis on the brevity of the expression to be
;; expanded: e.g. instead of typing (+ x 2), you can do +x2.
;; You can still do the full thing, but +x2 would save you some
;; key strokes.
;;
;; You can test out the following snippets
;; by positioning the point at the end of the expression
;; and calling `tiny-expand' (default shortcut is C-;):
;;
;; m10
;; m5 10
;; m5,10
;; m5 10*xx
;; m5 10*xx&x
;; m5 10*xx&0x&x
;; m25+x?a&c
;; m25+x?A&c
;; m97,122stringx
;; m97,122stringxx
;; m97,120stringxupcasex
;; m97,120stringxupcasex)x
;; m10*2+3x
;; m\n;; 10expx
;; m5\n;; 20expx&014.2f
;; m, 7&0x&02x
;; m1\n14&*** TODO http://emacsrocks.com/e&02d.html
;; m1\n10&convert img&s.jpg -monochrome -resize 50% -rotate 180 img&s_mono.pdf
;; (setq foo-list '(m1 11+x96&?&c))
;; m1\n10listx+x96&convert img&s.jpg -monochrome -resize 50% -rotate 180 img&c_mono.pdf
;; m1\n10listxnthxfoo-list&convert img&s.jpg -monochrome -resize 50% -rotate 180 img&c_mono.pdf
;;
;; As you might have guessed, the syntax is as follows:
;; m[<range start:=0>][<separator:= >]<range end>[lisp expr][&][format expr]
;;
;; x is the default var in the elisp expression. It will take one by one
;; the value of all numbers in the range.
;;
;; & means that elisp expr has ended and format expr has begun.
;; It can be used as part of the format expr if there's only one.
;; The keys are the same as for format: I just translate & to %.
;;
;; Note that multiple & can be used in the format expression.
;; In that case:
;; * if the lisp expresion returns a list, the members of this list
;;   are used in the appropriate place.
;; * otherwise, it's just the result of the expression repeated as
;;   many times as necessary.

(eval-when-compile
  (require 'cl))
(require 'cl-lib)
(require 'help-fns)

(defvar tiny-beg nil
  "Last matched snipped start position.")

(defvar tiny-end nil
  "Last matched snipped end position.")

(defun tiny-expand ()
  "Expand current snippet.
It's intended to poll all registered expander functions
if they can expand the thing at point.
First one to return a string succeeds.
These functions are expected to set `tiny-beg' and `tiny-end'
to the bounds of the snippet that they matched.
At the moment, only `tiny-mapconcat' is supported.
`tiny-mapconcat2' should be added to expand rectangles."
  (interactive)
  (let ((str (tiny-mapconcat)))
    (when str
      (delete-region tiny-beg tiny-end)
      (insert str)
      (tiny-replace-this-sexp))))

(defun tiny-setup-default ()
  (global-set-key (kbd "C-;") 'tiny-expand))

(defun tiny-replace-this-sexp ()
  "Intelligently replace current sexp."
  (interactive)
  (or
   (and (looking-back ")")
        (ignore-errors
          (tiny-replace-last-sexp)))
   (save-excursion (tiny-replace-sexp-desperately))))

(defun tiny-replace-last-sexp ()
  (interactive)
  (let ((sexp (preceding-sexp)))
    (unless (eq (car sexp) 'lambda)
      (let ((value (eval sexp)))
        (kill-sexp -1)
        (insert (format "%s" value))
        t))))

(defun tiny-replace-sexp-desperately ()
  "Try to eval the current sexp.
Replace it if there's no error.
Go upwards until it's possible to eval.
Skip lambdas."
  (interactive)
  (condition-case nil
      (tiny-up-list)
    (error "can't go up this list"))
  (let ((sexp (preceding-sexp)))
    (cond
      ((eq (car sexp) 'lambda)
       (tiny-replace-sexp-desperately))
      (t
       (condition-case nil
           (let ((value (eval sexp)))
             (kill-sexp -1)
             (insert (format "%s" value)))
         (error (tiny-replace-sexp-desperately)))))))

(defun tiny-beginning-of-string ()
  (interactive)
  (let ((p (nth 8 (syntax-ppss))))
    (when (eq (char-after p) ?\")
      (goto-char p))))

(defun tiny-up-list ()
  (interactive)
  (tiny-beginning-of-string)
  (up-list))

(defun tiny-mapconcat ()
  "Take the output of `tiny-mapconcat-parse' and replace
the null values with defaults and return the formatted
expression."
  (destructuring-bind (n1 s1 n2 expr fmt n-uses) (tiny-mapconcat-parse)
    (when (zerop (length n1))
      (setq n1 "0"))
    (when (zerop (length s1))
      (setq s1 " "))
    (when (zerop (length expr))
      (setq expr "x"))
    (when (zerop (length fmt))
      (setq fmt "%s"))
    ;;
    (let* ((lexpr (read expr))
           (format-expressions (if (and (listp lexpr) (eq (car lexpr) 'list))
                                   (mapconcat #'identity
                                              (loop for i from 0 to (1- (length lexpr))
                                                 collecting (format "(nth %d x)" i))
                                              " ")
                                 (if n-uses
                                     (apply #'concat (make-list n-uses "x "))
                                   "x"))))
    (unless (>= (read n1) (read n2))
      (format
       (concat
        "(mapconcat (lambda(x) (setq x %s)(format \"%s\" "
        format-expressions
        ")) (number-sequence %s %s) \"%s\")")
       expr
       fmt
       n1
       n2
       s1)))))

(defun tiny-mapconcat-parse ()
  "Try to match a snippet of this form:
m[START][SEPARATOR]END[EXPR][FORMAT]

* START - integer, default is 0
* SEPARATOR - string, default is " "
* END - integer, required
* EXPR - lisp expression.
  Parens are optional if it's unambiguous, e.g.
  `(* 2 (+ x 3))' can be shortened to *2+x3,
  and `(exp x)' can be shortened to expx.
  A closing paren may be added to resolve ambiguity:
  *2+x3"
  (let (n1 s1 n2 expr fmt str n-uses)
    (and (catch 'done
           (cond
             ;; either start with a number
             ((looking-back "\\m\\(-?[0-9]+\\)\\([^\n]*?\\)")
              (setq n1 (match-string-no-properties 1)
                    str (match-string-no-properties 2)
                    tiny-beg (match-beginning 0)
                    tiny-end (match-end 0))
              (when (zerop (length str))
                (setq n2 n1
                      n1 nil)
                (throw 'done t)))
             ;; else capture the whole thing
             ((looking-back "\\m\\([^\n]*\\)")
              (setq str (match-string-no-properties 1)
                    tiny-beg (match-beginning 0)
                    tiny-end (match-end 0))
              (when (zerop (length str))
                (throw 'done nil))))
           ;; at this point, `str' should be either [sep]<num>[expr][fmt]
           ;; or [expr][fmt]
           ;;
           ;; First, try to match [expr][fmt]
           (string-match "^\\(.*?\\)\\(&.*\\)?$" str)
           (setq expr (match-string-no-properties 1 str))
           (setq fmt  (match-string-no-properties 2 str))
           ;; If it's a valid expression, we're done
           (when (setq expr (tiny-tokenize expr))
             (when fmt
               (setq n-uses (cl-count ?& fmt))
               (setq fmt
                     (replace-regexp-in-string
                      "&" "%"
                      (replace-regexp-in-string
                       "%" "%%" fmt))))
             (setq n2 n1
                   n1 nil)
             (throw 'done t))
           ;; at this point, `str' is [sep]<num>[expr][fmt]
           (if (string-match "^\\([^\n0-9]*?\\)\\(-?[0-9]+\\)\\(.*\\)?$" str)
               (setq s1 (match-string-no-properties 1 str)
                     n2 (match-string-no-properties 2 str)
                     str (match-string-no-properties 3 str))
             ;; here there's only n2 that was matched as n1
             (setq n2 n1
                   n1 nil))
           ;; match expr_fmt
           (when str
             (if (string-match "^:?\\([^\n&]*?\\)\\(&[^\n]*\\)?$" str)
                (progn
                   (setq expr (tiny-tokenize (match-string-no-properties 1 str)))
                   (setq fmt (match-string-no-properties 2 str)))
               (error "couldn't match %s" str)))
           (when (> (length fmt) 0)
             (if (string-match "^&.*&.*$" fmt)
                 (progn
                   (setq fmt (replace-regexp-in-string "%" "%%" (substring fmt 1)))
                   (setq n-uses (cl-count ?& fmt))
                   (setq fmt (replace-regexp-in-string "&" "%" fmt)))
               (aset fmt 0 ?%)))
           t)
         (list n1 s1 n2 expr fmt n-uses))))

;; TODO: check for arity: this doesn't work: exptxy
(defun tiny-tokenize (str)
  (ignore-errors
    (let ((i 0)
          (j 1)
          (len (length str))
          sym
          s
          out
          (n-paren 0)
          (expect-fun t))
      (while (< i len)
        (setq s (substring str i j))
        (when (cond
                ((string= s "x")
                 (push s out)
                 (push " " out))
                ((string= s "y")
                 (push s out)
                 (push " " out))
                ((string= s " ")
                 (error "unexpected \" \""))
                ((string= s "?")
                 (setq s (format "%s" (read (substring str i (incf j)))))
                 (push s out)
                 (push " " out))
                ((string= s ")")
                 ;; expect a close paren only if it's necessary
                 (if (>= n-paren 2)
                     (decf n-paren)
                   (error "unexpected \")\""))
                 (pop out)
                 (push ") " out))
                ((string= s "(")
                 ;; open paren is used sometimes
                 ;; when there are numbers in the expression
                 (incf n-paren)
                 (push "(" out))
                ((progn (setq sym (intern-soft s))
                        (cond
                          ;; general functionp
                          ((not (eq t (help-function-arglist sym)))
                           (setq expect-fun)
                           ;; (when (zerop n-paren)
                           ;;   (push "(" out))
                           (push "(" out)
                           (incf n-paren))
                          ((and sym (boundp sym) (not expect-fun))
                           t)))
                 (push s out)
                 (push " " out))
                ((numberp (read s))
                 (let* ((num (string-to-number (substring str i)))
                        (num-s (format "%s" num)))
                   (push num-s out)
                   (push " " out)
                   (setq j (+ i (length num-s)))))
                (t
                 (incf j)
                 nil))
          (setq i j)
          (setq j (1+ i))))
      ;; last space
      (pop out)
      (concat
       (apply #'concat (nreverse out))
       (make-string n-paren ?\))))))

(provide 'tiny)
;;; tiny.el ends here
