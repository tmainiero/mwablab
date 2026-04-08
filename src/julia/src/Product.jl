# Product category C x D.
#
# Mathematical definition (nLab: product+category):
# Given categories C and D, the product category C x D has:
# - Objects: pairs (X, Y) with X in Ob(C) and Y in Ob(D)
# - Morphisms: pairs (f, g) with f in C and g in D
# - Identity: (id_X, id_Y)
# - Composition: (f2, g2) . (f1, g1) = (f2 . f1, g2 . g1)
#
# Design decision: ProdHom stays as a concrete morphism type (plain struct).
# The product category construction would ideally return a GATlab-compatible
# model, but parameterizing @instance over two arbitrary inner models hits
# the same limitation as Opposite: GATlab needs concrete type parameters.

export ProdHom

"""
    ProdHom{F,G}

A morphism in the product category. Stores a pair of component morphisms.

In the Haskell track this uses type families to project pair types; here
we use a parametric struct for type safety on the components.

nLab: product+category.
"""
struct ProdHom{F,G}
    fst::F
    snd::G
end

# Note: The parametric struct already provides ProdHom(f, g) via
# automatic type inference, so no extra constructor is needed.

# Note: A GATlab @instance for the product category would look like:
#
#   struct ProductModel{M1, M2}
#       first::M1
#       second::M2
#   end
#
#   @instance ThCategory{Tuple{A,B}, ProdHom} [model::ProductModel{M1,M2}] begin
#       id((a,b)) = ProdHom(ThCategory.id[model.first](a),
#                            ThCategory.id[model.second](b))
#       compose(fg1::ProdHom, fg2::ProdHom) =
#           ProdHom(ThCategory.compose[model.first](fg1.fst, fg2.fst),
#                   ThCategory.compose[model.second](fg1.snd, fg2.snd))
#   end
#
# This requires M1, M2 to be concrete GATlab model types with known
# Ob/Hom sorts. Deferred until we have concrete use cases.
