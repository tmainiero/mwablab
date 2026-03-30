---
title: Opposite Category
---

## Definition

Let $\caty{C}$ be a category. The **opposite category** $\caty{C}^\op$ has the same
objects as $\caty{C}$, with hom-sets reversed:

$$\Hom_{\caty{C}^\op}(X, Y) = \Hom_{\caty{C}}(Y, X).$$

Identities are unchanged: $\id^\op_X = \id_X$. Composition reverses direction. Given
$f \in \Hom_{\caty{C}^\op}(X, Y)$ and $g \in \Hom_{\caty{C}^\op}(Y, Z)$ — that is,
$f : Y \to X$ and $g : Z \to Y$ in $\caty{C}$ — the opposite composition is

$$g \circ^\op f = f \circ g \;\in\; \Hom_{\caty{C}}(Z, X) = \Hom_{\caty{C}^\op}(X, Z).$$

The axioms follow immediately from $\caty{C}$: associativity of $\circ^\op$ is associativity
of $\circ$ with arguments relabelled; left and right identity laws swap roles.

*Reference: Stacks Project Tag 0017.*

---

## Haskell

`src/haskell/src/Cat/Opposite.hs`

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

`src/agda/Cat/Opposite.agda`

The postfix operator `_op` constructs $\caty{C}^\op$ from any `Category` record.
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

*Reference: Stacks Project Tag 001C.*

---

## Common Lisp

`src/lisp/src/opposite.lisp`

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

*Reference: Stacks Project Tag 0013.*

---

## Key property: $(\caty{C}^\op)^\op = \caty{C}$

The opposite construction is an involution. Double reversal recovers the original
hom-sets:

$$\Hom_{(\caty{C}^\op)^\op}(X, Y)
  = \Hom_{\caty{C}^\op}(Y, X)
  = \Hom_{\caty{C}}(X, Y),$$

and composition $f \circ^{\op\op} g = g \circ^\op f = f \circ g$ agrees with $\caty{C}$.

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

**Contravariant functors.** A contravariant functor $\fun{F} : \caty{C} \to \caty{D}$
reverses morphisms: for $f : X \to Y$ in $\caty{C}$ it produces
$\fun{F}(f) : \fun{F}(Y) \to \fun{F}(X)$ in $\caty{D}$, with composition satisfying
$\fun{F}(g \circ f) = \fun{F}(f) \circ \fun{F}(g)$.
The opposite category absorbs the reversal: a contravariant functor from $\caty{C}$
to $\caty{D}$ is exactly a covariant functor $\caty{C}^\op \to \caty{D}$.
This makes contravariance a first-class citizen without a separate definition.

**Presheaves.** The presheaf category $[\caty{C}^\op, \Set]$ — functors from
$\caty{C}^\op$ to $\Set$ — is the canonical arena for sheaf theory and
representability questions. The representable presheaf
$\Hom_{\caty{C}}(-, Y) : \caty{C}^\op \to \Set$ is the basic example.

**Yoneda.** The Yoneda embedding sends each object $Y \in \caty{C}$ to the
representable presheaf $\Hom_{\caty{C}}(-, Y)$. It is a fully faithful functor
$\caty{C} \hookrightarrow [\caty{C}^\op, \Set]$, embedding $\caty{C}$ into its
own presheaf category. See [Yoneda Lemma](/foundations/yoneda).
