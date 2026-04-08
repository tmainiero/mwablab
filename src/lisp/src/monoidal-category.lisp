(in-package :mwablab)

;;;; Monoidal Category
;;;;
;;;; A monoidal category (C, ⊗, I, α, λ, ρ) consists of:
;;;;   - a category C
;;;;   - a bifunctor ⊗ : C × C → C  (the tensor product)
;;;;   - a unit object I ∈ Ob(C)
;;;;   - a natural isomorphism α_{A,B,C} : (A ⊗ B) ⊗ C → A ⊗ (B ⊗ C)  (associator)
;;;;   - a natural isomorphism λ_A : I ⊗ A → A  (left unitor)
;;;;   - a natural isomorphism ρ_A : A ⊗ I → A  (right unitor)
;;;;
;;;; subject to the pentagon and triangle coherence axioms.
;;;;
;;;; The pentagon axiom states that for all objects A, B, C, D the
;;;; diagram of associators
;;;;
;;;;   ((A ⊗ B) ⊗ C) ⊗ D  ──→  (A ⊗ B) ⊗ (C ⊗ D)  ──→  A ⊗ (B ⊗ (C ⊗ D))
;;;;           |                                                   ↑
;;;;           ↓                                                   |
;;;;   (A ⊗ (B ⊗ C)) ⊗ D  ────────────────────────→  A ⊗ ((B ⊗ C) ⊗ D)
;;;;
;;;; commutes.
;;;;
;;;; The triangle axiom states that for all objects A, B the diagram
;;;;
;;;;   (A ⊗ I) ⊗ B  ──α──→  A ⊗ (I ⊗ B)
;;;;         \                    /
;;;;      ρ⊗id              id⊗λ
;;;;           \              /
;;;;            →   A ⊗ B   ←
;;;;
;;;; commutes.
;;;;
;;;; Reference: nLab, monoidal+category.

;;; ── Class ─────────────────────────────────────────────────────

(defclass monoidal-category ()
  ((base-category
    :initarg :base-category
    :accessor monoidal-base-category
    :type category
    :documentation "The underlying category C.")
   (tensor
    :initarg :tensor
    :accessor monoidal-tensor
    :type bifunctor
    :documentation "The tensor bifunctor ⊗ : C × C → C.")
   (unit-object
    :initarg :unit-object
    :accessor monoidal-unit
    :documentation "The unit object I ∈ Ob(C).")
   (associator-forward
    :initarg :associator-forward
    :accessor monoidal-associator-forward
    :documentation "Function (a b c) → morphism α_{A,B,C} : (A ⊗ B) ⊗ C → A ⊗ (B ⊗ C).
The forward component of the associator natural isomorphism.")
   (associator-backward
    :initarg :associator-backward
    :accessor monoidal-associator-backward
    :documentation "Function (a b c) → morphism α⁻¹_{A,B,C} : A ⊗ (B ⊗ C) → (A ⊗ B) ⊗ C.
The backward component of the associator natural isomorphism.
Must satisfy α⁻¹ ∘ α = id and α ∘ α⁻¹ = id.")
   (left-unitor-forward
    :initarg :left-unitor-forward
    :accessor monoidal-left-unitor-forward
    :documentation "Function (a) → morphism λ_A : I ⊗ A → A.
The forward component of the left unitor natural isomorphism.")
   (left-unitor-backward
    :initarg :left-unitor-backward
    :accessor monoidal-left-unitor-backward
    :documentation "Function (a) → morphism λ⁻¹_A : A → I ⊗ A.
The backward component of the left unitor.
Must satisfy λ⁻¹ ∘ λ = id and λ ∘ λ⁻¹ = id.")
   (right-unitor-forward
    :initarg :right-unitor-forward
    :accessor monoidal-right-unitor-forward
    :documentation "Function (a) → morphism ρ_A : A ⊗ I → A.
The forward component of the right unitor natural isomorphism.")
   (right-unitor-backward
    :initarg :right-unitor-backward
    :accessor monoidal-right-unitor-backward
    :documentation "Function (a) → morphism ρ⁻¹_A : A → A ⊗ I.
The backward component of the right unitor.
Must satisfy ρ⁻¹ ∘ ρ = id and ρ ∘ ρ⁻¹ = id."))
  (:documentation "A monoidal category (C, ⊗, I, α, λ, ρ).

A category equipped with a tensor product bifunctor, a unit object, and
natural isomorphisms (associator, left unitor, right unitor) satisfying
the pentagon and triangle coherence axioms.

Reference: nLab, monoidal+category."))

;;; ── Generic functions ─────────────────────────────────────────

(defgeneric tensor-objects (mon a b)
  (:documentation "Compute the tensor product A ⊗ B at the object level.

Given a monoidal category MON and objects A, B in the base category,
returns the object A ⊗ B = F₀(A, B) where F₀ is the object map of
the tensor bifunctor.

Reference: nLab, monoidal+category."))

(defmethod tensor-objects ((mon monoidal-category) a b)
  "Object-level tensor: returns A ⊗ B as a value.
Delegates to the object-map of the tensor bifunctor.
If the bifunctor stores an explicit object-map, use it;
otherwise fall back to the convention that bimap(id_A, id_B)
applied to the pair (A, B) yields the tensor product object."
  (let ((base (monoidal-base-category mon)))
    (funcall (bimap-morphisms (monoidal-tensor mon)
                              (id-morphism base a)
                              (id-morphism base b))
             (cons a b))))

(defgeneric tensor-morphisms (mon f g)
  (:documentation "Compute the tensor product f ⊗ g at the morphism level.

Given a monoidal category MON and morphisms f : A₁ → A₂, g : B₁ → B₂
in the base category, returns bimap(f, g) : A₁ ⊗ B₁ → A₂ ⊗ B₂.

This delegates to the bimap of the tensor bifunctor.

Reference: nLab, monoidal+category."))

(defmethod tensor-morphisms ((mon monoidal-category) f g)
  (bimap-morphisms (monoidal-tensor mon) f g))

(defgeneric associator-at (mon a b c)
  (:documentation "Return the associator morphism α_{A,B,C} : (A ⊗ B) ⊗ C → A ⊗ (B ⊗ C).

Given objects A, B, C in the base category of the monoidal category MON,
returns the forward component of the associator natural isomorphism at
the triple (A, B, C).

Reference: nLab, monoidal+category."))

(defmethod associator-at ((mon monoidal-category) a b c)
  (funcall (monoidal-associator-forward mon) a b c))

(defgeneric left-unitor-at (mon a)
  (:documentation "Return the left unitor morphism λ_A : I ⊗ A → A.

Given an object A in the base category of the monoidal category MON,
returns the forward component of the left unitor at A.

Reference: nLab, monoidal+category."))

(defmethod left-unitor-at ((mon monoidal-category) a)
  (funcall (monoidal-left-unitor-forward mon) a))

(defgeneric right-unitor-at (mon a)
  (:documentation "Return the right unitor morphism ρ_A : A ⊗ I → A.

Given an object A in the base category of the monoidal category MON,
returns the forward component of the right unitor at A.

Reference: nLab, monoidal+category."))

(defmethod right-unitor-at ((mon monoidal-category) a)
  (funcall (monoidal-right-unitor-forward mon) a))
