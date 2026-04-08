"""
    MwabLab

Categorical foundations implemented in Julia, using GATlab.jl for algebraic
theories (@theory) and concrete models (@instance).

The theory hierarchy mirrors the mathematical dependency chain:
  ThCategory -> ThMonoidalCategory -> ThBraidedMonoidalCategory -> ThSymmetricMonoidalCategory
  ThFunctor, ThNaturalTransformation, ThNaturalIsomorphism (multi-sorted theories)

GATlab @theory is used for all categorical structures expressible as
generalized algebraic theories. Plain structs are used only for concrete
morphism types (ProdHom) and standalone bifunctor data.

Reference: nLab, Stacks Project Part I.
"""
module MwabLab

using GATlab

# Export all @theory names so tests/users can access ThX.op[model](...) syntax
export ThCategory, ThMonoidalCategory, ThBraidedMonoidalCategory, ThSymmetricMonoidalCategory
export ThFunctor, ThNaturalTransformation, ThNaturalIsomorphism

# Theory hierarchy (GATlab @theory)
include("Category.jl")
include("Monoidal.jl")
include("BraidedMonoidal.jl")
include("SymmetricMonoidal.jl")

# Multi-sorted theories (GATlab @theory)
include("Functor.jl")
include("NaturalTransformation.jl")
include("NaturalIsomorphism.jl")

# Category constructions (GATlab @instance where possible)
include("Opposite.jl")
include("Product.jl")
include("Bifunctor.jl")

# Concrete models (GATlab @instance)
include("Examples.jl")

end # module MwabLab
