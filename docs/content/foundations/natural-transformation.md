---
title: Natural Transformation
---

A *natural transformation* is a morphism between functors.
It is the 2-cell of the 2-category $\caty{Cat}$.

## Definition

Let $\caty{C}$ and $\caty{D}$ be categories,
and let $\fun{F}, \fun{G} \colon \caty{C} \to \caty{D}$ be functors.
A **natural transformation** $\nat{\alpha} \colon \fun{F} \Rightarrow \fun{G}$
consists of, for each object $X \in \operatorname{Ob}(\caty{C})$,
a morphism

$$\nat{\alpha}_X \colon \fun{F}(X) \to \fun{G}(X)$$

in $\caty{D}$, called the **component** of $\nat{\alpha}$ at $X$,
subject to the **naturality condition**:
for every morphism $f \colon X \to Y$ in $\caty{C}$,

$$\fun{G}(f) \circ \nat{\alpha}_X = \nat{\alpha}_Y \circ \fun{F}(f).$$

Reference: [Stacks Project, Tag 0015](https://stacks.math.columbia.edu/tag/0015).

## The naturality square

The naturality condition is the commutativity of the following square in $\caty{D}$:

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

Both paths from $\fun{F}(X)$ to $\fun{G}(Y)$ agree:
going right then down equals going down then right.

## Haskell

Source: `src/haskell/src/Cat/NaturalTransformation.hs`

```haskell
newtype NatTrans (cat2 :: k2 -> k2 -> Type) (f :: k1 -> k2) (g :: k1 -> k2) = NatTrans
  { component :: forall (a :: k1). cat2 (f a) (g a) }
```

`NatTrans cat2 f g` represents $\nat{\alpha} \colon \fun{f} \Rightarrow \fun{g}$
where morphisms live in `cat2`.
The field `component` is the family $\nat{\alpha}_a \colon \fun{f}(a) \to \fun{g}(a)$,
universally quantified over all objects `a :: k1`.

The naturality condition is a law, not enforced by the type:
`compose (fmap h) (component alpha) = compose (component alpha) (fmap h)`.

**Identity natural transformation** --- $\id_{\fun{F}} \colon \fun{F} \Rightarrow \fun{F}$,
with each component the identity morphism $(\id_{\fun{F}})_a = \id_{\fun{F}(a)}$:

```haskell
idNat :: Category cat2 => NatTrans cat2 f f
idNat = NatTrans id
```

**Vertical composition** --- given $\nat{\alpha} \colon \fun{F} \Rightarrow \fun{G}$
and $\nat{\beta} \colon \fun{G} \Rightarrow \fun{H}$:

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

- `η` --- the component family $\nat{\eta}_X \colon \fun{F}(X) \to \fun{G}(X)$.
- `commute` --- the naturality condition $\nat{\eta}_Y \circ \fun{F}(f) \approx \fun{G}(f) \circ \nat{\eta}_X$.
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

A `natural-transformation` holds the source functor $\fun{F}$, target functor $\fun{G}$,
and a Lisp function `(lambda (x) ...)` encoding the component assignment $X \mapsto \nat{\eta}_X$.

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

Given $\nat{\alpha} \colon \fun{F} \Rightarrow \fun{G}$
and $\nat{\beta} \colon \fun{G} \Rightarrow \fun{H}$,
their **vertical composite** $\nat{\beta} \circ \nat{\alpha} \colon \fun{F} \Rightarrow \fun{H}$
has components

$$(\nat{\beta} \circ \nat{\alpha})_X = \nat{\beta}_X \circ \nat{\alpha}_X.$$

Naturality of $\nat{\beta} \circ \nat{\alpha}$ follows by pasting the naturality squares
of $\nat{\alpha}$ and $\nat{\beta}$:

$$\fun{H}(f) \circ (\nat{\beta} \circ \nat{\alpha})_X
  = \fun{H}(f) \circ \nat{\beta}_X \circ \nat{\alpha}_X
  = \nat{\beta}_Y \circ \fun{G}(f) \circ \nat{\alpha}_X
  = \nat{\beta}_Y \circ \nat{\alpha}_Y \circ \fun{F}(f)
  = (\nat{\beta} \circ \nat{\alpha})_Y \circ \fun{F}(f).$$

Vertical composition is associative and admits $\id_{\fun{F}}$ as a two-sided unit,
making functors $\caty{C} \to \caty{D}$ and natural transformations between them
into the **functor category** $[\caty{C}, \caty{D}]$.

In Haskell: `vertComp beta alpha` computes $\nat{\beta} \circ \nat{\alpha}$ by composing
the components pointwise via the underlying `Category` instance.

## Examples

### $\nat{\eta} \colon \id \Rightarrow \operatorname{Maybe}$ --- the "Just" transformation

The functor $\operatorname{Maybe} \colon \caty{Hask} \to \caty{Hask}$
sends each type $A$ to $\operatorname{Maybe}\, A$ and each function $f \colon A \to B$
to $\operatorname{fmap}\, f \colon \operatorname{Maybe}\, A \to \operatorname{Maybe}\, B$.

The natural transformation $\nat{\eta} \colon \id \Rightarrow \operatorname{Maybe}$
has component $\nat{\eta}_A = \mathtt{Just} \colon A \to \operatorname{Maybe}\, A$ at each type $A$.

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
