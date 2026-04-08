# Bifunctor -- a functor from a product category C x D to E.
#
# Mathematical definition (nLab: bifunctor):
# A bifunctor F : C x D -> E is a functor from the product category C x D to E.
# Equivalently, a map that is functorial in each argument separately,
# with an interchange condition.
#
# Design decision: In the GATlab refactor, the tensor product IS the bifunctor
# (otimes on morphisms in ThMonoidalCategory). This module provides a minimal
# standalone BifunctorData struct for use cases outside the @theory hierarchy
# (e.g., product category constructions, tests that need explicit bimap).
#
# nLab: bifunctor.

export BifunctorData, bimap_data, first_data, second_data

"""
    BifunctorData

A bifunctor reified as data. Stores the bimap action on morphisms.

Given morphisms f : a1 -> b1 in C and g : a2 -> b2 in D,
`bimap(F, f, g)` produces F(f, g) : F(a1,a2) -> F(b1,b2) in E.

In the GATlab theory hierarchy, `otimes(f, g)` on Hom sorts serves
as the bifunctor action. This standalone struct is for contexts where
we need bimap outside a GATlab model.

Laws:
- Identity:    `bimap_data(F, id, id) == id`
- Composition: `bimap_data(F, f2 . f1, g2 . g1) == bimap_data(F, f2, g2) . bimap_data(F, f1, g1)`

nLab: bifunctor.
"""
struct BifunctorData
    bimap::Function  # (f, g) -> tensor(f, g)
end

"""
    bimap_data(bf::BifunctorData, f, g)

Apply bifunctor to morphisms f and g.

nLab: bifunctor.
"""
bimap_data(bf::BifunctorData, f, g) = bf.bimap(f, g)

"""
    first_data(bf::BifunctorData, f)

Apply bifunctor in the first argument only, holding the second at identity.
Corresponds to the partial functor F(-, d) for a fixed object d.

nLab: bifunctor.
"""
first_data(bf::BifunctorData, f) = bimap_data(bf, f, identity)

"""
    second_data(bf::BifunctorData, g)

Apply bifunctor in the second argument only, holding the first at identity.
Corresponds to the partial functor F(c, -) for a fixed object c.

nLab: bifunctor.
"""
second_data(bf::BifunctorData, g) = bimap_data(bf, identity, g)
