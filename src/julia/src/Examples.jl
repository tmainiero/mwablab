# Concrete monoidal category instances using GATlab @instance.
#
# This module provides the two canonical symmetric monoidal structures
# on the category of sets (Julia types with functions):
#
# 1. Cartesian monoidal structure (Set, Tuple, ())
#    where the tensor product is the cartesian product.
#
# 2. Cocartesian monoidal structure (Set, Either, Nothing)
#    where the tensor product is the coproduct (disjoint union).
#
# Each structure is implemented as a GATlab model struct with @instance
# declarations for the appropriate theory level.
#
# nLab: cartesian+monoidal+category, cocartesian+monoidal+category.

using GATlab

export SetCartesian, SetCocartesian
export either_match

# We reuse GATlab's Either{T,S} = Union{Left{T}, Right{S}} (from GATlab.Util.Eithers)
# rather than defining our own, to avoid export conflicts.

"""
    either_match(on_left, on_right, e)

Pattern match on an Either value (GATlab's Left/Right).
Applies `on_left` to the value if Left, `on_right` if Right.

nLab: coproduct.
"""
function either_match(on_left, on_right, e)
    if e isa Left
        on_left(e.val)
    else
        on_right(e.val)
    end
end

"""
    absurd(::Nothing)

The unique morphism from the initial object (Nothing/Void) to any type.
Since Nothing has no inhabitants besides `nothing`, this should never
actually be called on a meaningful value. We error to signal misuse.

nLab: initial+object.
"""
absurd(::Nothing) = error("absurd: Nothing has no inhabitants")

# ---------------------------------------------------------------------------
# Cartesian monoidal structure: (Set, Tuple, ())
# ---------------------------------------------------------------------------

"""
    SetCartesian

GATlab model for the cartesian monoidal structure on Set.

Objects are Julia types, morphisms are functions, tensor is Tuple,
unit is the empty tuple ().

nLab: cartesian+monoidal+category.
"""
struct SetCartesian end

# Single @instance at the highest theory level (ThSymmetricMonoidalCategory)
# to avoid method overwriting errors. GATlab generates methods for all
# inherited operations, so declaring at multiple levels would conflict.
@instance ThSymmetricMonoidalCategory{Type, Function} [model::SetCartesian] begin
    id(a::Type) = identity
    compose(f::Function, g::Function) = g ∘ f  # diagrammatic: f then g

    otimes(a::Type, b::Type) = Tuple{a, b}
    otimes(f::Function, g::Function) = x -> (f(x[1]), g(x[2]))
    munit() = Tuple{}

    # Associator: ((a,b),c) <-> (a,(b,c))
    associator(a::Type, b::Type, c::Type) = x -> (x[1][1], (x[1][2], x[2]))
    associator_inv(a::Type, b::Type, c::Type) = x -> ((x[1], x[2][1]), x[2][2])

    # Left unitor: ((),a) <-> a
    left_unitor(a::Type) = x -> x[2]
    left_unitor_inv(a::Type) = a -> ((), a)

    # Right unitor: (a,()) <-> a
    right_unitor(a::Type) = x -> x[1]
    right_unitor_inv(a::Type) = a -> (a, ())

    # Braiding: (a,b) <-> (b,a)
    braid(a::Type, b::Type) = x -> (x[2], x[1])
    braid_inv(a::Type, b::Type) = x -> (x[2], x[1])
end

# ---------------------------------------------------------------------------
# Cocartesian monoidal structure: (Set, Either, Nothing)
# ---------------------------------------------------------------------------

"""
    SetCocartesian

GATlab model for the cocartesian monoidal structure on Set.

Objects are Julia types, morphisms are functions, tensor is Either,
unit is Nothing (the initial object / Void).

nLab: cocartesian+monoidal+category.
"""
struct SetCocartesian end

# Single @instance at ThSymmetricMonoidalCategory (same reasoning as SetCartesian).
@instance ThSymmetricMonoidalCategory{Type, Function} [model::SetCocartesian] begin
    id(a::Type) = identity
    compose(f::Function, g::Function) = g ∘ f

    otimes(a::Type, b::Type) = Either{a, b}
    otimes(f::Function, g::Function) = x -> either_match(a -> Left(f(a)), b -> Right(g(b)), x)
    munit() = Nothing

    # Associator: Either(Either(a,b), c) <-> Either(a, Either(b,c))
    associator(a::Type, b::Type, c::Type) = x -> either_match(
        ab -> either_match(a -> Left(a), b -> Right(Left(b)), ab),
        c -> Right(Right(c)),
        x
    )
    associator_inv(a::Type, b::Type, c::Type) = x -> either_match(
        a -> Left(Left(a)),
        bc -> either_match(b -> Left(Right(b)), c -> Right(c), bc),
        x
    )

    # Left unitor: Either(Nothing, a) <-> a
    left_unitor(a::Type) = x -> either_match(v -> absurd(v), a -> a, x)
    left_unitor_inv(a::Type) = a -> Right(a)

    # Right unitor: Either(a, Nothing) <-> a
    right_unitor(a::Type) = x -> either_match(a -> a, v -> absurd(v), x)
    right_unitor_inv(a::Type) = a -> Left(a)

    # Braiding: Left(a) <-> Right(a), Right(b) <-> Left(b)
    braid(a::Type, b::Type) = x -> either_match(a -> Right(a), b -> Left(b), x)
    braid_inv(a::Type, b::Type) = x -> either_match(a -> Right(a), b -> Left(b), x)
end
