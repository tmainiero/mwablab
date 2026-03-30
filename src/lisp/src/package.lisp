(defpackage :mwablab
  (:use :cl)
  (:documentation "Categorical foundations — DSL and exploration layer.
Provides diagram specification, mathematical notation via reader macros,
and REPL-driven exploration of categorical constructions.")
  (:export
   ;; category.lisp — Category (Stacks Project 0014)
   #:category
   #:category-name
   #:category-objects
   #:category-hom
   #:category-identity
   #:category-compose
   #:id-morphism
   #:compose-morphisms
   #:hom-set

   ;; functor.lisp — Functor (Stacks Project 001B)
   #:functor
   #:functor-name
   #:functor-source
   #:functor-target
   #:functor-obj-map
   #:functor-mor-map
   #:fobj
   #:fmap

   ;; natural-transformation.lisp — Natural transformation (Stacks Project 001I)
   #:natural-transformation
   #:nat-trans-name
   #:nat-trans-source
   #:nat-trans-target
   #:nat-trans-component
   #:component-at
   #:vertical-compose
   #:identity-nat-trans

   ;; opposite.lisp — Opposite category
   #:opposite-category

   ;; examples.lisp — Concrete examples for exploration
   #:make-finite-category
   #:make-discrete-category
   #:*set-category*))

(in-package :mwablab)
