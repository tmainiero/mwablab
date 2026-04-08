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

   ;; natural-isomorphism.lisp — Natural isomorphism (nLab)
   #:natural-isomorphism
   #:invert-nat-iso
   #:compose-nat-iso
   #:identity-nat-iso

   ;; opposite.lisp — Opposite category
   #:opposite-category

   ;; product-category.lisp — Product category (nLab)
   #:product-category
   #:prod-morphism
   #:prod-first
   #:prod-second
   #:projection-functor-1
   #:projection-functor-2
   #:pairing-functor

   ;; bifunctor.lisp — Bifunctor (nLab)
   #:bifunctor
   #:bifunctor-source-cat-1
   #:bifunctor-source-cat-2
   #:bifunctor-target-cat
   #:bifunctor-bimap-fn
   #:bimap-morphisms
   #:bimap-first
   #:bimap-second

   ;; monoidal-category.lisp — Monoidal category (nLab)
   #:monoidal-category
   #:monoidal-base-category
   #:monoidal-tensor
   #:monoidal-unit-object
   #:tensor-objects
   #:tensor-morphisms
   #:associator-at
   #:left-unitor-at
   #:right-unitor-at

   ;; braided-monoidal.lisp — Braided monoidal category (nLab)
   #:braided-monoidal-category
   #:braided-base-monoidal
   #:braiding-forward-fn
   #:braiding-backward-fn
   #:braiding-at
   #:braiding-inverse-at

   ;; symmetric-monoidal.lisp — Symmetric monoidal category (nLab)
   #:symmetric-monoidal-category
   #:symmetry-check

   ;; examples.lisp — Concrete examples for exploration
   #:make-finite-category
   #:make-discrete-category
   #:*set-category*))

(in-package :mwablab)
