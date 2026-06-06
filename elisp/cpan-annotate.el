;;; cpan-annotate.el --- CPAN testers annotation helper -*- lexical-binding: t; -*-

;;; Commentary:
;; This file provides `cpan-annotate-insert`, which helps in maintaining
;; an annotation file for CPAN tester results.

;;; Code:

(require 'cl-lib)

(defgroup cpan-annotate nil
  "CPAN testers annotation helper."
  :group 'tools)

(defcustom cpan-annotate-url-file "~/Downloads/current_url.txt"
  "File containing the URL to be added."
  :type 'file
  :group 'cpan-annotate)

(defcustom cpan-annotate-annotate-file "~/work2/analysis-cpantesters-annotate/annotate.txt"
  "The annotation file to be updated."
  :type 'file
  :group 'cpan-annotate)

(defcustom cpan-annotate-issue-url-regexps
  '("^https://github\\.com/.*/issues/[0-9]+$"
    "^https://gitlab\\.com/.*/-/issues/[0-9]+$"
    "^https://codeberg\\.org/.*/issues/[0-9]+$"
    "^https://rt\\.cpan\\.org/Public/Bug/Display\\.html\\?id=[0-9]+$")
  "List of regexps to match valid issue URLs."
  :type '(repeat string)
  :group 'cpan-annotate)

(defcustom cpan-annotate-window-regexp
  "^\\(FAIL\\|NA\\|UNKNOWN\\)\\s-+\\([^[:space:]]+\\)\\s-+.*- ctr_good_or_invalid$"
  "Regexp to match the window title and extract DISTVNAME (group 2)."
  :type 'string
  :group 'cpan-annotate)

(defcustom cpan-annotate-url-column 40
  "The column where the issue URLs should start."
  :type 'integer
  :group 'cpan-annotate)

(defun cpan-annotate--version-to-float (v)
  "Convert Perl version string V to a float for comparison."
  (if (string-match-p "\\." v)
      (let ((parts (split-string v "\\.")))
        (if (> (length parts) 2)
            ;; Dotted-decimal: 1.2.3 -> 1.002003
            (let ((float-val (string-to-number (car parts)))
                  (multiplier 0.001))
              (dolist (part (cdr parts))
                (setq float-val (+ float-val (* (string-to-number part) multiplier)))
                (setq multiplier (* multiplier 0.001)))
              float-val)
          ;; Single dot: just convert to number
          (string-to-number v)))
    ;; No dot: just convert to number
    (string-to-number v)))

(defun cpan-annotate--extract-dist-name (distvname)
  "Extract the distribution name from DISTVNAME (e.g., Zuzu from Zuzu-0.001)."
  (if (string-match "\\(.*\\)-\\([^-]+\\)$" distvname)
      (match-string 1 distvname)
    distvname))

(defun cpan-annotate--extract-version (distvname)
  "Extract the version string from DISTVNAME."
  (if (string-match "\\(.*\\)-\\([^-]+\\)$" distvname)
      (match-string 2 distvname)
    "0"))

(defun cpan-annotate--normalize-url (url)
  "Normalize URL.  RT URLs are converted to their ID if they match the RT pattern."
  (if (string-match "https://rt\\.cpan\\.org/Public/Bug/Display\\.html\\?id=\\([0-9]+\\)" url)
      (match-string 1 url)
    url))

(defun cpan-annotate--get-distvname ()
  "Get the DISTVNAME from wmctrl -l.
Fails if not exactly one matching window is found."
  (let* ((wmctrl-output (shell-command-to-string "wmctrl -l"))
         (lines (split-string wmctrl-output "\n" t))
         (matches nil))
    (dolist (line lines)
      ;; wmctrl -l output format: window-id desktop-id hostname title
      (when (string-match "^0x[0-9a-f]+\\s-+[0-9-]+\\s-+[^[:space:]]+\\s-+\\(.*\\)$" line)
        (let ((title (match-string 1 line)))
          (when (string-match cpan-annotate-window-regexp title)
            (push (match-string 2 title) matches)))))
    (cond
     ((= (length matches) 0)
      (error "No matching window found for wmctrl"))
     ((> (length matches) 1)
      (error "More than one matching window found: %s" (mapconcat 'identity matches ", ")))
     (t
      (car matches)))))

(defun cpan-annotate--read-current-url ()
  "Read the first line of `cpan-annotate-url-file` and validate it."
  (let ((file (expand-file-name cpan-annotate-url-file)))
    (unless (file-exists-p file)
      (error "URL file %s does not exist" file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let ((url (buffer-substring-no-properties (point) (line-end-position))))
        (setq url (replace-regexp-in-string "[ \t\n\r]+" "" url))
        (when (string= url "")
          (error "URL file is empty"))
        (unless (cl-some (lambda (re) (string-match-p re url))
                         cpan-annotate-issue-url-regexps)
          (error "URL does not match any known issue patterns: %s" url))
        url))))

;;;###autoload
(defun cpan-annotate-insert ()
  "Interactively add or update a CPAN testers annotation."
  (interactive)
  (let* ((current-url (cpan-annotate--read-current-url))
         (distvname (cpan-annotate--get-distvname))
         (normalized-url (cpan-annotate--normalize-url current-url))
         (annotate-file (expand-file-name cpan-annotate-annotate-file))
         (dist-name (cpan-annotate--extract-dist-name distvname))
         (version (cpan-annotate--extract-version distvname))
         (version-float (cpan-annotate--version-to-float version)))

    (find-file annotate-file)
    (goto-char (point-min))

    (let ((found-dist-line nil)
          (found-url-for-dist-line nil))
      (while (not (eobp))
        (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
          (when (string-match "^\\([^[:space:]]+\\)\\s-+\\(.*\\)$" line)
            (let* ((ldistvname (match-string 1 line))
                   (ldistname (cpan-annotate--extract-dist-name ldistvname))
                   (lurls (mapcar (lambda (s) (replace-regexp-in-string "^\\s-+\\|\\s-+$" "" s))
                                  (split-string (match-string 2 line) "," t)))
                   (lnormalized-urls (mapcar #'cpan-annotate--normalize-url lurls)))
              (cond
               ((string= ldistvname distvname)
                (setq found-dist-line t)
                (if (member normalized-url lnormalized-urls)
                    (error "URL exists already for this distvname")
                  (goto-char (line-end-position))
                  (insert "," current-url))
                (goto-char (point-max))) ;; exit loop
               ((and (string= ldistname dist-name)
                     (member normalized-url lnormalized-urls))
                (setq found-url-for-dist-line t)
                (let* ((lversion (cpan-annotate--extract-version ldistvname))
                       (lversion-float (cpan-annotate--version-to-float lversion)))
                  (if (< lversion-float version-float)
                      (progn
                        (goto-char (line-beginning-position))
                        (when (looking-at "[^[:space:]]+")
                          (replace-match distvname))
                        (goto-char (point-max))) ;; exit loop
                    (error "URL exists already for a newer or same version: %s" ldistvname))))))))
        (unless (eobp) (forward-line 1)))

      (unless (or found-dist-line found-url-for-dist-line)
        ;; Append new line
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert distvname)
        (indent-to cpan-annotate-url-column)
        (insert current-url)
        (insert "\n")))

    (message "Added annotation for %s" distvname)))

(provide 'cpan-annotate)

;;; cpan-annotate.el ends here
