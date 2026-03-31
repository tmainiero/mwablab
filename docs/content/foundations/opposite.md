---
title: Opposite Category
---

## Definition

Let $\Category{C}$ be a category. The **opposite category** $\Category{C}^\op$ has the same
objects as $\Category{C}$, with hom-sets reversed:

$$\Hom_{\Category{C}^\op}(X, Y) = \Hom_{\Category{C}}(Y, X).$$

Identities are unchanged: $\id^\op_X = \id_X$. Composition reverses direction. Given
$f \in \Hom_{\Category{C}^\op}(X, Y)$ and $g \in \Hom_{\Category{C}^\op}(Y, Z)$ — that is,
$f : Y \to X$ and $g : Z \to Y$ in $\Category{C}$ — the opposite composition is

$$g \circ^\op f = f \circ g \;\in\; \Hom_{\Category{C}}(Z, X) = \Hom_{\Category{C}^\op}(X, Z).$$

The axioms follow immediately from $\Category{C}$: associativity of $\circ^\op$ is associativity
of $\circ$ with arguments relabelled; left and right identity laws swap roles.

*Reference: Stacks Project Tag 001M.*

---

## Haskell

Source: `src/haskell/src/Cat/Opposite.hs`

The opposite category is captured by a single newtype that swaps the source and target
indices:

```haskell
newtype Op (cat :: k -> k -> Type) (a :: k) (b :: k) = Op { getOp :: cat b a }
```

`Op cat a b` holds a morphism of type `cat b a`, making the index reversal
explicit in the type. `getOp` unwraps it.

The `Category` instance reverses composition and leaves identity alone:

```haskell
instance Category cat => Category (Op cat) where
  id              = Op id
  compose (Op f) (Op g) = Op (compose g f)
```

For the record-based interface, `oppositeData` transforms a `CategoryData` value:

```haskell
oppositeData :: CategoryData hom -> CategoryData (Op hom)
oppositeData (CatData ident comp) = CatData
  { catIdentity = Op ident
  , catCompose  = \(Op f) (Op g) -> Op (comp g f)
  }
```

---

## Agda

Source: `src/agda/Cat/Opposite.agda`

The postfix operator `_op` constructs $\Category{C}^\op$ from any `Category` record.
The key moves are two `flip`s:

```agda
_op : ∀ {o ℓ e} → Category o ℓ e → Category o ℓ e
C op = record
  { _⇒_       = flip _⇒_
  ; _∘_       = flip _∘_
  ; assoc     = sym-assoc
  ; sym-assoc = assoc
  ; identityˡ = identityʳ
  ; identityʳ = identityˡ
  ; ∘-resp-≈  = flip ∘-resp-≈
  }
  where open Category C
```

`flip _⇒_` reverses the hom-set; `flip _∘_` reverses composition.
The associativity proofs swap (`assoc ↔ sym-assoc`) and the identity proofs
swap (`identityˡ ↔ identityʳ`) — exactly reflecting the composition reversal.
All other fields (`Obj`, `_≈_`, `id`, `equiv`, `identity²`) are unchanged.

*Reference: Stacks Project Tag 001M.*

---

## Common Lisp

Source: `src/lisp/src/opposite.lisp`

```lisp
(defun opposite-category (cat)
  (make-instance 'category
    :name     (format nil "~A^op" (category-name cat))
    :objects  (category-objects cat)
    :hom      (lambda (x y) (funcall (category-hom cat) y x))
    :identity (category-identity cat)
    :compose  (lambda (g f) (funcall (category-compose cat) f g))))
```

The `:hom` closure swaps arguments; the `:compose` closure reverses argument
order. Objects and identities are shared with the original category.

*Reference: Stacks Project Tag 001M.*

---

## Key property: $(\Category{C}^\op)^\op = \Category{C}$

The opposite construction is an involution. Double reversal recovers the original
hom-sets:

$$\Hom_{(\Category{C}^\op)^\op}(X, Y)
  = \Hom_{\Category{C}^\op}(Y, X)
  = \Hom_{\Category{C}}(X, Y),$$

and composition $f \circ^{\op\op} g = g \circ^\op f = f \circ g$ agrees with $\Category{C}$.

Source: `src/haskell/test/Cat/OppositeSpec.hs`

In Haskell this is witnessed by `getOp . getOp`:

```haskell
-- The involution: unwrapping Op twice recovers the original morphism.
prop_doubleOp :: cat a b -> Bool
prop_doubleOp f = getOp (getOp (Op (Op f))) == f
```

The type `Op (Op cat) a b` holds `cat a b`, so the round-trip is the identity on
both types and terms.

---

## Why it matters

**Contravariant functors.** A contravariant functor $\Functor{F} : \Category{C} \to \Category{D}$
reverses morphisms: for $f : X \to Y$ in $\Category{C}$ it produces
$\Functor{F}(f) : \Functor{F}(Y) \to \Functor{F}(X)$ in $\Category{D}$, with composition satisfying
$\Functor{F}(g \circ f) = \Functor{F}(f) \circ \Functor{F}(g)$.
The opposite category absorbs the reversal: a contravariant functor from $\Category{C}$
to $\Category{D}$ is exactly a covariant functor $\Category{C}^\op \to \Category{D}$.
This makes contravariance a first-class citizen without a separate definition.

**Presheaves.** The presheaf category $[\Category{C}^\op, \Set]$ — functors from
$\Category{C}^\op$ to $\Set$ — is the canonical arena for sheaf theory and
representability questions. The representable presheaf
$\Hom_{\Category{C}}(-, Y) : \Category{C}^\op \to \Set$ is the basic example.

**Yoneda.** The Yoneda embedding sends each object $Y \in \Category{C}$ to the
representable presheaf $\Hom_{\Category{C}}(-, Y)$. It is a fully faithful functor
$\Category{C} \hookrightarrow [\Category{C}^\op, \Set]$, embedding $\Category{C}$ into its
own presheaf category. See [Yoneda Lemma](/foundations/yoneda).
