# Natural transformation -- morphism between functors.
#
# Mathematical definition (Stacks Project 001I):
# Given functors F, G : C -> D, a natural transformation eta : F => G
# is a family of morphisms eta_a : F(a) -> G(a) for each object a in C,
# such that for every morphism f : a -> b in C, the naturality square commutes:
# G(f) . eta_a = eta_b . F(f).
#
# GATlab encodes this as a multi-sorted theory extending the "two parallel
# functors" setup. We have a source category C, a target category D, two
# functors F and G (object and morphism maps for each), and a component
# family eta indexed by objects of C, valued in morphisms of D.
#
# This follows the pattern of Catlab's ThCategory2, where 2-cells are typed
# as Hom2(dom::Hom(A,B), codom::Hom(A,B))::TYPE -- a sort dependent on
# 1-morphisms. Here, components are morphisms in D dependent on objects of C.
#
# Stacks Project 001I; nLab: natural+transformation.

using GATlab

"""
    ThNaturalTransformation

The theory of a natural transformation eta : F => G between functors F, G : C -> D.

Extends the two-functor setup with:
- `component(a::ObC)` -- the component eta_a : HomD(fob(a), gob(a))

Axioms:
- Naturality: for all f : a -> b in C,
  composeD(fhom(f), component(b)) == composeD(component(a), ghom(f))

This theory inlines the source/target category axioms and both functors'
laws. The naturality condition is the key additional axiom.

Stacks Project 001I; nLab: natural+transformation.
"""
@theory ThNaturalTransformation begin
    # Source category C
    ObC::TYPE
    HomC(dom::ObC, codom::ObC)::TYPE
    idC(a::ObC)::HomC(a, a)
    composeC(f::HomC(a, b), g::HomC(b, c))::HomC(a, c) ⊣ [a::ObC, b::ObC, c::ObC]

    # Source category laws
    composeC(f, idC(b)) == f ⊣ [a::ObC, b::ObC, f::HomC(a, b)]
    composeC(idC(a), f) == f ⊣ [a::ObC, b::ObC, f::HomC(a, b)]
    composeC(composeC(f, g), h) == composeC(f, composeC(g, h)) ⊣
        [a::ObC, b::ObC, c::ObC, d::ObC, f::HomC(a, b), g::HomC(b, c), h::HomC(c, d)]

    # Target category D
    ObD::TYPE
    HomD(dom::ObD, codom::ObD)::TYPE
    idD(a::ObD)::HomD(a, a)
    composeD(f::HomD(a, b), g::HomD(b, c))::HomD(a, c) ⊣ [a::ObD, b::ObD, c::ObD]

    # Target category laws
    composeD(f, idD(b)) == f ⊣ [a::ObD, b::ObD, f::HomD(a, b)]
    composeD(idD(a), f) == f ⊣ [a::ObD, b::ObD, f::HomD(a, b)]
    composeD(composeD(f, g), h) == composeD(f, composeD(g, h)) ⊣
        [a::ObD, b::ObD, c::ObD, d::ObD, f::HomD(a, b), g::HomD(b, c), h::HomD(c, d)]

    # Functor F : C -> D
    fob(a::ObC)::ObD
    fhom(f::HomC(a, b))::HomD(fob(a), fob(b)) ⊣ [a::ObC, b::ObC]

    # F preserves identity and composition
    fhom(idC(a)) == idD(fob(a)) ⊣ [a::ObC]
    fhom(composeC(f, g)) == composeD(fhom(f), fhom(g)) ⊣
        [a::ObC, b::ObC, c::ObC, f::HomC(a, b), g::HomC(b, c)]

    # Functor G : C -> D
    gob(a::ObC)::ObD
    ghom(f::HomC(a, b))::HomD(gob(a), gob(b)) ⊣ [a::ObC, b::ObC]

    # G preserves identity and composition
    ghom(idC(a)) == idD(gob(a)) ⊣ [a::ObC]
    ghom(composeC(f, g)) == composeD(ghom(f), ghom(g)) ⊣
        [a::ObC, b::ObC, c::ObC, f::HomC(a, b), g::HomC(b, c)]

    # Natural transformation component
    component(a::ObC)::HomD(fob(a), gob(a))

    # Naturality condition (diagrammatic order):
    # composeD(fhom(f), component(b)) == composeD(component(a), ghom(f))
    # i.e., (fhom(f) then eta_b) == (eta_a then ghom(f))
    composeD(fhom(f), component(b)) == composeD(component(a), ghom(f)) ⊣
        [a::ObC, b::ObC, f::HomC(a, b)]
end
