;;; +org.el -*- lexical-binding: t; -*-

(use-package! org-journal
  :ensure t
  :defer t
  :config
  (setq org-journal-dir "~/org/journal/")
  (setq org-journal-file-type 'weekly))

(use-package! org-roam
  :config
  (setq org-roam-directory (file-truename "~/org-roam"))
  (org-roam-db-autosync-mode)
  )

(after! org-mode
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((R . t))))

(provide '+org)
