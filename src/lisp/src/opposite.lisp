(in-package :mwablab)

;;;; Opposite Category
;;;;
;;;; Given a category C, the opposite category C^op has:
;;;;   - the same objects: Ob(C^op) = Ob(C)
;;;;   - reversed hom-sets: Hom_{C^op}(X, Y) = Hom_C(Y, X)
;;;;   - same identities:  id^op_X = id_X
;;;;   - reversed composition: g ∘^op f = f ∘ g  (in C)
;;;;
;;;; The opposite category is used to express contravariance uniformly:
;;;; a contravariant functor C → D is a covariant functor C^op → D.
;;;;
;;;; Reference: Stacks Project, Tag 0013.

(defun opposite-category (cat)
  "Construct the opposite category C^op from CAT.

Ob(C^op) = Ob(C)
Hom_{C^op}(X, Y) = Hom_C(Y, X)
id^op_X = id_X
g ∘^op f = f ∘ g  (composition in C)

The involution (C^op)^op is isomorphic to C.

Reference: Stacks Project, Tag 0013."
  (make-instance 'category
    :name (format nil "~A^op" (category-name cat))
    :objects (category-objects cat)
    :hom (lambda (x y) (funcall (category-hom cat) y x))
    :identity (category-identity cat)
    :compose (lambda (g f) (funcall (category-compose cat) f g))))
