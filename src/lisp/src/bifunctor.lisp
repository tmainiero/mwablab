(in-package :mwablab)

;;;; Bifunctor
;;;;
;;;; A bifunctor F : C x D -> E is a functor from the product category
;;;; C x D to E.  Equivalently, a map that is functorial in each
;;;; argument separately, with a compatibility condition.
;;;;
;;;; Given morphisms f : X1 -> X2 in C and g : Y1 -> Y2 in D,
;;;;   bimap(f, g) : F(X1,Y1) -> F(X2,Y2) in E.
;;;;
;;;; Laws:
;;;;   bimap(id, id) = id
;;;;   bimap(f2 . f1, g2 . g1) = bimap(f2, g2) . bimap(f1, g1)
;;;;
;;;; Reference: nLab, bifunctor.

;;; Bifunctor class

(defclass bifunctor ()
  ((source-cat-1
    :initarg :source-cat-1
    :accessor bifunctor-source-cat-1
    :type category
    :documentation "The first source category C in F : C x D -> E.")
   (source-cat-2
    :initarg :source-cat-2
    :accessor bifunctor-source-cat-2
    :type category
    :documentation "The second source category D in F : C x D -> E.")
   (target-cat
    :initarg :target-cat
    :accessor bifunctor-target-cat
    :type category
    :documentation "The target category E in F : C x D -> E.")
   (bimap-fn
    :initarg :bimap-fn
    :accessor bifunctor-bimap-fn
    :documentation "Function (f g) -> bimap(f, g).
Takes a morphism f in C and a morphism g in D,
returns a morphism bimap(f, g) : F(X1,Y1) -> F(X2,Y2) in E.

Must satisfy:
  - bimap(id_X, id_Y) = id_{F(X,Y)}
  - bimap(f2 . f1, g2 . g1) = bimap(f2, g2) . bimap(f1, g1)"))
  (:documentation "A bifunctor F : C x D -> E. nLab, bifunctor.

A bifunctor is a functor from a product category C x D to a category E,
equivalently a map that is functorial in each variable separately."))

;;; Generic functions

(defgeneric bimap-morphisms (bf f g)
  (:documentation "Apply bifunctor BF to morphisms F (in C) and G (in D),
returning bimap(f, g) in the target category E.

For F : C x D -> E, f : X1 -> X2 in C, g : Y1 -> Y2 in D,
returns bimap(f, g) : F(X1,Y1) -> F(X2,Y2) in E.

Reference: nLab, bifunctor."))

(defmethod bimap-morphisms ((bf bifunctor) f g)
  (funcall (bifunctor-bimap-fn bf) f g))

(defgeneric bimap-first (bf f obj)
  (:documentation "Apply bifunctor BF in the first argument only.

Holds the second argument at the identity morphism of OBJ (an object
of the second source category D).  Returns bimap(f, id_OBJ).

This is the partial functor F(-, d) applied to f.

Reference: nLab, bifunctor."))

(defmethod bimap-first ((bf bifunctor) f obj)
  (bimap-morphisms bf f (id-morphism (bifunctor-source-cat-2 bf) obj)))

(defgeneric bimap-second (bf g obj)
  (:documentation "Apply bifunctor BF in the second argument only.

Holds the first argument at the identity morphism of OBJ (an object
of the first source category C).  Returns bimap(id_OBJ, g).

This is the partial functor F(c, -) applied to g.

Reference: nLab, bifunctor."))

(defmethod bimap-second ((bf bifunctor) g obj)
  (bimap-morphisms bf (id-morphism (bifunctor-source-cat-1 bf) obj) g))
