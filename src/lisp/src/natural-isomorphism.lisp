(in-package :mwablab)

;;;; Natural Isomorphism
;;;;
;;;; A natural isomorphism α : F ≅ G between functors F, G : C → D
;;;; is a pair of natural transformations
;;;;
;;;;   α   : F ⟹ G   (forward)
;;;;   α⁻¹ : G ⟹ F   (backward)
;;;;
;;;; such that α⁻¹ ∘ α = id_F and α ∘ α⁻¹ = id_G (vertical composition).
;;;; Equivalently, every component α_X is an isomorphism in D.
;;;;
;;;; Natural isomorphisms are the isomorphisms in the functor category [C, D].
;;;;
;;;; Reference: nLab, natural+isomorphism.

(defclass natural-isomorphism ()
  ((forward
    :initarg :forward
    :accessor nat-iso-forward
    :type natural-transformation
    :documentation "The forward natural transformation α : F ⟹ G.")
   (backward
    :initarg :backward
    :accessor nat-iso-backward
    :type natural-transformation
    :documentation "The backward natural transformation α⁻¹ : G ⟹ F.
Must satisfy: α⁻¹ ∘ α = id_F and α ∘ α⁻¹ = id_G (vertical composition)."))
  (:documentation "A natural isomorphism α : F ≅ G between functors F, G : C → D.
Consists of a forward and backward natural transformation that are
mutually inverse under vertical composition.

Reference: nLab, natural+isomorphism."))

;;; Generic functions

(defgeneric invert-nat-iso (nat-iso)
  (:documentation "Return the inverse natural isomorphism α⁻¹ : G ≅ F.

Given α : F ≅ G, returns the natural isomorphism with forward and
backward components swapped.

Reference: nLab, natural+isomorphism."))

(defmethod invert-nat-iso ((nat-iso natural-isomorphism))
  (make-instance 'natural-isomorphism
    :forward (nat-iso-backward nat-iso)
    :backward (nat-iso-forward nat-iso)))

(defgeneric compose-nat-iso (beta alpha)
  (:documentation "Return the composite natural isomorphism β ∘ α : F ≅ H.

Given α : F ≅ G and β : G ≅ H, the composite has
forward components β_X ∘ α_X and backward components α⁻¹_X ∘ β⁻¹_X.

Reference: nLab, natural+isomorphism."))

(defmethod compose-nat-iso ((beta natural-isomorphism) (alpha natural-isomorphism))
  (make-instance 'natural-isomorphism
    :forward (vertical-compose (nat-iso-forward beta) (nat-iso-forward alpha))
    :backward (vertical-compose (nat-iso-backward alpha) (nat-iso-backward beta))))

(defgeneric identity-nat-iso (funct)
  (:documentation "Return the identity natural isomorphism id_F : F ≅ F.

Both forward and backward components are identity natural transformations.

Reference: nLab, natural+isomorphism."))

(defmethod identity-nat-iso ((funct functor))
  (let ((id-nat (identity-nat-trans funct)))
    (make-instance 'natural-isomorphism
      :forward id-nat
      :backward id-nat)))
