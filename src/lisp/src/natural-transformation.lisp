(in-package :mwablab)

;;;; Natural Transformation
;;;;
;;;; Given functors F, G : C → D, a natural transformation η : F ⟹ G
;;;; assigns to each object X ∈ Ob(C) a morphism
;;;;
;;;;   η_X : F(X) → G(X)   in D
;;;;
;;;; such that for every morphism f : X → Y in C, the naturality square commutes:
;;;;
;;;;   F(X) ──F(f)──► F(Y)
;;;;     │               │
;;;;    η_X            η_Y
;;;;     │               │
;;;;     ▼               ▼
;;;;   G(X) ──G(f)──► G(Y)
;;;;
;;;; i.e. η_Y ∘ F(f) = G(f) ∘ η_X.
;;;;
;;;; Vertical composition: given α : F ⟹ G and β : G ⟹ H,
;;;; (β ∘ α)_X = β_X ∘ α_X.
;;;;
;;;; Reference: Stacks Project, Tag 001I.

(defclass natural-transformation ()
  ((name
    :initarg :name
    :accessor nat-trans-name
    :documentation "Human-readable name, e.g. \"η\" or \"unit\".")
   (source
    :initarg :source
    :accessor nat-trans-source
    :type functor
    :documentation "The source functor F in η : F ⟹ G.")
   (target
    :initarg :target
    :accessor nat-trans-target
    :type functor
    :documentation "The target functor G in η : F ⟹ G.")
   (component
    :initarg :component
    :accessor nat-trans-component
    :documentation "Function (x) → η_x, returning the component morphism at object X.
For X ∈ Ob(C), η_X : F(X) → G(X) is a morphism in the target category D.
Must satisfy the naturality condition:
  η_Y ∘ F(f) = G(f) ∘ η_X  for all f : X → Y in C."))
  (:documentation "A natural transformation η : F ⟹ G between functors F, G : C → D.
Stacks Project, Tag 001I.

A natural transformation is a family of morphisms {η_X}_{X ∈ Ob(C)}
indexed by objects of C, each living in the target category D,
satisfying the naturality condition for every morphism in C."))

;;; Generic functions

(defgeneric component-at (nat-trans obj)
  (:documentation "Return the component η_{OBJ} of NAT-TRANS at OBJ.

For η : F ⟹ G and X ∈ Ob(C), returns η_X : F(X) → G(X) in D.

Reference: Stacks Project, Tag 001I."))

(defmethod component-at ((nat-trans natural-transformation) obj)
  (funcall (nat-trans-component nat-trans) obj))

(defgeneric vertical-compose (beta alpha)
  (:documentation "Return the vertical composite β ∘ α of natural transformations ALPHA and BETA.

Given α : F ⟹ G and β : G ⟹ H (functors C → D),
the vertical composite β ∘ α : F ⟹ H has components
  (β ∘ α)_X = β_X ∘ α_X  in D, for each X ∈ Ob(C).

Vertical composition is the composition law in the functor category [C, D].

Reference: Stacks Project, Tag 001I."))

(defmethod vertical-compose ((beta natural-transformation) (alpha natural-transformation))
  (let* ((source-cat (functor-source (nat-trans-source alpha)))
         (target-cat (functor-target (nat-trans-source alpha)))
         (F (nat-trans-source alpha))
         (H (nat-trans-target beta)))
    (declare (ignore source-cat))
    (make-instance 'natural-transformation
      :name (format nil "(~A ∘ ~A)" (nat-trans-name beta) (nat-trans-name alpha))
      :source F
      :target H
      :component (lambda (x)
                   (compose-morphisms target-cat
                                      (component-at beta x)
                                      (component-at alpha x))))))

(defgeneric identity-nat-trans (funct)
  (:documentation "Return the identity natural transformation id_F : F ⟹ F for functor FUNCT.

The identity natural transformation on F : C → D has components
  (id_F)_X = id_{F(X)}  in D, for each X ∈ Ob(C).

It is the identity morphism on F in the functor category [C, D].

Reference: Stacks Project, Tag 001I."))

(defmethod identity-nat-trans ((funct functor))
  (let ((target-cat (functor-target funct)))
    (make-instance 'natural-transformation
      :name (format nil "id_{~A}" (functor-name funct))
      :source funct
      :target funct
      :component (lambda (x)
                   (id-morphism target-cat (fobj funct x))))))
