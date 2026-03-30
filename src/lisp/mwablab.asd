(defsystem "mwablab"
  :description "Categorical foundations — DSL and exploration layer"
  :version "0.1.0"
  :depends-on ()
  :components
  ((:module "src"
    :components
    ((:file "package")
     (:file "category"            :depends-on ("package"))
     (:file "functor"             :depends-on ("package" "category"))
     (:file "natural-transformation" :depends-on ("package" "category" "functor"))
     (:file "opposite"            :depends-on ("package" "category"))
     (:file "examples"            :depends-on ("package" "category" "functor"
                                               "natural-transformation" "opposite")))))
  :in-order-to ((test-op (test-op "mwablab/test"))))

(defsystem "mwablab/test"
  :depends-on ("mwablab")
  :components
  ((:module "test"
    :components ()))
  :perform (test-op (o c)
    (symbol-call :mwablab/test :run-tests)))
