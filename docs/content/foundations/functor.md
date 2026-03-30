---
title: Functor
---

A functor is a structure-preserving map between categories.
It sends objects to objects and morphisms to morphisms, respecting identity and composition.

## Definition

Let $\caty{C}$ and $\caty{D}$ be categories.
A **functor** $\fun{F} : \caty{C} \to \caty{D}$ consists of:

1. A map on objects $\fun{F} : \Ob(\caty{C}) \to \Ob(\caty{D})$.
2. For each pair $X, Y \in \Ob(\caty{C})$, a map on hom-sets
$$\fun{F}_{X,Y} : \Hom_{\caty{C}}(X, Y) \to \Hom_{\caty{D}}(\fun{F}(X), \fun{F}(Y)).$$

subject to:

- **Identity preservation.** For each $X \in \Ob(\caty{C})$,
  $$\fun{F}(\id_X) = \id_{\fun{F}(X)}.$$

- **Composition preservation.** For all $f : X \to Y$ and $g : Y \to Z$ in $\caty{C}$,
  $$\fun{F}(g \circ f) = \fun{F}(g) \circ \fun{F}(f).$$

Reference: [Stacks Project, Tag 0014](https://stacks.math.columbia.edu/tag/0014).

The **identity functor** $\operatorname{Id}_{\caty{C}} : \caty{C} \to \caty{C}$ fixes all objects and
morphisms. Given functors $\fun{F} : \caty{C} \to \caty{D}$ and $\fun{G} : \caty{D} \to \caty{E}$,
their **composite** $\fun{G} \circ \fun{F} : \caty{C} \to \caty{E}$ applies each in turn:
$(\fun{G} \circ \fun{F})(X) = \fun{G}(\fun{F}(X))$ on objects and
$(\fun{G} \circ \fun{F})(f) = \fun{G}(\fun{F}(f))$ on morphisms.
Functor composition is associative and $\operatorname{Id}$ is the unit;
small categories and functors therefore form a category $\caty{Cat}$.

---

## Haskell

Source: `src/haskell/src/Cat/Functor.hs`

### Typeclass track

```haskell
class (Category cat1, Category cat2)
    => CFunctor (f :: k1 -> k2)
                (cat1 :: k1 -> k1 -> Type)
                (cat2 :: k2 -> k2 -> Type)
    | f -> cat1 cat2 where
  cmap :: cat1 a b -> cat2 (f a) (f b)
```

The typeclass is named `CFunctor` (categorical functor) to avoid collision with `Prelude.Functor`.
The functional dependency `f -> cat1 cat2` enforces that a type constructor `f` determines both
its source and target categories uniquely.
The action on objects is implicit in Haskell's type system: `f a` is the image of object `a`.
`cmap` is the action on morphisms: given $f : a \to b$ in `cat1`, it produces
$\fun{F}(f) : \fun{F}(a) \to \fun{F}(b)$ in `cat2`.

### Data track

```haskell
newtype FunctorData (hom1 :: Type -> Type -> Type)
                    (hom2 :: Type -> Type -> Type)
                    (f    :: Type -> Type)
  = FunctorData
  { fmapData :: forall a b. hom1 a b -> hom2 (f a) (f b) }
```

`FunctorData` reifies a functor as a first-class value rather than a typeclass instance.
This is the substrate for future $\caty{V}$-enriched functors, where morphism-mapping must
be a morphism in the enriching category $\caty{V}$, not just a Haskell function.

---

## Agda

Source: `src/agda/Cat/Functor.agda`

```agda
record Functor {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ : Level}
               (C : Category o₁ ℓ₁ e₁) (D : Category o₂ ℓ₂ e₂)
               : Set (o₁ ⊔ ℓ₁ ⊔ e₁ ⊔ o₂ ⊔ ℓ₂ ⊔ e₂) where
  field
    F₀ : C.Obj → D.Obj
    F₁ : ∀ {A B} → A C.⇒ B → F₀ A D.⇒ F₀ B

  field
    identity     : ∀ {A} → F₁ (C.id {A}) D.≈ D.id
    homomorphism : ∀ {X Y Z} {f : X C.⇒ Y} {g : Y C.⇒ Z}
                 → F₁ (g C.∘ f) D.≈ (F₁ g D.∘ F₁ f)
    F-resp-≈     : ∀ {A B} {f g : A C.⇒ B}
                 → f C.≈ g → F₁ f D.≈ F₁ g
```

`F₀` is the object map; `F₁` is the morphism map.
The three proof fields correspond exactly to the two functor axioms plus the requirement that
`F₁` respects morphism equality — necessary because Agda's setoid-enriched categories
distinguish definitional from propositional equality on homs.
Universe levels are fully polymorphic: each category carries independent levels for
objects ($o$), morphisms ($\ell$), and morphism equality ($e$).

---

## Common Lisp

Source: `src/lisp/src/functor.lisp`

```lisp
(defclass functor ()
  ((source   :initarg :source   :accessor functor-source)
   (target   :initarg :target   :accessor functor-target)
   (obj-map  :initarg :obj-map  :accessor functor-obj-map)
   (mor-map  :initarg :mor-map  :accessor functor-mor-map)))

(defgeneric fobj (funct object)
  (:documentation "F(object) in the target category."))

(defgeneric fmap (funct morphism)
  (:documentation "F(morphism) in the target category."))
```

A `functor` instance carries its source and target categories explicitly as slots,
alongside two function-valued slots for the object and morphism maps.
`fobj` and `fmap` are the public interface; the default methods delegate to the slots via `funcall`.
CLOS dispatch allows specialised subtypes to override either operation directly,
which is the natural hook for building the representable functors $\Hom(\caty{C})(A, -)$.

---

## Examples

### Maybe as an endofunctor on Hask

`Maybe` sends each type $A$ to $\{*, A\}$ (with an added point $\text{Nothing}$) and lifts
functions pointwise, sending $\text{Nothing}$ to $\text{Nothing}$.

```haskell
instance CFunctor Maybe (->) (->) where
  cmap _ Nothing  = Nothing
  cmap f (Just a) = Just (f a)
```

### Identity functor

```haskell
newtype Id a = Id { runId :: a }

instance CFunctor Id (->) (->) where
  cmap f (Id a) = Id (f a)
```

The identity functor on $\caty{Hask}$: objects and morphisms pass through unchanged (up to the `Id` wrapper).

---

## Laws

Both axioms must hold for every `CFunctor` instance.
Source: `src/haskell/test/Cat/FunctorSpec.hs`

**Identity preservation** — `cmap id = id`:
```haskell
prop_maybeFunctorIdentity :: Maybe Int -> Bool
prop_maybeFunctorIdentity mx =
  cmap id mx == (id :: Maybe Int -> Maybe Int) mx
```

**Composition preservation** — `cmap (g \`compose\` f) = cmap g \`compose\` cmap f`:
```haskell
prop_maybeFunctorComp :: Fun Int Int -> Fun Int Int -> Maybe Int -> Bool
prop_maybeFunctorComp (Fun _ g) (Fun _ f) mx =
  cmap (compose g f) mx == compose (cmap g) (cmap f) mx
```

The same two properties are checked for the `Id` functor and for `FunctorData`.
QuickCheck generates random functions via `Fun` and random inputs to exercise all branches.
