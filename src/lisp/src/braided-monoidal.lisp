(in-package :mwablab)

;;;; Braided Monoidal Category
;;;;
;;;; A braided monoidal category is a monoidal category (C, ⊗, I, α, λ, ρ)
;;;; equipped with a natural isomorphism (the braiding)
;;;;
;;;;   σ_{A,B} : A ⊗ B → B ⊗ A
;;;;
;;;; satisfying two hexagon coherence axioms.
;;;;
;;;; Hexagon 1:
;;;;   α(B,C,A) ∘ σ(A, B⊗C) ∘ α(A,B,C)
;;;;     = (id_B ⊗ σ(A,C)) ∘ α(B,A,C) ∘ (σ(A,B) ⊗ id_C)
;;;;
;;;; Hexagon 2:
;;;;   α⁻¹(C,A,B) ∘ σ(A⊗B, C) ∘ α⁻¹(A,B,C)
;;;;     = (σ(A,C) ⊗ id_B) ∘ α⁻¹(A,C,B) ∘ (id_A ⊗ σ(B,C))
;;;;
;;;; Reference: nLab, braided+monoidal+category.

;;; ── Class ─────────────────────────────────────────────────────

(defclass braided-monoidal-category ()
  ((base-monoidal
    :initarg :base-monoidal
    :accessor braided-base-monoidal
    :type monoidal-category
    :documentation "The underlying monoidal category (C, ⊗, I, α, λ, ρ).")
   (braiding-forward
    :initarg :braiding-forward
    :accessor braided-braiding-forward
    :documentation "Function (a b) → morphism σ_{A,B} : A ⊗ B → B ⊗ A.
The forward component of the braiding natural isomorphism.")
   (braiding-backward
    :initarg :braiding-backward
    :accessor braided-braiding-backward
    :documentation "Function (a b) → morphism σ⁻¹_{A,B} : B ⊗ A → A ⊗ B.
The backward component of the braiding natural isomorphism.
Must satisfy σ⁻¹ ∘ σ = id and σ ∘ σ⁻¹ = id."))
  (:documentation "A braided monoidal category (C, ⊗, I, α, λ, ρ, σ).

A monoidal category equipped with a braiding natural isomorphism
σ_{A,B} : A ⊗ B → B ⊗ A satisfying the two hexagon coherence axioms.
The hexagon axioms ensure compatibility of the braiding with the
associator.

Reference: nLab, braided+monoidal+category."))

;;; ── Generic functions ─────────────────────────────────────────

(defgeneric braiding-at (bmc a b)
  (:documentation "Return the braiding morphism σ_{A,B} : A ⊗ B → B ⊗ A.

Given a braided monoidal category BMC and objects A, B in the base
category, returns the forward component of the braiding natural
isomorphism at the pair (A, B).

Reference: nLab, braided+monoidal+category."))

(defmethod braiding-at ((bmc braided-monoidal-category) a b)
  (funcall (braided-braiding-forward bmc) a b))

(defgeneric braiding-inverse-at (bmc a b)
  (:documentation "Return the inverse braiding morphism σ⁻¹_{A,B} : B ⊗ A → A ⊗ B.

Given a braided monoidal category BMC and objects A, B in the base
category, returns the backward component of the braiding at (A, B).

Must satisfy: σ⁻¹_{A,B} ∘ σ_{A,B} = id_{A⊗B}.

Reference: nLab, braided+monoidal+category."))

(defmethod braiding-inverse-at ((bmc braided-monoidal-category) a b)
  (funcall (braided-braiding-backward bmc) a b))
