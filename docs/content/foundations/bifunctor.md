---
title: Bifunctor
---

A *bifunctor* is a functor from a product category.
It is a map that is functorial in each argument separately.

## Definition

Let $\Category{C}$, $\Category{D}$, and $\Category{E}$ be categories.
A **bifunctor**
$\Functor{F} \colon \Category{C} \times \Category{D} \to \Category{E}$
is a functor from the product category $\Category{C} \times \Category{D}$ to $\Category{E}$.

Concretely, it consists of:

1. A map on objects
   $$\Functor{F} \colon \Ob(\Category{C}) \times \Ob(\Category{D}) \to \Ob(\Category{E}), \quad (X, Y) \mapsto \Functor{F}(X, Y).$$

2. For each pair of morphisms $f \colon X_1 \to X_2$ in $\Category{C}$
   and $g \colon Y_1 \to Y_2$ in $\Category{D}$, a morphism
   $$\operatorname{bimap}(f, g) \colon \Functor{F}(X_1, Y_1) \to \Functor{F}(X_2, Y_2)$$
   in $\Category{E}$.

Reference: [nLab, bifunctor](https://ncatlab.org/nlab/show/bifunctor).

---

## Bimap laws

The map $\operatorname{bimap}$ satisfies:

**Identity.**
$$\operatorname{bimap}(\id_X, \id_Y) = \id_{\Functor{F}(X,Y)}.$$

**Composition.**
For $f_1 \colon X_1 \to X_2$, $f_2 \colon X_2 \to X_3$ in $\Category{C}$,
and $g_1 \colon Y_1 \to Y_2$, $g_2 \colon Y_2 \to Y_3$ in $\Category{D}$:
$$\operatorname{bimap}(f_2 \circ f_1, g_2 \circ g_1)
  = \operatorname{bimap}(f_2, g_2) \circ \operatorname{bimap}(f_1, g_1).$$

Both laws follow immediately from functoriality of $\Functor{F}$
applied to the product category $\Category{C} \times \Category{D}$.

---

## Separate functoriality

A bifunctor $\Functor{F} \colon \Category{C} \times \Category{D} \to \Category{E}$
determines, and is determined by:

1. For each $Y \in \Ob(\Category{D})$, a functor
   $\Functor{F}(\mathord{-}, Y) \colon \Category{C} \to \Category{E}$,
   with $\Functor{F}(\mathord{-}, Y)(f) = \operatorname{bimap}(f, \id_Y)$.

2. For each $X \in \Ob(\Category{C})$, a functor
   $\Functor{F}(X, \mathord{-}) \colon \Category{D} \to \Category{E}$,
   with $\Functor{F}(X, \mathord{-})(g) = \operatorname{bimap}(\id_X, g)$.

These partial functors satisfy the **interchange law**:
$$\operatorname{bimap}(f, g)
  = \Functor{F}(\mathord{-}, Y_2)(f) \circ \Functor{F}(X_1, \mathord{-})(g)
  = \Functor{F}(X_2, \mathord{-})(g) \circ \Functor{F}(\mathord{-}, Y_1)(f).$$

---

## Haskell

Source: `src/haskell/src/Cat/Bifunctor.hs`

The module provides a data track encoding (records, not typeclasses),
consistent with the monoidal phase design.

```haskell
data BifunctorData (hom1 :: Type -> Type -> Type)
                   (hom2 :: Type -> Type -> Type)
                   (hom3 :: Type -> Type -> Type)
                   (f :: Type -> Type -> Type) = BifunctorData
  { bimap :: forall a1 b1 a2 b2. hom1 a1 b1 -> hom2 a2 b2 -> hom3 (f a1 a2) (f b1 b2)
  }
```

The three hom-type parameters `hom1`, `hom2`, `hom3` represent
the morphism types of $\Category{C}$, $\Category{D}$, and $\Category{E}$ respectively.
The partial application helpers extract the separate functoriality:

```haskell
firstData  :: Category hom2 => BifunctorData hom1 hom2 hom3 f -> hom1 a b -> hom3 (f a c) (f b c)
secondData :: Category hom1 => BifunctorData hom1 hom2 hom3 f -> hom2 a b -> hom3 (f c a) (f c b)
```

`firstData bf f` computes $\operatorname{bimap}(f, \id)$ and
`secondData bf g` computes $\operatorname{bimap}(\id, g)$.

---

## Agda

Source: `src/agda/Cat/Bifunctor.agda`

```agda
Bifunctor : ∀ {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ o₃ ℓ₃ e₃}
          → Category o₁ ℓ₁ e₁
          → Category o₂ ℓ₂ e₂
          → Category o₃ ℓ₃ e₃
          → Set _
Bifunctor C D E = Functor (Product C D) E
```

A bifunctor is a type alias for a `Functor` from the `Product` category.
The `BifunctorOps` module provides convenience operations `bimap₁`, `first₁`, and `second₁`
that unwrap the product structure for cleaner usage.

---

## Common Lisp

Source: `src/lisp/src/bifunctor.lisp`

```common-lisp
(defclass bifunctor ()
  ((source-cat-1 :initarg :source-cat-1 :accessor bifunctor-source-cat-1 :type category)
   (source-cat-2 :initarg :source-cat-2 :accessor bifunctor-source-cat-2 :type category)
   (target-cat   :initarg :target-cat   :accessor bifunctor-target-cat   :type category)
   (bimap-fn     :initarg :bimap-fn     :accessor bifunctor-bimap-fn)))
```

A `bifunctor` stores both source categories and the target category explicitly,
alongside a function-valued `bimap-fn` slot.
The generic functions `bimap-morphisms`, `bimap-first`, and `bimap-second`
provide the full and partial application interfaces.

---

## Laws

Source: `src/haskell/test/Cat/BifunctorSpec.hs`

**Identity** --- `bimap id id = id`:
$$\operatorname{bimap}(\id, \id) \; x = \id \; x$$

**Composition** --- `bimap (compose f2 f1) (compose g2 g1) = compose (bimap f2 g2) (bimap f1 g1)`:
$$\operatorname{bimap}(f_2 \circ f_1, g_2 \circ g_1) = \operatorname{bimap}(f_2, g_2) \circ \operatorname{bimap}(f_1, g_1)$$
