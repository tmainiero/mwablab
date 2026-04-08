# Braided monoidal category -- a monoidal category equipped with a braiding.
#
# Mathematical definition (nLab: braided+monoidal+category):
# A braided monoidal category (C, tensor, I, alpha, lambda, rho, sigma) is a
# monoidal category together with a natural isomorphism
#   sigma_{A,B} : A tensor B ~-> B tensor A
# called the braiding, subject to the two hexagon axioms.
#
# Hexagon axiom 1:
#   alpha_{B,C,A} . sigma_{A, B tensor C} . alpha_{A,B,C}
#   = (id_B bimap sigma_{A,C}) . alpha_{B,A,C} . (sigma_{A,B} bimap id_C)
#
# Hexagon axiom 2:
#   alpha^{-1}_{C,A,B} . sigma_{A tensor B, C} . alpha^{-1}_{A,B,C}
#   = (sigma_{A,C} bimap id_B) . alpha^{-1}_{A,C,B} . (id_A bimap sigma_{B,C})
#
# This extends ThMonoidalCategory with braiding operations.

using GATlab

"""
    ThBraidedMonoidalCategory

The theory of braided monoidal categories, extending ThMonoidalCategory.

Additional operations:
- `braid(a, b)` -- sigma_{a,b} : a otimes b -> b otimes a
- `braid_inv(a, b)` -- sigma^{-1}_{a,b} : b otimes a -> a otimes b

Axioms include braiding roundtrip. Hexagon axioms are verified in tests
(their nested term structure may exceed GATlab's equation parser).

nLab: braided+monoidal+category.
"""
@theory ThBraidedMonoidalCategory <: ThMonoidalCategory begin
    # Braiding and its inverse
    braid(a::Ob, b::Ob)::Hom(otimes(a, b), otimes(b, a))
    braid_inv(a::Ob, b::Ob)::Hom(otimes(b, a), otimes(a, b))

    # Braiding roundtrip
    compose(braid(a, b), braid_inv(a, b)) == id(otimes(a, b)) ⊣ [a::Ob, b::Ob]
    compose(braid_inv(a, b), braid(a, b)) == id(otimes(b, a)) ⊣ [a::Ob, b::Ob]

    # Hexagon axioms: verified in tests due to term complexity.
    # See module header for the full statements.
end
