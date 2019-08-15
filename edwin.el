;;; edwin --- Dynamic window manager for Emacs -*- lexical-binding: t -*-

;;; Copyright © 2019 Alex Griffin <a@ajgrf.com>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'seq)

(defvar edwin-layout 'edwin-tall-layout
  "The current Edwin layout.
A layout is a function that takes a list of buffers, and arranges them into
a window configuration.")

(defvar edwin-nmaster 1
  "The number of windows to put in the Edwin master area.")

(defvar edwin-mfact 0.55
  "The size of the master area in proportion to the stack area.")

(defun edwin-arrange ()
  "Arrange windows according to Edwin's current layout."
  (interactive)
  (let* ((windows (edwin-window-list))
         (selected-window-index (seq-position windows (selected-window)))
         (buffers (mapcar #'window-buffer windows)))
    (delete-other-windows)
    (funcall edwin-layout buffers)
    (select-window (nth selected-window-index
                        (edwin-window-list)))))

(defun edwin-window-list (&optional frame)
  "Return a list of windows on FRAME in layout order."
  (window-list frame nil (frame-first-window frame)))

(defun edwin-stack-layout (buffers)
  "Edwin layout that stacks BUFFERS evenly on top of each other."
  (let ((split-height (ceiling (/ (window-height)
                                  (length buffers)))))
    (switch-to-buffer (car buffers))
    (dolist (buffer (cdr buffers))
      (select-window
       (split-window nil split-height 'below))
      (switch-to-buffer buffer))))

(defun edwin-mastered (side layout)
  "Add a master area to LAYOUT.
SIDE has the same meaning as in `split-window', but putting master to the
right or bottom is not supported."
  (lambda (buffers)
    (let ((master (seq-take buffers edwin-nmaster))
          (stack  (seq-drop buffers edwin-nmaster))
          (msize  (ceiling (* -1
                              edwin-mfact
                              (if (memq side '(left right t))
                                  (frame-width)
                                (frame-height))))))
      (when stack
        (funcall layout stack))
      (when master
        (when stack
          (select-window
           (split-window (frame-root-window) msize side)))
        (edwin-stack-layout master)))))

(defun edwin-tall-layout (buffers)
  "Edwin layout with master and stack areas for BUFFERS."
  (let* ((side (if (< (frame-width) 132) 'above 'left))
         (layout (edwin-mastered side #'edwin-stack-layout)))
    (funcall layout buffers)))

(defun edwin-select-next-window ()
  "Move cursor to the next window in cyclic order."
  (interactive)
  (select-window (next-window)))

(defun edwin-select-previous-window ()
  "Move cursor to the previous window in cyclic order."
  (interactive)
  (select-window (previous-window)))

(defun edwin-swap-next-window ()
  "Swap the selected window with the next window."
  (interactive)
  (window-swap-states (selected-window)
                      (next-window)))

(defun edwin-swap-previous-window ()
  "Swap the selected window with the previous window."
  (interactive)
  (window-swap-states (selected-window)
                      (previous-window)))

(defun edwin-inc-nmaster ()
  "Increase the number of windows in the master area."
  (interactive)
  (setq edwin-nmaster (+ edwin-nmaster 1))
  (edwin-arrange))

(defun edwin-dec-nmaster ()
  "Decrease the number of windows in the master area."
  (interactive)
  (setq edwin-nmaster (- edwin-nmaster 1))
  (when (< edwin-nmaster 0)
    (setq edwin-nmaster 0))
  (edwin-arrange))

(defun edwin-inc-mfact ()
  "Increase the size of the master area."
  (interactive)
  (setq edwin-mfact (min (+ edwin-mfact 0.05)
                         0.95))
  (edwin-arrange))

(defun edwin-dec-mfact ()
  "Decrease the size of the master area."
  (interactive)
  (setq edwin-mfact (max (- edwin-mfact 0.05)
                         0.05))
  (edwin-arrange))

(defvar edwin-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "M-r") 'edwin-arrange)
    (define-key map (kbd "M-j") 'edwin-select-next-window)
    (define-key map (kbd "M-k") 'edwin-select-previous-window)
    (define-key map (kbd "M-J") 'edwin-swap-next-window)
    (define-key map (kbd "M-K") 'edwin-swap-previous-window)
    (define-key map (kbd "M-i") 'edwin-inc-nmaster)
    (define-key map (kbd "M-d") 'edwin-dec-nmaster)
    (define-key map (kbd "M-h") 'edwin-dec-mfact)
    (define-key map (kbd "M-l") 'edwin-inc-mfact)
    map)
  "Keymap for edwin-mode.")

(define-minor-mode edwin-mode
  "Toggle Edwin mode on or off.
With a prefix argument ARG, enable Edwin mode if ARG is
positive, and disable it otherwise.  If called from Lisp, enable
the mode if ARG is omitted or nil, and toggle it if ARG is `toggle'.

Edwin mode is a global minor mode that provides dwm-like dynamic
window management for Emacs windows."
  :global t
  :lighter " edwin"
  :keymap 'edwin-mode-map
  (edwin-arrange))

(provide 'edwin)
;;; edwin.el ends here
