;;; arbitools.el --- Package for chess tournaments administration

;; Copyright 2016 Free Software Foundation, Inc.

;; Author: David Gonzalez Gandara <dggandara@member.fsf.org>
;; Version: 0.51

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; REQUIRES:
;; ---------------------------
;;
;;
;; USAGE:
;; ---------------------------
;; arbitools.el is an interface for the pythong package "arbitools",
;; designed to manage chess tournament reports.  If you don't install the
;; python package you can still have the syntax colouring.
;;
;; FEATURES:
;; ----------------------------
;; - Syntax colouring for the official trf FIDE files.  This facilitates
;; manual edition of the files.
;;
;; - Updating the players ratings.  By means of the function arbitools-update
;;
;; - Adding players to an existing file.  By arbitools-add
;;
;; - Getting standings and report files from a tournament file.  By
;;   arbitools-standings.
;;
;; You will find more information in www.ourenxadrez.org/arbitools.htm

;;; Code:

(defun arbitools-update (elolist)
  "Update the players ratings."
  (interactive "selolist:")
  ;; FIXME: What if `list' is "foo; bar"?
  (call-process "arbitools-run.py" nil nil nil "update" buffer-file-name "-l" elolist))

(defun arbitools-add (addfile)
  "Add players to an existing file."
  (interactive "faddfile: ")
  ;; FIXME: What if `addlist' is "foo; bar"?
  (call-process "arbitools-add.py" nil nil nil "-a" addfile "-i" buffer-file-name))

(defun arbitools-standings ()
  "Get standings and report files from a tournament file."
  (interactive)
  ;; (shell-command (concat (expand-file-name "arbitools-standings.py") " -i " buffer-file-name))) ;this is to use the actual path
  (call-process "arbitools-standings.py" nil nil nil "-i" buffer-file-name))

(defun arbitools-delete-round (round)
   "Delete round"
   (interactive "sround: ")
   (beginning-of-buffer)
   (while (re-search-forward "^001" nil t)
     (forward-char (+ 88 (* (- (string-to-number round) 1) 10)))
     (delete-char 10)
     (insert "          "))
   (beginning-of-buffer))

(defun arbitools-insert-result (round white black result)
   "Insert a result"
   (interactive "sround: \nswhite: \nsblack: \nsresult: ")
   (beginning-of-buffer)
   (while (re-search-forward "^001" nil t)
     (forward-char 4) ;; rank number
     ;; (print (format "%s" white))
     (when (string= white (thing-at-point 'word))
       ;;go to first round taking into account the cursor is in the rank number
       (forward-char (+ 85 (* (- (string-to-number round) 1) 10)))
       (insert "  ") ;; replace the first positions with spaces
       (delete-char 2) ;; delete the former characters
       ;; make room for bigger numbers
       (cond ((= 2 (length black))
         (backward-char 1))
         ((= 3 (length black))
         (backward-char 2)))
       (insert (format "%s w %s" black result))
       (delete-char 5) 
       ;; adjust when numbers are longer
       (cond ((= 2 (length black)) (delete-char 1))
         ((= 3 (length black)) (delete-char 2))))
     (when (string= black (thing-at-point 'word))
       ;;go to first round taking into account the cursor is in the rank number
       (forward-char (+ 85 (* (- (string-to-number round) 1) 10)))
       (insert "  ") ;; replace the first positions with spaces
       (delete-char 2) ;; delete the former characters
       ;; make room for bigger numbers
       (cond ((= 2 (length white)) (backward-char 1))
         ((= 3 (length white)) (backward-char 2)))
       (cond ((string= "1" result) (insert (format "%s b 0" white)))
         ((string= "0" result) (insert (format "%s b 1" white))))
       (delete-char 5) 
       ;; adjust when numbers are longer
       (cond ((= 2 (length white)) (delete-char 1))
         ((= 3 (length white)) (delete-char 2)))))
   (beginning-of-buffer))

(defun arbitools-it3 ()
   "Get the IT3 tournament report."
   (interactive)
   (call-process "arbitools-run.py" nil nil nil "it3" buffer-file-name))

(defun arbitools-fedarating ()
   "Get the FEDA rating admin file."
   (interactive)
   (call-process "arbitools-run.py" nil nil nil "fedarating" buffer-file-name))

(defvar arbitools-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c i") 'arbitools-it3)
    map)
  "Keymap for Arbitools major mode.")


(easy-menu-define arbitools-mode-menu arbitools-mode-map
  "Menu for Arbitools mode"
  '("Arbitools"
    ["Insert Result" arbitools-insert-result]
    ["Delete Round" arbitools-delete-round]
    "---"
    ["Get It3 form Report" arbitools-it3]
    ["Get FEDA Ratinf file" arbitools-fedarating]
    ))


(defvar arbitools-highlights
 '(("^001" . font-lock-function-name-face) ; name of the tournament
    ("^012.*" . font-lock-comment-face)
    ("\\(^022\\|^032\\|^042\\|^052\\|^062\\|^072\\|^082\\|^092\\|^102\\|^112\\|^122\\).*" . font-lock-constant-face)
    ("^132.*" . font-lock-warning-face) ;dates
    ("^013" . font-lock-warning-face) ;teams
    ("\\(^013.\\{1\\}\\)\\(.\\{31\\}\\)" 2 font-lock-comment-face) ;; teams
    ;; (" [0-9]\\{6,\\} " . font-lock-variable-name-face) ;FIDE ID
    ("\\(^001.\\{11\\}\\)\\(.\\{32\\}\\)" 2 font-lock-string-face)  ;; Name of the player (by position)
    ("\\(^001.\\{55\\}\\)\\(.\\{10\\}\\)" 2 font-lock-function-name-face) ;; FIDE ID
    ("\\(^001.\\{88\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face) ;; round 1 opponent
    ;; ("\\(^132.\\{88\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face) ;; round 1 date line
    ("\\(^001.\\{93\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face) ;; round 1 colour
    ("\\(^001.\\{95\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face) ;; round 1 result
    ;; rest of rounds
    ("\\(^001.\\{98\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{98\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{103\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{105\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{108\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{108\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{113\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{115\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{118\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{118\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{123\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{125\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{128\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{128\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{133\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{135\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{138\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{138\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{143\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{145\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{148\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{148\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{153\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{155\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{158\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{158\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{163\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{165\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{168\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{168\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{173\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{175\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{178\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{178\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{183\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{185\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{188\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{188\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{193\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{195\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)
    ("\\(^001.\\{198\\}\\)\\(.\\{4\\}\\)" 2 font-lock-comment-face)
    ;; ("\\(^132.\\{198\\}\\)\\(.\\{8\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{203\\}\\)\\(.\\{1\\}\\)" 2 font-lock-string-face)
    ("\\(^001.\\{205\\}\\)\\(.\\{1\\}\\)" 2 font-lock-function-name-face)))

;;;###autoload
(define-derived-mode arbitools-mode
  fundamental-mode
  "Arbitools"
  "Major mode for Chess Tournament Management."
  ;(setq font-lock-defaults '(arbitools-highlights))
  (use-local-map arbitools-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(arbitools-highlights)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.trf?\\'" . arbitools-mode))

(provide 'arbitools)

;;; arbitools.el ends here