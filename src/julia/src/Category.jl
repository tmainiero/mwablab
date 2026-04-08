# Category -- the fundamental notion, expressed as a GATlab theory.
#
# Mathematical definition (Stacks Project 0014):
# A category C consists of a set of objects Ob(C),
# for each pair x, y in Ob(C) a set of morphisms Mor_C(x, y),
# for each object an identity morphism, and composition satisfying
# associativity and unit laws.
#
# This module uses GATlab's @theory to express Category as a generalized
# algebraic theory with equational axioms. Models (instances) provide
# concrete interpretations.
#
# Note: We define our own ThCategory rather than reusing GATlab's stdlib
# ThCategory, to keep the theory hierarchy self-contained and to match
# our mathematical conventions (no dom/codom accessors, diagrammatic compose).

using GATlab

"""
    ThCategory

The theory of categories as a generalized algebraic theory.

Sorts:
- `Ob` -- objects
- `Hom(dom, codom)` -- morphisms from dom to codom

Operations:
- `id(a)` -- identity morphism on object a
- `compose(f, g)` -- composition of f : a -> b and g : b -> c (diagrammatic order)

Axioms:
- Right unit:    compose(f, id(b)) == f
- Left unit:     compose(id(a), f) == f
- Associativity: compose(compose(f, g), h) == compose(f, compose(g, h))

Note: GATlab uses diagrammatic (left-to-right) composition order.
compose(f, g) means "f then g", which is g . f in conventional notation.

Stacks Project 0014; nLab: category.
"""
@theory ThCategory begin
    Ob::TYPE
    Hom(dom::Ob, codom::Ob)::TYPE

    id(a::Ob)::Hom(a, a)
    compose(f::Hom(a, b), g::Hom(b, c))::Hom(a, c) ⊣ [a::Ob, b::Ob, c::Ob]

    compose(f, id(b)) == f ⊣ [a::Ob, b::Ob, f::Hom(a, b)]
    compose(id(a), f) == f ⊣ [a::Ob, b::Ob, f::Hom(a, b)]
    compose(compose(f, g), h) == compose(f, compose(g, h)) ⊣
        [a::Ob, b::Ob, c::Ob, d::Ob, f::Hom(a, b), g::Hom(b, c), h::Hom(c, d)]
end
