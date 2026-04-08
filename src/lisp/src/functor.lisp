(in-package :mwablab)

;;;; Functor
;;;;
;;;; A functor F : C → D between categories C and D consists of:
;;;;   - an object map:   Ob(C) → Ob(D),    X ↦ F(X)
;;;;   - a morphism map:  Hom_C(X,Y) → Hom_D(F(X),F(Y)),  f ↦ F(f)
;;;;
;;;; satisfying:
;;;;   - F(id_X) = id_{F(X)}                    (preservation of identities)
;;;;   - F(g ∘ f) = F(g) ∘ F(f)                 (preservation of composition)
;;;;
;;;; Reference: Stacks Project, Tag 001B; nLab: functor.

(defclass functor ()
  ((name
    :initarg :name
    :accessor functor-name
    :documentation "Human-readable name for the functor, e.g. \"F\" or \"Hom(A,-)\".)")
   (source
    :initarg :source
    :accessor functor-source
    :type category
    :documentation "The source (domain) category C in F : C → D.")
   (target
    :initarg :target
    :accessor functor-target
    :type category
    :documentation "The target (codomain) category D in F : C → D.")
   (obj-map
    :initarg :obj-map
    :accessor functor-obj-map
    :documentation "Function (x) → F(x) mapping objects of C to objects of D.
Must be defined for every object x ∈ Ob(C).")
   (mor-map
    :initarg :mor-map
    :accessor functor-mor-map
    :documentation "Function (f) → F(f) mapping morphisms of C to morphisms of D.
For f : X → Y in C, F(f) : F(X) → F(Y) in D.
Must satisfy:
  - F(id_X) = id_{F(X)}
  - F(g ∘ f) = F(g) ∘ F(f)"))
  (:documentation "A functor F : C → D. Stacks Project, Tag 001B.

A functor encodes a structure-preserving map between categories,
sending objects to objects and morphisms to morphisms while
respecting identities and composition."))

;;; Generic functions

(defgeneric fobj (funct object)
  (:documentation "Apply functor FUNCT to OBJECT, returning F(OBJECT) in the target category.

For F : C → D and X ∈ Ob(C), returns F(X) ∈ Ob(D).

Reference: Stacks Project, Tag 001B."))

(defmethod fobj ((funct functor) object)
  (funcall (functor-obj-map funct) object))

(defgeneric fmap (funct morphism)
  (:documentation "Apply functor FUNCT to MORPHISM, returning F(MORPHISM) in the target category.

For F : C → D and f : X → Y in C, returns F(f) : F(X) → F(Y) in D.

The functor laws must hold:
  - fmap F (id-morphism X) = id-morphism (fobj F X)
  - fmap F (compose g f)   = compose (fmap F g) (fmap F f)

Reference: Stacks Project, Tag 001B."))

(defmethod fmap ((funct functor) morphism)
  (funcall (functor-mor-map funct) morphism))
