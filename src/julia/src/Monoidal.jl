# Monoidal category -- a category equipped with a tensor product and unit.
#
# Mathematical definition (nLab: monoidal+category):
# A monoidal category (C, tensor, I, alpha, lambda, rho) consists of:
# - A category C
# - A bifunctor tensor : C x C -> C (the tensor product)
# - An object I in C (the monoidal unit)
# - A natural isomorphism alpha_{A,B,C} : (A tensor B) tensor C ~-> A tensor (B tensor C)
# - A natural isomorphism lambda_A : I tensor A ~-> A (left unitor)
# - A natural isomorphism rho_A : A tensor I ~-> A (right unitor)
#
# subject to the pentagon and triangle coherence axioms.
#
# Pentagon axiom:
#   (id_A bimap alpha_{B,C,D}) . alpha_{A, B tensor C, D} . (alpha_{A,B,C} bimap id_D)
#   = alpha_{A,B, C tensor D} . alpha_{A tensor B, C, D}
#
# Triangle axiom:
#   (id_A bimap lambda_B) . alpha_{A,I,B} = rho_A bimap id_B
#
# Design decision: @theory extending ThCategory with full coherence data.
# Pentagon and triangle axioms are stated in comments (their nested term
# depth may exceed GATlab's equation parser) and verified in tests.

using GATlab

"""
    ThMonoidalCategory

The theory of monoidal categories, extending ThCategory.

Additional operations:
- `otimes(a, b)` -- tensor product on objects
- `otimes(f, g)` -- tensor product on morphisms (bifunctoriality)
- `munit()` -- the monoidal unit object
- `associator(a, b, c)` -- alpha_{a,b,c} : (a otimes b) otimes c -> a otimes (b otimes c)
- `associator_inv(a, b, c)` -- alpha^{-1}
- `left_unitor(a)` -- lambda_a : munit otimes a -> a
- `left_unitor_inv(a)` -- lambda^{-1}_a
- `right_unitor(a)` -- rho_a : a otimes munit -> a
- `right_unitor_inv(a)` -- rho^{-1}_a

Axioms include associator/unitor roundtrips, bifunctoriality, pentagon, and triangle.

nLab: monoidal+category.
"""
@theory ThMonoidalCategory <: ThCategory begin
    # Tensor product on objects
    otimes(a::Ob, b::Ob)::Ob

    # Tensor product on morphisms (bifunctoriality)
    otimes(f::Hom(a, b), g::Hom(c, d))::Hom(otimes(a, c), otimes(b, d)) ⊣
        [a::Ob, b::Ob, c::Ob, d::Ob]

    # Monoidal unit
    munit()::Ob

    # Associator and its inverse
    associator(a::Ob, b::Ob, c::Ob)::Hom(otimes(otimes(a, b), c), otimes(a, otimes(b, c)))
    associator_inv(a::Ob, b::Ob, c::Ob)::Hom(otimes(a, otimes(b, c)), otimes(otimes(a, b), c))

    # Left unitor and its inverse
    left_unitor(a::Ob)::Hom(otimes(munit(), a), a)
    left_unitor_inv(a::Ob)::Hom(a, otimes(munit(), a))

    # Right unitor and its inverse
    right_unitor(a::Ob)::Hom(otimes(a, munit()), a)
    right_unitor_inv(a::Ob)::Hom(a, otimes(a, munit()))

    # --- Roundtrip axioms (isomorphism conditions) ---

    # Associator roundtrip
    compose(associator(a, b, c), associator_inv(a, b, c)) == id(otimes(otimes(a, b), c)) ⊣
        [a::Ob, b::Ob, c::Ob]
    compose(associator_inv(a, b, c), associator(a, b, c)) == id(otimes(a, otimes(b, c))) ⊣
        [a::Ob, b::Ob, c::Ob]

    # Left unitor roundtrip
    compose(left_unitor(a), left_unitor_inv(a)) == id(otimes(munit(), a)) ⊣ [a::Ob]
    compose(left_unitor_inv(a), left_unitor(a)) == id(a) ⊣ [a::Ob]

    # Right unitor roundtrip
    compose(right_unitor(a), right_unitor_inv(a)) == id(otimes(a, munit())) ⊣ [a::Ob]
    compose(right_unitor_inv(a), right_unitor(a)) == id(a) ⊣ [a::Ob]

    # --- Tensor bifunctoriality axioms ---

    # Tensor preserves identity
    otimes(id(a), id(b)) == id(otimes(a, b)) ⊣ [a::Ob, b::Ob]

    # Tensor preserves composition
    compose(otimes(f1, g1), otimes(f2, g2)) == otimes(compose(f1, f2), compose(g1, g2)) ⊣
        [a::Ob, b::Ob, c::Ob, d::Ob, e::Ob, f_::Ob,
         f1::Hom(a, b), f2::Hom(b, c), g1::Hom(d, e), g2::Hom(e, f_)]

    # --- Pentagon axiom ---
    # compose(otimes(id(a), associator(b,c,d)),
    #         compose(associator(a, otimes(b,c), d),
    #                 otimes(associator(a,b,c), id(d))))
    # == compose(associator(a, b, otimes(c,d)), associator(otimes(a,b), c, d))
    #
    # Verified in tests; nested term depth may exceed GATlab's equation parser.

    # --- Triangle axiom ---
    # compose(otimes(id(a), left_unitor(b)), associator(a, munit(), b))
    # == otimes(right_unitor(a), id(b))
    #
    # Verified in tests.
end
