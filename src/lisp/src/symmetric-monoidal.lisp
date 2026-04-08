(in-package :mwablab)

;;;; Symmetric Monoidal Category
;;;;
;;;; A symmetric monoidal category is a braided monoidal category
;;;; where the braiding is self-inverse:
;;;;
;;;;   σ_{B,A} ∘ σ_{A,B} = id_{A⊗B}
;;;;
;;;; for all objects A, B.  Equivalently, σ⁻¹_{A,B} = σ_{B,A}.
;;;;
;;;; This collapses the two hexagon axioms into a single condition
;;;; and makes the braiding involutive.  Most monoidal categories
;;;; arising in practice (Set, Vect, Ab, ...) are symmetric.
;;;;
;;;; Reference: nLab, symmetric+monoidal+category.

;;; ── Class ─────────────────────────────────────────────────────

(defclass symmetric-monoidal-category (braided-monoidal-category)
  ()
  (:documentation "A symmetric monoidal category (C, ⊗, I, α, λ, ρ, σ).

A braided monoidal category where the braiding satisfies the symmetry
condition σ_{B,A} ∘ σ_{A,B} = id_{A⊗B} for all objects A, B.

In a symmetric monoidal category, the inverse braiding is given by
swapping the arguments: σ⁻¹_{A,B} = σ_{B,A}.  Instances should
ensure that braiding-backward is consistent with this (i.e., the
backward braiding at (A, B) equals the forward braiding at (B, A)).

Reference: nLab, symmetric+monoidal+category."))

;;; ── Generic functions ─────────────────────────────────────────

(defgeneric symmetry-check (smc a b)
  (:documentation "Check the symmetry condition σ_{B,A} ∘ σ_{A,B} = id_{A⊗B}.

Given a symmetric monoidal category SMC and objects A, B, computes
both composites and tests equality.  Returns T if the symmetry law
holds, NIL otherwise.

This is a runtime verification aid; the law is a mathematical
requirement, not merely a convention.

Reference: nLab, symmetric+monoidal+category."))

(defmethod symmetry-check ((smc symmetric-monoidal-category) a b)
  (let* ((mon (braided-base-monoidal smc))
         (cat (monoidal-base-category mon))
         (sigma-ab (braiding-at smc a b))
         (sigma-ba (braiding-at smc b a))
         (composite (compose-morphisms cat sigma-ba sigma-ab))
         (tensor-ab (tensor-objects mon a b))
         (identity  (id-morphism cat tensor-ab)))
    (equal composite identity)))
