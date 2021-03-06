(in-package #:clvba)

(let ((cache (make-hash-table :test 'equal)))
  (defun encode-vba-identifier (identifier)
    "Given a string, produces to a valid VBA identifier by
following transformation heuristics case conversion. For example,
cl-vba becomes clVba, *some-global* becomes SOMEGLOBAL."
    (or (gethash identifier cache)
        (setf (gethash identifier cache)
              (cond ((some (lambda (c) (find c "-*+!?#@%/=:<>^")) identifier)
                     (let ((lowercase t)
                           (all-uppercase nil))
                       (when (and (not (string= identifier "[]")) ;; HACK
                                  (find-if (lambda (x) (find x '(#\. #\[ #\]))) identifier))
                         (warn "Symbol ~A contains one of '.[]' - this compound naming convention is no longer supported by CLVBA!"
                               identifier))
                       (acond ((nth-value 1 (cl-ppcre:scan-to-strings "[\\*|\\+](.+)[\\*|\\+](.*)" identifier :sharedp t))
                               (setf all-uppercase t
                                     identifier (concatenate 'string (aref it 0) (aref it 1))))
                              ((and (> (length identifier) 1)
                                    (or (eql (char identifier 0) #\+)
                                        (eql (char identifier 0) #\*)))
                               (setf lowercase nil
                                     identifier (subseq identifier 1))))
                       (with-output-to-string (acc)
                         (loop for c across identifier
                            do (acond ((eql c #\-)
                                       (setf lowercase (not lowercase)))
                                      ((position c "!?#@%+*/=:<>^")
                                       (write-sequence (aref #("bang" "what" "hash" "at" "percent"
                                                               "plus" "star" "slash" "equals" "colon"
                                                               "lessthan" "greaterthan" "caret")
                                                             it)
                                                       acc))
                                      (t (write-char (cond ((and lowercase (not all-uppercase)) (char-downcase c))
                                                           (t (char-upcase c)))
                                                     acc)
                                         (setf lowercase t)))))))
                    ((every #'upper-case-p (remove-if-not #'alpha-char-p identifier)) (string-downcase identifier))
                    ((every #'lower-case-p (remove-if-not #'alpha-char-p identifier)) (string-upcase identifier))
                    (t identifier))))))

(defun ordered-set-difference (list1 list2 &key (test #'eql))
  "CL set-difference may not preserve order."
  (reduce (lambda (list el) (remove el list :test test))
          (cons list1 list2)))


(defun flatten (x &optional acc)
  (cond ((null x) acc)
        ((atom x) (cons x acc))
        (t (flatten (car x) (flatten (cdr x) acc)))))

(defun tree-search (A tree)
  (or (equal A tree)
      (when (consp tree)
        (loop for x on tree thereis ;; fucking dotted lists
              (or (tree-search A (car x))
                  (unless (listp (cdr x))
                    (equal A (cdr x))))))))


(defun symbol-to-vba-string (symbol &optional (mangle-symbol-name? t))
  (let* ((symbol-name (symbol-name symbol))
         (identifier (if mangle-symbol-name?
                         (encode-vba-identifier symbol-name)
                         symbol-name)))
    identifier))

(defun row-string (first other repeat &optional (sep "|"))
  "If first is \"abc\", other is \"def\", repeat is 2, then the result is: \"abc|def|def\""
  (let ((str01 first))
    (dotimes (i repeat str01)
      (setf str01 (concatenate 'string str01 sep other)))))
