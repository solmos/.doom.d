(use-package! ess
  ;; :ensure t
  :demand t
  :init
  (require 'ess-site)
  :config
  (setq display-buffer-alist
        `(("*R Dired"
           (display-buffer-reuse-window display-buffer-in-side-window)
           (side . right)
           (slot . -1)
           (window-width . 0.33)
           (reusable-frames . nil))
          ("*R"
           (display-buffer-reuse-window display-buffer-in-side-window)
           (side . right)
           (window-width . 0.5)
           (reusable-frames . nil))
          ("*Help"
           (display-buffer-reuse-window display-buffer-below-selected)
           (side . left)
           (slot . 1)
           (window-width . 0.33)
           (reusable-frames . nil)))
        )
  (setq ess-style 'RStudio-
        ;; auto-width
        ess-auto-width 'window
        ;; let lsp manage lintr
        ess-use-flymake t
        ;; Stop R repl eval from blocking emacs.
        ess-eval-visibly 'nowait
        ess-use-eldoc t
        ess-eldoc-show-on-symbol nil
        ess-use-company t
        )

  (setq ess-ask-for-ess-directory t
        ess-local-process-name "R"
        ansi-color-for-comint-mode 'filter
        comint-scroll-to-bottom-on-input t
        comint-scroll-to-bottom-on-output t
        comint-move-point-for-output t)
  (setq tab-width 2)

  (setq ess-r-fetch-ESSR-on-remotes 'ess-remote)
  ;; insert pipes etc...
  (defun tide-insert-assign ()
    "Insert an assignment <-"
    (interactive)
    (insert " <- "))
  (defun tide-insert-pipe ()
    "Insert a %>% and newline"
    (interactive)
    (insert " %>%"))
  (defun ess-insert-pipe ()
    "Insert a |> and newline"
    (interactive)
    (insert " |>"))
  ;; set keybindings
  ;; insert pipe
  (define-key ess-r-mode-map (kbd "C-'") 'tide-insert-assign)
  (define-key inferior-ess-r-mode-map (kbd "C-'") 'tide-insert-assign)
  ;; insert assign
  (define-key ess-r-mode-map (kbd ";") 'tide-insert-pipe)
  (define-key inferior-ess-r-mode-map (kbd ";") 'tide-insert-pipe)
  (define-key ess-r-mode-map (kbd "C->") 'ess-insert-pipe)
  (define-key inferior-ess-r-mode-map (kbd "C->") 'ess-insert-pipe)
  )

(add-hook! inferior-ess-mode-hook
  (setq-local comint-use-prompt-regexp nil)
  (setq-local inhibit-field-text-motion nil)
  (persp-add-buffer ess-local-process-name))

(use-package! ess-view-data
  :after ess
  :init
  (require 'ess-view-data))

(use-package! quarto-mode
  :init
  (require 'quarto-mode))

;; R helprs
(defun pos-paragraph ()
      (backward-paragraph)
      ;; (next-line 1)
      (forward-line 1)
      (beginning-of-line)
      (point))

(defun highlight-piped-region ()
  (let ((end (point))
        (beg (pos-paragraph)))
    (set-mark beg)
    (goto-char end)
    (end-of-line)
    (deactivate-mark)
    (setq last-point (point))
    (goto-char end)
    (buffer-substring-no-properties beg last-point)))

(defun ess-run-partial-pipe ()
  (interactive)
  (let ((string-to-execute (highlight-piped-region)))
    ;; https://stackoverflow.com/questions/65882345/replace-last-occurence-of-regexp-in-a-string-which-has-new-lines-replace-regexp/65882683#65882683
    (ess-eval-linewise
     (replace-regexp-in-string
      ".+<-" "" (replace-regexp-in-string
                 "\\(\\(.\\|\n\\)*\\)\\(%>%\\|\+\\) *\\'" "\\1" string-to-execute)))))

(define-key ess-mode-map (kbd "C-.") 'ess-run-partial-pipe)

;; ===========================================================
;; IDE Functions
;; ===========================================================

;; Bring up empty R script and R console for quick calculations
(defun ess-tide-scratch ()
  (interactive)
  (progn
    (delete-other-windows)
    (setq new-buf (get-buffer-create "scratch.R"))
    (switch-to-buffer new-buf)
    (R-mode)
    (setq w1 (selected-window))
    (setq w1name (buffer-name))
    (setq w2 (split-window w1 nil t))
    (if (not (member "*R*" (mapcar (function buffer-name) (buffer-list))))
        (R))
    (set-window-buffer w2 "*R*")
    (set-window-buffer w1 w1name)))

(global-set-key (kbd "C-x 9") 'ess-tide-R-scratch)

(defun ess-tide-display-ESS ()
  "Display the current inferior ESS process buffer."
  (interactive)
  (ess-force-buffer-current)
  (display-buffer (buffer-name (process-buffer (get-process ess-current-process-name)))
                 '(nil . ((inhibit-same-window . t))))
  )

(define-key ess-mode-map (kbd "C-c `") 'ess-tide-display-ESS)

;; Custom functions ====================================================
(defun ess-summary-at-point ()
  (interactive)
  (let ((x (ess-edit-word-at-point)))
    (ess-eval-linewise (concat "summary(" x ")"))))

(defun ess-glimpse-df-at-point ()
  "Show a glimpse of the data frame in the console"
  (interactive)
  (let ((x (ess-edit-word-at-point)))
    (ess-eval-linewise (concat "dplyr::glimpse(" x ")"))))

(defun ess-load-project-packages ()
  "Load packages.R when current working directory is project root"
  (interactive)
  (ess-eval-linewise "source('packages.R')"))

(defun ess-load-target-at-point ()
  "Load target at point"
  (interactive)
  (let ((x (ess-edit-word-at-point)))
    (ess-eval-linewise (concat "targets::tar_load(" x ")"))))

(defun ess-tar-make ()
  (interactive)
  (ess-eval-linewise "targets::tar_make()"))

;; Mark a word at a point ==============================================
;; http://www.emacswiki.org/emacs/ess-edit.el
(defun ess-edit-word-at-point ()
  (save-excursion
    (buffer-substring
     (+ (point) (skip-chars-backward "a-zA-Z0-9._"))
     (+ (point) (skip-chars-forward "a-zA-Z0-9._")))))
;; eval any word where the cursor is (objects, functions, etc)
(defun ess-eval-word ()
  (interactive)
  (let ((x (ess-edit-word-at-point)))
    (ess-eval-linewise (concat x)))
  )
;; key binding
(define-key ess-mode-map (kbd "C-c r") 'ess-eval-word)

;; keybindings
;; ==============================================================================
(map! (:localleader
       :map ess-r-mode-map
       :prefix-map ("c" . "ess")
       "v"      #'ess-view-inspect-df
       "c"       'ess-tide-insert-chunk
       "w"       'ess-eval-word
       "r"       'ess-run-partial-pipe)
      )

;; Interaction with REPL
(map! (:localleader
       :map ess-r-mode-map
       "w"       'ess-eval-word
       "e"       'ess-eval-paragraph-and-step
       "i"       'ess-interrupt
       "n"       'ess-debug-command-next
       "l"       'ess-eval-line-and-step)
      )

;; Graphics management
(map! (:localleader
       :map ess-r-mode-map
       :prefix-map ("g" . "Graphics")
       "o"      'ess-gdev-open-remote-pdf
       "g"      'ess-gdev-save-pdf))

;; Viewing objects
(map! (:localleader
       :map ess-r-mode-map
       :prefix-map ("d" . "Display")
       "d"      'ess-glimpse-df-at-point
       "s"      'ess-summary-at-point))

;; Targets/Drake projects
(map! (:localleader
       :map ess-r-mode-map
       :prefix-map ("t" . "targets")
       "p"      'ess-load-project-packages
       "l"      'ess-load-target-at-point
       "m"      'ess-tar-make))

(map! :localleader
      :map (polymode-minor-mode-map markdown-mode-map ess-r-mode-map)
      "P" 'polymode-map
      )

;; provide ess configuration
(provide '+ess)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; +ess.el ends here
