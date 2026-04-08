# Functor -- structure-preserving map between categories.
#
# Mathematical definition (Stacks Project 001B):
# A functor F : C -> D consists of a map on objects and a map on morphisms
# preserving identity and composition.
#
# GATlab can express this as a multi-sorted dependent type theory with two
# sets of objects/morphisms (source and target categories) plus maps between
# them. This follows the same pattern as Catlab's ThCopresheaf (which adds
# elements dependent on objects) and ThDoubleCategory (which has cells
# dependent on both proarrows and morphisms).
#
# The key insight: a functor is NOT "inter-model" -- it is a single algebraic
# theory with sorts for two categories and operations mapping between them.
#
# Stacks Project 001B; nLab: functor.

using GATlab

"""
    ThFunctor

The theory of a functor F : C -> D as a generalized algebraic theory.

Sorts:
- `ObC`, `HomC(dom, codom)` -- objects and morphisms of the source category C
- `ObD`, `HomD(dom, codom)` -- objects and morphisms of the target category D

Operations (source category):
- `idC(a)`, `composeC(f, g)` -- identity and composition in C

Operations (target category):
- `idD(a)`, `composeD(f, g)` -- identity and composition in D

Operations (functor):
- `fob(a)` -- action on objects: ObC -> ObD
- `fhom(f)` -- action on morphisms: HomC(a,b) -> HomD(fob(a), fob(b))

Axioms include the category laws for C and D, plus:
- Identity preservation: fhom(idC(a)) == idD(fob(a))
- Composition preservation: fhom(composeC(f, g)) == composeD(fhom(f), fhom(g))

Stacks Project 001B; nLab: functor.
"""
@theory ThFunctor begin
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

    # Functor maps
    fob(a::ObC)::ObD
    fhom(f::HomC(a, b))::HomD(fob(a), fob(b)) ⊣ [a::ObC, b::ObC]

    # Functor laws
    fhom(idC(a)) == idD(fob(a)) ⊣ [a::ObC]
    fhom(composeC(f, g)) == composeD(fhom(f), fhom(g)) ⊣
        [a::ObC, b::ObC, c::ObC, f::HomC(a, b), g::HomC(b, c)]
end
