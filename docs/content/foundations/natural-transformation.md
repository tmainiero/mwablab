---
title: Natural Transformation
---

A *natural transformation* is a morphism between functors.
It is the 2-cell of the 2-category $\Category{Cat}$.

## Definition

Let $\Category{C}$ and $\Category{D}$ be categories,
and let $\Functor{F}, \Functor{G} \colon \Category{C} \to \Category{D}$ be functors.
A **natural transformation** $\NatTrans{\alpha} \colon \Functor{F} \Rightarrow \Functor{G}$
consists of, for each object $X \in \operatorname{Ob}(\Category{C})$,
a morphism

$$\NatTrans{\alpha}_X \colon \Functor{F}(X) \to \Functor{G}(X)$$

in $\Category{D}$, called the **component** of $\NatTrans{\alpha}$ at $X$,
subject to the **naturality condition**:
for every morphism $f \colon X \to Y$ in $\Category{C}$,

$$\Functor{G}(f) \circ \NatTrans{\alpha}_X = \NatTrans{\alpha}_Y \circ \Functor{F}(f).$$

Reference: [Stacks Project, Tag 001I](https://stacks.math.columbia.edu/tag/001I).

## The naturality square

The naturality condition is the commutativity of the following square in $\Category{D}$:

```
       α_X
F(X) ──────► G(X)
  │               │
F(f)│           │G(f)
  │               │
  ▼               ▼
F(Y) ──────► G(Y)
       α_Y
```

Both paths from $\Functor{F}(X)$ to $\Functor{G}(Y)$ agree:
going right then down equals going down then right.

## Haskell

Source: `src/haskell/src/Cat/NaturalTransformation.hs`

```haskell
newtype NatTrans (cat2 :: k2 -> k2 -> Type) (f :: k1 -> k2) (g :: k1 -> k2) = NatTrans
  { component :: forall (a :: k1). cat2 (f a) (g a) }
```

`NatTrans cat2 f g` represents $\NatTrans{\alpha} \colon \Functor{f} \Rightarrow \Functor{g}$
where morphisms live in `cat2`.
The field `component` is the family $\NatTrans{\alpha}_a \colon \Functor{f}(a) \to \Functor{g}(a)$,
universally quantified over all objects `a :: k1`.

The naturality condition is a law, not enforced by the type:
`compose (fmap h) (component alpha) = compose (component alpha) (fmap h)`.

**Identity natural transformation** --- $\id_{\Functor{F}} \colon \Functor{F} \Rightarrow \Functor{F}$,
with each component the identity morphism $(\id_{\Functor{F}})_a = \id_{\Functor{F}(a)}$:

```haskell
idNat :: Category cat2 => NatTrans cat2 f f
idNat = NatTrans id
```

**Vertical composition** --- given $\NatTrans{\alpha} \colon \Functor{F} \Rightarrow \Functor{G}$
and $\NatTrans{\beta} \colon \Functor{G} \Rightarrow \Functor{H}$:

```haskell
vertComp :: Category cat2
         => NatTrans cat2 g h
         -> NatTrans cat2 f g
         -> NatTrans cat2 f h
vertComp (NatTrans beta) (NatTrans alpha) = NatTrans (compose beta alpha)
```

## Agda

Source: `src/agda/Cat/NaturalTransformation.agda`

```agda
record NaturalTransformation {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ : Level}
                             {C : Category o₁ ℓ₁ e₁} {D : Category o₂ ℓ₂ e₂}
                             (F G : Functor C D)
                             : Set (o₁ ⊔ ℓ₁ ⊔ e₁ ⊔ o₂ ⊔ ℓ₂ ⊔ e₂) where
  field
    η           : ∀ (X : C.Obj) → F.F₀ X D.⇒ G.F₀ X
    commute     : ∀ {X Y} (f : X C.⇒ Y)
                → (η Y D.∘ F.F₁ f) D.≈ (G.F₁ f D.∘ η X)
    sym-commute : ∀ {X Y} (f : X C.⇒ Y)
                → (G.F₁ f D.∘ η X) D.≈ (η Y D.∘ F.F₁ f)
```

- `η` --- the component family $\NatTrans{\eta}_X \colon \Functor{F}(X) \to \Functor{G}(X)$.
- `commute` --- the naturality condition $\NatTrans{\eta}_Y \circ \Functor{F}(f) \approx \Functor{G}(f) \circ \NatTrans{\eta}_X$.
- `sym-commute` --- the symmetric direction, provided for convenience (follows from `commute` and the setoid symmetry of $D$).

The three universe levels per category ($o$, $\ell$, $e$) track the sizes of objects, morphisms, and morphism equality respectively.

## Common Lisp

Source: `src/lisp/src/natural-transformation.lisp`

```lisp
(defclass natural-transformation ()
  ((name      :initarg :name      :accessor nat-trans-name)
   (source    :initarg :source    :accessor nat-trans-source)
   (target    :initarg :target    :accessor nat-trans-target)
   (component :initarg :component :accessor nat-trans-component)))
```

A `natural-transformation` holds the source functor $\Functor{F}$, target functor $\Functor{G}$,
and a Lisp function `(lambda (x) ...)` encoding the component assignment $X \mapsto \NatTrans{\eta}_X$.

**Retrieving a component:**

```lisp
(defgeneric component-at (nat-trans obj))
;; Returns η_{OBJ} : F(OBJ) → G(OBJ) in D.

(defmethod component-at ((nat-trans natural-transformation) obj)
  (funcall (nat-trans-component nat-trans) obj))
```

**Vertical composition:**

```lisp
(defgeneric vertical-compose (beta alpha))
;; Returns β ∘ α : F ⟹ H, given α : F ⟹ G and β : G ⟹ H.

(defmethod vertical-compose ((beta natural-transformation) (alpha natural-transformation))
  (make-instance 'natural-transformation
    :name (format nil "(~A ∘ ~A)" (nat-trans-name beta) (nat-trans-name alpha))
    :source (nat-trans-source alpha)
    :target (nat-trans-target beta)
    :component (lambda (x)
                 (compose-morphisms target-cat
                                    (component-at beta x)
                                    (component-at alpha x)))))
```

## Vertical composition

Given $\NatTrans{\alpha} \colon \Functor{F} \Rightarrow \Functor{G}$
and $\NatTrans{\beta} \colon \Functor{G} \Rightarrow \Functor{H}$,
their **vertical composite** $\NatTrans{\beta} \circ \NatTrans{\alpha} \colon \Functor{F} \Rightarrow \Functor{H}$
has components

$$(\NatTrans{\beta} \circ \NatTrans{\alpha})_X = \NatTrans{\beta}_X \circ \NatTrans{\alpha}_X.$$

Naturality of $\NatTrans{\beta} \circ \NatTrans{\alpha}$ follows by pasting the naturality squares
of $\NatTrans{\alpha}$ and $\NatTrans{\beta}$:

$$\Functor{H}(f) \circ (\NatTrans{\beta} \circ \NatTrans{\alpha})_X
  = \Functor{H}(f) \circ \NatTrans{\beta}_X \circ \NatTrans{\alpha}_X
  = \NatTrans{\beta}_Y \circ \Functor{G}(f) \circ \NatTrans{\alpha}_X
  = \NatTrans{\beta}_Y \circ \NatTrans{\alpha}_Y \circ \Functor{F}(f)
  = (\NatTrans{\beta} \circ \NatTrans{\alpha})_Y \circ \Functor{F}(f).$$

Vertical composition is associative and admits $\id_{\Functor{F}}$ as a two-sided unit,
making functors $\Category{C} \to \Category{D}$ and natural transformations between them
into the **functor category** $[\Category{C}, \Category{D}]$.

In Haskell: `vertComp beta alpha` computes $\NatTrans{\beta} \circ \NatTrans{\alpha}$ by composing
the components pointwise via the underlying `Category` instance.

## Examples

### $\NatTrans{\eta} \colon \id \Rightarrow \operatorname{Maybe}$ --- the "Just" transformation

The functor $\operatorname{Maybe} \colon \Category{Hask} \to \Category{Hask}$
sends each type $A$ to $\operatorname{Maybe}\, A$ and each function $f \colon A \to B$
to $\operatorname{fmap}\, f \colon \operatorname{Maybe}\, A \to \operatorname{Maybe}\, B$.

The natural transformation $\NatTrans{\eta} \colon \id \Rightarrow \operatorname{Maybe}$
has component $\NatTrans{\eta}_A = \mathtt{Just} \colon A \to \operatorname{Maybe}\, A$ at each type $A$.

**Naturality check.**
For any $f \colon A \to B$, we must verify
$\operatorname{fmap}\, f \circ \mathtt{Just}_A = \mathtt{Just}_B \circ f$:

```
id(A) = A ──Just──► Maybe A
           │                  │
         f │             fmap f│
           │                  │
id(B) = B ──Just──► Maybe B
```

Both paths agree: $\mathtt{Just}\, (f\, x) = \operatorname{fmap}\, f\, (\mathtt{Just}\, x)$
by definition of `fmap` for `Maybe`.

In Haskell this is:

```haskell
justNat :: NatTrans (->) Identity Maybe
justNat = NatTrans (Just . runIdentity)
```

**Naturality test (property-based):**
For all `f :: a -> b` and `x :: a`,

```haskell
fmap f (component justNat x) == component justNat (f x)
-- i.e.  fmap f (Just x) == Just (f x)
-- which holds by the Functor law for Maybe
```
