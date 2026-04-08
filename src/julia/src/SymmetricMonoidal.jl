# Symmetric monoidal category -- a braided monoidal category whose braiding
# is self-inverse.
#
# Mathematical definition (nLab: symmetric+monoidal+category):
# A symmetric monoidal category is a braided monoidal category in which
# sigma_{B,A} . sigma_{A,B} = id_{A tensor B}.
# Equivalently, sigma^{-1}_{A,B} = sigma_{B,A}.
#
# The two hexagon axioms collapse into one (the second follows from
# the first plus symmetry).

using GATlab

"""
    ThSymmetricMonoidalCategory

The theory of symmetric monoidal categories, extending ThBraidedMonoidalCategory.

Additional axiom:
- Involution: compose(braid(a,b), braid(b,a)) == id(otimes(a,b))

This implies braid_inv(a,b) == braid(b,a).

nLab: symmetric+monoidal+category.
"""
@theory ThSymmetricMonoidalCategory <: ThBraidedMonoidalCategory begin
    # Symmetry / involution axiom
    compose(braid(a, b), braid(b, a)) == id(otimes(a, b)) ⊣ [a::Ob, b::Ob]
end
