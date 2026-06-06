;;; test-cpan-annotate.el --- Tests for cpan-annotate.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cpan-annotate "./elisp/cpan-annotate.el")

(ert-deftest cpan-annotate-test-version-to-float ()
  (should (= (cpan-annotate--version-to-float "0.001") 0.001))
  (should (= (cpan-annotate--version-to-float "1.2.3") 1.002003))
  (should (= (cpan-annotate--version-to-float "1.2") 1.2))
  (should (= (cpan-annotate--version-to-float "10") 10.0))
  (should (approx-equal (cpan-annotate--version-to-float "1.02.03") 1.002003)))

(defun approx-equal (a b)
  (< (abs (- a b)) 1e-7))

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
  (should (string= (cpan-annotate--normalize-url "https://rt.cpan.org/Public/Bug/Display.html?id=12345") "12345")))

(ert-deftest cpan-annotate-test-wmctrl-parsing ()
  (let ((line1 "0x02c00044  0     N/A FAIL Alien-ggml-0.09 aarch64-freebsd-thread-multi 15.0-beta1 (perl v5.42.0) - ctr_good_or_invalid")
        (line2 "0x03c00044  3     N/A FAIL Search-Xapian-1.2.25.7 aarch64-freebsd-ld 15.0-stable (perl v5.42.2) - ctr_good_or_invalid")
        (wmctrl-re "^0x[[:xdigit:]]+[ \t]+[0-9-]+[ \t]+[^ \t\n\r]+[ \t]+\\(.*\\)")
        (window-re cpan-annotate-window-regexp))

    ;; Test full wmctrl line match and title extraction
    (should (string-match wmctrl-re line1))
    (let ((title1 (match-string 1 line1)))
      (should (string= title1 "FAIL Alien-ggml-0.09 aarch64-freebsd-thread-multi 15.0-beta1 (perl v5.42.0) - ctr_good_or_invalid"))
      ;; Test title match and distvname extraction
      (should (string-match window-re title1))
      (should (string= (match-string 2 title1) "Alien-ggml-0.09")))

    (should (string-match wmctrl-re line2))
    (let ((title2 (match-string 1 line2)))
      (should (string= title2 "FAIL Search-Xapian-1.2.25.7 aarch64-freebsd-ld 15.0-stable (perl v5.42.2) - ctr_good_or_invalid"))
      ;; Test title match and distvname extraction
      (should (string-match window-re title2))
      (should (string= (match-string 2 title2) "Search-Xapian-1.2.25.7")))))

;;; test-cpan-annotate.el ends here
