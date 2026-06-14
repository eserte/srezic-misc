;;; test-cpan-annotate.el --- Tests for cpan-annotate.el -*- lexical-binding: t; -*-

;; To run tests from repository root:
;; emacs -batch -L elisp -l test-cpan-annotate.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'cpan-annotate)

(defun approx-equal (a b)
  (< (abs (- a b)) 1e-7))

(ert-deftest cpan-annotate-test-version-to-float ()
  (should (= (cpan-annotate--version-to-float "0.001") 0.001))
  (should (= (cpan-annotate--version-to-float "1.2.3") 1.002003))
  (should (= (cpan-annotate--version-to-float "1.2") 1.2))
  (should (= (cpan-annotate--version-to-float "10") 10.0))
  (should (approx-equal (cpan-annotate--version-to-float "1.02.03") 1.002003)))

(ert-deftest cpan-annotate-test-extract-dist-name ()
  (should (string= (cpan-annotate--extract-dist-name "Zuzu-0.001") "Zuzu"))
  (should (string= (cpan-annotate--extract-dist-name "Alien-ggml-0.09") "Alien-ggml"))
  (should (string= (cpan-annotate--extract-dist-name "Search-Xapian-1.2.25.7") "Search-Xapian")))

(ert-deftest cpan-annotate-test-extract-version ()
  (should (string= (cpan-annotate--extract-version "Zuzu-0.001") "0.001"))
  (should (string= (cpan-annotate--extract-version "Alien-ggml-0.09") "0.09"))
  (should (string= (cpan-annotate--extract-version "Search-Xapian-1.2.25.7") "1.2.25.7")))

(ert-deftest cpan-annotate-test-normalize-url ()
  (should (string= (cpan-annotate--normalize-url "https://github.com/user/repo/issues/1") "https://github.com/user/repo/issues/1"))
  (should (string= (cpan-annotate--normalize-url "https://rt.cpan.org/Public/Bug/Display.html?id=12345") "12345"))
  (should (string= (cpan-annotate--normalize-url "https://rt.cpan.org/Ticket/Display.html?id=163630") "163630"))
  (should (string= (cpan-annotate--normalize-url "https://rt.cpan.org/Ticket/Display.html?id=163630&results=abcd") "163630"))
  (should (string= (cpan-annotate--normalize-url "https://sourceforge.net/p/kontocheck/bugs/23/") "https://sourceforge.net/p/kontocheck/bugs/23/")))

(ert-deftest cpan-annotate-test-get-distvname ()
  (let ((mock-output "0x02c00044  0     N/A FAIL Alien-ggml-0.09 aarch64-freebsd-thread-multi 15.0-beta1 (perl v5.42.0) - ctr_good_or_invalid\n0x03c00044  3     N/A FAIL Search-Xapian-1.2.25.7 aarch64-freebsd-ld 15.0-stable (perl v5.42.2) - ctr_good_or_invalid"))
    (cl-letf (((symbol-function 'cpan-annotate--wmctrl-l) (lambda () mock-output)))
      ;; More than one window matches the general pattern, so it should fail
      (should-error (cpan-annotate--get-distvname))

      ;; Test with only one matching line in output
      (let ((mock-output "0x02c00044  0     N/A FAIL Alien-ggml-0.09 aarch64-freebsd-thread-multi 15.0-beta1 (perl v5.42.0) - ctr_good_or_invalid"))
        (cl-letf (((symbol-function 'cpan-annotate--wmctrl-l) (lambda () mock-output)))
          (should (string= (cpan-annotate--get-distvname) "Alien-ggml-0.09"))))

      ;; Test with Search-Xapian
      (let ((mock-output "0x03c00044  3     N/A FAIL Search-Xapian-1.2.25.7 aarch64-freebsd-ld 15.0-stable (perl v5.42.2) - ctr_good_or_invalid"))
        (cl-letf (((symbol-function 'cpan-annotate--wmctrl-l) (lambda () mock-output)))
          (should (string= (cpan-annotate--get-distvname) "Search-Xapian-1.2.25.7")))))))

(ert-deftest cpan-annotate-test-do-insert-new ()
  (with-temp-buffer
    (cpan-annotate--do-insert "Zuzu-0.001" "https://github.com/user/repo/issues/1")
    (should (string= (buffer-string) "Zuzu-0.001                              https://github.com/user/repo/issues/1\n"))

    (erase-buffer)
    (cpan-annotate--do-insert "Zuzu-0.001" "https://rt.cpan.org/Public/Bug/Display.html?id=12345")
    (should (string= (buffer-string) "Zuzu-0.001                              12345\n"))))

(ert-deftest cpan-annotate-test-do-insert-append-url ()
  (with-temp-buffer
    (insert "Zuzu-0.001                              https://github.com/user/repo/issues/1\n")
    (cpan-annotate--do-insert "Zuzu-0.001" "https://github.com/user/repo/issues/2")
    (should (string= (buffer-string) "Zuzu-0.001                              https://github.com/user/repo/issues/1,https://github.com/user/repo/issues/2\n"))

    (erase-buffer)
    (insert "Zuzu-0.001                              12345\n")
    (cpan-annotate--do-insert "Zuzu-0.001" "https://github.com/user/repo/issues/1")
    (should (string= (buffer-string) "Zuzu-0.001                              12345,https://github.com/user/repo/issues/1\n"))))

(ert-deftest cpan-annotate-test-do-insert-duplicate-url ()
  (with-temp-buffer
    (insert "Zuzu-0.001                              https://github.com/user/repo/issues/1\n")
    (should-error (cpan-annotate--do-insert "Zuzu-0.001" "https://github.com/user/repo/issues/1"))))

(ert-deftest cpan-annotate-test-do-insert-upgrade-version ()
  (with-temp-buffer
    (insert "Zuzu-0.001                              https://github.com/user/repo/issues/1\n")
    (cpan-annotate--do-insert "Zuzu-0.002" "https://github.com/user/repo/issues/1")
    (should (string= (buffer-string) "Zuzu-0.002                              https://github.com/user/repo/issues/1\n"))))

(ert-deftest cpan-annotate-test-do-insert-older-version-fail ()
  (with-temp-buffer
    (insert "Zuzu-0.002                              https://github.com/user/repo/issues/1\n")
    (should-error (cpan-annotate--do-insert "Zuzu-0.001" "https://github.com/user/repo/issues/1"))))

(ert-deftest cpan-annotate-test-do-insert-rt-normalization ()
  (with-temp-buffer
    (insert "Zuzu-0.001                              12345\n")
    ;; Should fail because 12345 is already there as a shortcut
    (should-error (cpan-annotate--do-insert "Zuzu-0.001" "https://rt.cpan.org/Public/Bug/Display.html?id=12345"))

    ;; Should also fail if we try to add a shortcut when the full URL is there
    (erase-buffer)
    (insert "Zuzu-0.001                              https://rt.cpan.org/Public/Bug/Display.html?id=12345\n")
    (should-error (cpan-annotate--do-insert "Zuzu-0.001" "12345"))))

(ert-deftest cpan-annotate-test-insert-high-level ()
  (let ((mock-wmctrl "0x02c00044  0     N/A FAIL Alien-ggml-0.09 aarch64-freebsd-thread-multi 15.0-beta1 (perl v5.42.0) - ctr_good_or_invalid")
        (test-buffer (get-buffer-create "*test-cpan-annotate-high-level*")))
    (cl-letf (((symbol-function 'cpan-annotate--wmctrl-l) (lambda () mock-wmctrl))
              ((symbol-function 'cpan-annotate--read-current-url) (lambda () "https://github.com/user/repo/issues/1"))
              ((symbol-function 'find-file) (lambda (f) (set-buffer test-buffer) (erase-buffer)))
              ((symbol-function 'message) (lambda (&rest _args) nil)))
      (cpan-annotate-insert)
      (with-current-buffer test-buffer
        (should (string-match "Alien-ggml-0.09" (buffer-string)))
        (should (string-match "https://github.com/user/repo/issues/1" (buffer-string))))
      (kill-buffer test-buffer))))

;;; test-cpan-annotate.el ends here
