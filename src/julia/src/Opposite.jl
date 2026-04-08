# Opposite category C^op.
#
# Mathematical definition (Stacks Project 001M; nLab: opposite+category):
# Given a category C, the opposite category C^op has the same objects, with
# Mor_{C^op}(x, y) = Mor_C(y, x).
# Composition is reversed: f .^op g = g . f.
#
# GATlab's own stdlib implements this pattern (see GATlab/src/stdlib/models/op.jl).
# The key: use @instance with `where {ObT, HomT}` to be generic over the
# wrapped model's sorts. GATlab's OpC does exactly this.
#
# We follow that pattern here. The CatWrapper mechanism in GATlab provides
# a uniform interface for delegating to wrapped models.
#
# Stacks Project 001M; nLab: opposite+category.

using GATlab

export OpCat, opposite

"""
    OpCat{ObT, HomT, M}

The opposite category model. Wraps a ThCategory model M, reversing
the direction of morphisms: composition in C^op is reversed, and
dom/codom are swapped.

This is a proper GATlab model with a generic @instance declaration,
following the pattern of GATlab's own `OpC` in its stdlib.

Given a model m implementing ThCategory{ObT, HomT}:
- Objects are the same: Ob in C^op = Ob in C
- Morphisms are the same values but with swapped dom/codom
- id is unchanged
- compose(f, g) in C^op = compose(g, f) in C

Stacks Project 001M; nLab: opposite+category.
"""
struct OpCat{ObT, HomT, M}
    inner::M
end

"""
    opposite(m, ObT, HomT)

Construct the opposite category model from a ThCategory model.

Stacks Project 001M; nLab: opposite+category.
"""
opposite(m::M, ::Type{ObT}, ::Type{HomT}) where {ObT, HomT, M} =
    OpCat{ObT, HomT, M}(m)

@instance ThCategory{ObT, HomT} [model::OpCat{ObT, HomT, M}] where {ObT, HomT, M} begin
    id(a::ObT) = ThCategory.id[model.inner](a)
    compose(f::HomT, g::HomT) = ThCategory.compose[model.inner](g, f)
end
