# Natural isomorphism -- an invertible natural transformation.
#
# Mathematical definition:
# A natural isomorphism alpha : F ~=> G is a natural transformation whose
# components are all isomorphisms. Equivalently, a pair of natural
# transformations alpha : F => G and alpha^{-1} : G => F that are mutual
# inverses under vertical composition.
#
# GATlab encodes this by extending the natural transformation theory with
# an inverse component family and roundtrip axioms. This is the same
# pattern as how ThBraidedMonoidalCategory adds braid_inv to the braiding.
#
# nLab: natural+isomorphism.

using GATlab

"""
    ThNaturalIsomorphism

The theory of a natural isomorphism alpha : F ~=> G.

Extends the two-functor-plus-component setup with:
- `component_inv(a::ObC)` -- the inverse component alpha^{-1}_a : HomD(gob(a), fob(a))

Axioms (beyond naturality of component):
- Forward roundtrip: composeD(component(a), component_inv(a)) == idD(fob(a))
- Backward roundtrip: composeD(component_inv(a), component(a)) == idD(gob(a))
- Naturality of inverse: composeD(ghom(f), component_inv(b)) == composeD(component_inv(a), fhom(f))

nLab: natural+isomorphism.
"""
@theory ThNaturalIsomorphism begin
    # Source category C
    ObC::TYPE
    HomC(dom::ObC, codom::ObC)::TYPE
    idC(a::ObC)::HomC(a, a)
    composeC(f::HomC(a, b), g::HomC(b, c))::HomC(a, c) ⊣ [a::ObC, b::ObC, c::ObC]

    composeC(f, idC(b)) == f ⊣ [a::ObC, b::ObC, f::HomC(a, b)]
    composeC(idC(a), f) == f ⊣ [a::ObC, b::ObC, f::HomC(a, b)]
    composeC(composeC(f, g), h) == composeC(f, composeC(g, h)) ⊣
        [a::ObC, b::ObC, c::ObC, d::ObC, f::HomC(a, b), g::HomC(b, c), h::HomC(c, d)]

    # Target category D
    ObD::TYPE
    HomD(dom::ObD, codom::ObD)::TYPE
    idD(a::ObD)::HomD(a, a)
    composeD(f::HomD(a, b), g::HomD(b, c))::HomD(a, c) ⊣ [a::ObD, b::ObD, c::ObD]

    composeD(f, idD(b)) == f ⊣ [a::ObD, b::ObD, f::HomD(a, b)]
    composeD(idD(a), f) == f ⊣ [a::ObD, b::ObD, f::HomD(a, b)]
    composeD(composeD(f, g), h) == composeD(f, composeD(g, h)) ⊣
        [a::ObD, b::ObD, c::ObD, d::ObD, f::HomD(a, b), g::HomD(b, c), h::HomD(c, d)]

    # Functor F : C -> D
    fob(a::ObC)::ObD
    fhom(f::HomC(a, b))::HomD(fob(a), fob(b)) ⊣ [a::ObC, b::ObC]

    fhom(idC(a)) == idD(fob(a)) ⊣ [a::ObC]
    fhom(composeC(f, g)) == composeD(fhom(f), fhom(g)) ⊣
        [a::ObC, b::ObC, c::ObC, f::HomC(a, b), g::HomC(b, c)]

    # Functor G : C -> D
    gob(a::ObC)::ObD
    ghom(f::HomC(a, b))::HomD(gob(a), gob(b)) ⊣ [a::ObC, b::ObC]

    ghom(idC(a)) == idD(gob(a)) ⊣ [a::ObC]
    ghom(composeC(f, g)) == composeD(ghom(f), ghom(g)) ⊣
        [a::ObC, b::ObC, c::ObC, f::HomC(a, b), g::HomC(b, c)]

    # Forward component: eta_a : F(a) -> G(a)
    component(a::ObC)::HomD(fob(a), gob(a))

    # Naturality of forward component
    composeD(fhom(f), component(b)) == composeD(component(a), ghom(f)) ⊣
        [a::ObC, b::ObC, f::HomC(a, b)]

    # Inverse component: eta^{-1}_a : G(a) -> F(a)
    component_inv(a::ObC)::HomD(gob(a), fob(a))

    # Roundtrip axioms
    composeD(component(a), component_inv(a)) == idD(fob(a)) ⊣ [a::ObC]
    composeD(component_inv(a), component(a)) == idD(gob(a)) ⊣ [a::ObC]

    # Naturality of inverse (follows from forward naturality + roundtrips,
    # but stating it explicitly is cleaner for the theory)
    composeD(ghom(f), component_inv(b)) == composeD(component_inv(a), fhom(f)) ⊣
        [a::ObC, b::ObC, f::HomC(a, b)]
end
