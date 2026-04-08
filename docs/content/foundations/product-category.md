---
title: Product Category
---

The product category is the categorical product in $\Category{Cat}$.
It equips pairs of categories with componentwise structure.

## Definition

Given categories $\Category{C}$ and $\Category{D}$,
their **product category** $\Category{C} \times \Category{D}$ consists of:

1. **Objects.** $\Ob(\Category{C} \times \Category{D}) = \Ob(\Category{C}) \times \Ob(\Category{D})$.
   An object is a pair $(X, Y)$ with $X \in \Ob(\Category{C})$ and $Y \in \Ob(\Category{D})$.

2. **Morphisms.** A morphism $(X_1, Y_1) \to (X_2, Y_2)$ is a pair $(f, g)$
   with $f \colon X_1 \to X_2$ in $\Category{C}$ and $g \colon Y_1 \to Y_2$ in $\Category{D}$.

3. **Identity.** $\id_{(X,Y)} = (\id_X, \id_Y)$.

4. **Composition.** $(f_2, g_2) \circ (f_1, g_1) = (f_2 \circ f_1, g_2 \circ g_1)$.

The category axioms hold componentwise:
associativity and identity laws in $\Category{C} \times \Category{D}$
reduce to the corresponding laws in $\Category{C}$ and $\Category{D}$.

Reference: [nLab, product category](https://ncatlab.org/nlab/show/product+category).

---

## Projection functors

The **projection functors** are:

$$\Functor{\pi}_1 \colon \Category{C} \times \Category{D} \to \Category{C}, \quad (X, Y) \mapsto X, \quad (f, g) \mapsto f,$$

$$\Functor{\pi}_2 \colon \Category{C} \times \Category{D} \to \Category{D}, \quad (X, Y) \mapsto Y, \quad (f, g) \mapsto g.$$

These are strict functors: they preserve identities and composition by definition.

---

## Universal property

For any category $\Category{E}$ and functors
$\Functor{F} \colon \Category{E} \to \Category{C}$
and $\Functor{G} \colon \Category{E} \to \Category{D}$,
there exists a unique functor
$\langle \Functor{F}, \Functor{G} \rangle \colon \Category{E} \to \Category{C} \times \Category{D}$
such that
$\Functor{\pi}_1 \circ \langle \Functor{F}, \Functor{G} \rangle = \Functor{F}$
and
$\Functor{\pi}_2 \circ \langle \Functor{F}, \Functor{G} \rangle = \Functor{G}$.

```
          E
         / | \
        /  |  \
    F  / <F,G> \ G
      /    |    \
     v     v     v
    C   C x D    D
         / \
      pi_1  pi_2
```

The pairing functor acts as
$\langle \Functor{F}, \Functor{G} \rangle(E) = (\Functor{F}(E), \Functor{G}(E))$
on objects and
$\langle \Functor{F}, \Functor{G} \rangle(h) = (\Functor{F}(h), \Functor{G}(h))$
on morphisms.

---

## Haskell

Source: `src/haskell/src/Cat/Product.hs`

### Typeclass track

```haskell
newtype Prod (cat1 :: Type -> Type -> Type)
             (cat2 :: Type -> Type -> Type)
             (a :: (Type, Type))
             (b :: (Type, Type))
  = Prod { unProd :: (cat1 (Fst a) (Fst b), cat2 (Snd a) (Snd b)) }

instance (Category cat1, Category cat2) => Category (Prod cat1 cat2) where
  id = Prod (id, id)
  compose (Prod (f1, f2)) (Prod (g1, g2)) = Prod (compose f1 g1, compose f2 g2)
```

Objects are type-level pairs `'(a, b)`.
A morphism in `Prod cat1 cat2` is a pair of morphisms, one from each component category.
The type families `Fst` and `Snd` project promoted pairs.

Projection functor wrappers `FstProj` and `SndProj` project objects back to the components.

### Data track

```haskell
productData :: CategoryData cat1 -> CategoryData cat2 -> CategoryData (ProdHom cat1 cat2)
```

`productData` builds the product category from data-track category values, with `ProdHom` wrapping pairs of component morphisms at the value level.

---

## Agda

Source: `src/agda/Cat/Product.agda`

```agda
Product : ∀ {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂}
        → Category o₁ ℓ₁ e₁ → Category o₂ ℓ₂ e₂
        → Category (o₁ ⊔ o₂) (ℓ₁ ⊔ ℓ₂) (e₁ ⊔ e₂)
Product C D = record
  { Obj = C.Obj × D.Obj
  ; _⇒_ = λ { (a₁ , a₂) (b₁ , b₂) → (a₁ C.⇒ b₁) × (a₂ D.⇒ b₂) }
  ; _≈_ = λ { (f₁ , f₂) (g₁ , g₂) → (f₁ C.≈ g₁) × (f₂ D.≈ g₂) }
  ; id  = C.id , D.id
  ; _∘_ = λ { (f₁ , f₂) (g₁ , g₂) → (f₁ C.∘ g₁) , (f₂ D.∘ g₂) }
  ...
  }
```

The universe levels of the product are the join of the component levels.
Morphism equality is componentwise, preserving the setoid structure.
All proof obligations (associativity, identities, congruence) are discharged from the component proofs.

---

## Common Lisp

Source: `src/lisp/src/product-category.lisp`

```common-lisp
(defun product-category (cat-c cat-d)
  "Construct the product category C x D from categories C and D.")
```

Product morphisms are represented as `prod-morphism` structs with `first` and `second` slots.
The `objects` slot is a predicate on cons pairs.
Projection functors `projection-functor-1` and `projection-functor-2` extract the components,
and `pairing-functor` constructs the universal pairing $\langle \Functor{F}, \Functor{G} \rangle$.

---

## Laws

Source: `src/haskell/test/Cat/ProductSpec.hs`

The product category inherits its laws componentwise from $\Category{C}$ and $\Category{D}$:

**Associativity**
$$(h_1, h_2) \circ ((g_1, g_2) \circ (f_1, f_2)) = ((h_1, h_2) \circ (g_1, g_2)) \circ (f_1, f_2)$$

**Left identity**
$$(\id_{X_1}, \id_{X_2}) \circ (f_1, f_2) = (f_1, f_2)$$

**Right identity**
$$(f_1, f_2) \circ (\id_{X_1}, \id_{X_2}) = (f_1, f_2)$$
