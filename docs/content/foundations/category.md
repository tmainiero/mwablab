---
title: Category
---

## Definition

A **category** $\Category{C}$ consists of:

1. A collection $\Ob(\Category{C})$ of **objects**.
2. For each pair $X, Y \in \Ob(\Category{C})$, a set $\Hom_{\Category{C}}(X, Y)$ of **morphisms** from $X$ to $Y$.
3. For each object $X$, an **identity morphism** $\id_X \in \Hom_{\Category{C}}(X, X)$.
4. For each triple $X, Y, Z \in \Ob(\Category{C})$, a **composition map**
$$\circ : \Hom_{\Category{C}}(Y, Z) \times \Hom_{\Category{C}}(X, Y) \to \Hom_{\Category{C}}(X, Z), \quad (g, f) \mapsto g \circ f$$

subject to associativity and identity laws (see [Laws](#laws) below).

Reference: [Stacks Project 0014](https://stacks.math.columbia.edu/tag/0014).

---

## Haskell

`Cat.Category` provides two encodings.

### Typeclass track

For locally small categories whose objects are Haskell types:

```haskell
class Category (cat :: k -> k -> Type) where
  id      :: cat a a
  compose :: cat b c -> cat a b -> cat a c
```

`compose g f` is $g \circ f$ — conventional right-to-left order. For chains that read left-to-right, use the diagrammatic alias:

```haskell
(>>>) :: Category cat => cat a b -> cat b c -> cat a c
f >>> g = compose g f
```

`f >>> g >>> h` means "apply $f$, then $g$, then $h$", matching diagram order. The two operators are interchangeable: use whichever order fits the context.

### Data track

`CategoryData` reifies the typeclass as a first-class record, making the category structure passable as a value:

```haskell
data CategoryData (hom :: Type -> Type -> Type) = CatData
  { catIdentity :: forall a.         hom a a
  , catCompose  :: forall a b c. hom b c -> hom a b -> hom a c
  }

categoryDataFromClass :: Category cat => CategoryData cat
categoryDataFromClass = CatData id compose
```

This is the substrate for V-enrichment (planned Phase 1b): a $\Category{V}$-enriched category replaces `hom a b :: Type` with `hom a b :: Ob(V)`.

---

## Agda

`Cat.Category` follows the Hu–Carette (`agda-categories`) design: three universe levels and setoid equality.

```agda
record Category (o ℓ e : Level) : Set (suc (o ⊔ ℓ ⊔ e)) where
  field
    Obj : Set o
    _⇒_ : Obj → Obj → Set ℓ
    _≈_ : ∀ {A B} → Rel (A ⇒ B) e
    id  : ∀ {A} → A ⇒ A
    _∘_ : ∀ {A B C} → B ⇒ C → A ⇒ B → A ⇒ C
  field
    assoc     : (h ∘ g) ∘ f ≈ h ∘ (g ∘ f)
    sym-assoc : h ∘ (g ∘ f) ≈ (h ∘ g) ∘ f
    identityˡ : id ∘ f ≈ f
    identityʳ : f ∘ id ≈ f
    identity² : id ∘ id ≈ id
    equiv      : IsEquivalence (_≈_ {A} {B})
    ∘-resp-≈   : f ≈ h → g ≈ i → f ∘ g ≈ h ∘ i
```

**Universe levels.** `o` is the level of objects, `ℓ` of morphism types, `e` of the equality proof type. A small category has `o = ℓ = e = 0`; a locally small category has `o` large and `ℓ = 0`.

**Setoid equality.** The field `_≈_` is an arbitrary equivalence relation on each hom-set, witnessed by `equiv`. This avoids propositional equality, which is too strict for categories whose morphisms carry computational content (e.g. functors up to natural isomorphism). The field `∘-resp-≈` ensures composition is a congruence with respect to this equality.

The diagrammatic alias `_≫_` (defined as `f ≫ g = g ∘ f`) mirrors Haskell's `>>>`.

---

## Common Lisp

`mwablab` represents categories as CLOS instances with function-valued slots, supporting both finite (list-based) and infinite (closure-based) categories.

```common-lisp
(defclass category ()
  ((name     :initarg :name     :accessor category-name)
   (objects  :initarg :objects  :accessor category-objects)
   (hom      :initarg :hom      :accessor category-hom)
   (identity :initarg :identity :accessor category-identity)
   (compose  :initarg :compose  :accessor category-compose)))
```

The generic interface:

```common-lisp
(defgeneric id-morphism       (cat obj)   )  ; returns id_{obj}
(defgeneric compose-morphisms (cat g f)   )  ; returns g ∘ f
(defgeneric hom-set           (cat x y)   )  ; returns Hom_C(X, Y)
```

The `compose` slot stores a function `(g f) → g ∘ f` in traditional order. The `objects` slot may be a list (finite case) or a predicate `(x) → boolean` (infinite case). This makes the data representation uniform across discrete categories, monoids-as-categories, and large categories defined by a type predicate.

---

## Examples

### Hask: `(->)`

The category of Haskell types and total functions.

- **Objects**: Haskell types (`Int`, `Bool`, `[a]`, ...)
- **Morphisms**: functions `a -> b`
- **Identity**: `id x = x`
- **Composition**: function composition

```haskell
instance Category (->) where
  id x       = x
  compose g f x = g (f x)
```

### Discrete category

$\Hom(X, Y) = \{\id_X\}$ if $X = Y$, else $\emptyset$.

```haskell
data Discrete (a :: Type) (b :: Type) where
  Refl :: Discrete a a

instance Category Discrete where
  id            = Refl
  compose Refl Refl = Refl
```

The GADT constructor `Refl :: Discrete a a` enforces $X = Y$ at the type level: `compose` only type-checks when both arguments have matching endpoints.

### Kleisli category

For a monad $m$, the Kleisli category $\Category{C}_m$ has the same objects as $\Category{C}$ but morphisms $X \to Y$ are Kleisli arrows $X \to m\,Y$.

- **Identity**: `pure :: a -> m a`
- **Composition**: `(g <=< f) x = f x >>= g`

```haskell
newtype Kleisli (m :: Type -> Type) (a :: Type) (b :: Type)
  = Kleisli { runKleisli :: a -> m b }

instance Monad m => Category (Kleisli m) where
  id                      = Kleisli pure
  compose (Kleisli g) (Kleisli f) = Kleisli (f >=> g)
```

---

## Laws

For all $f : X \to Y$, $g : Y \to Z$, $h : Z \to W$:

**Associativity**
$$h \circ (g \circ f) = (h \circ g) \circ f$$

**Left identity**
$$\id_Y \circ f = f$$

**Right identity**
$$f \circ \id_X = f$$

The QuickCheck suite verifies all three laws for the `(->)` instance, testing against random functions `Int -> Int`:

```haskell
prop_leftIdentity  :: Fun Int Int -> Int -> Bool
prop_leftIdentity  (Fun _ f) x = compose id f x == f x

prop_rightIdentity :: Fun Int Int -> Int -> Bool
prop_rightIdentity (Fun _ f) x = compose f id x == f x

prop_assoc :: Fun Int Int -> Fun Int Int -> Fun Int Int -> Int -> Bool
prop_assoc (Fun _ h) (Fun _ g) (Fun _ f) x =
  compose h (compose g f) x == compose (compose h g) f x
```

The same laws are checked for `CategoryData` via `catCompose` and `catIdentity`, verifying that `categoryDataFromClass` faithfully reifies the typeclass instance.

In Agda, `assoc`, `identityˡ`, and `identityʳ` are proof-term fields — they must be supplied when constructing a `Category` record, making law satisfaction a compile-time requirement rather than a runtime check.
