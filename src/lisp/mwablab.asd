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
     (:file "natural-isomorphism" :depends-on ("package" "category" "natural-transformation"))
     (:file "opposite"            :depends-on ("package" "category"))
     (:file "product-category"    :depends-on ("package" "category" "functor"))
     (:file "bifunctor"           :depends-on ("package" "category" "functor" "product-category"))
     (:file "monoidal-category"  :depends-on ("package" "category" "bifunctor" "natural-isomorphism"))
     (:file "braided-monoidal"   :depends-on ("package" "monoidal-category"))
     (:file "symmetric-monoidal" :depends-on ("package" "braided-monoidal"))
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
