using Test
using MwabLab
using GATlab

# ---------------------------------------------------------------------------
# Cartesian monoidal structure: (Set, Tuple, ())
# ---------------------------------------------------------------------------

@testset "Cartesian Monoidal (SetCartesian)" begin
    m = SetCartesian()

    # Convenience: extract operations from the model
    assoc = (a, b, c) -> ThMonoidalCategory.associator[m](a, b, c)
    assoc_inv = (a, b, c) -> ThMonoidalCategory.associator_inv[m](a, b, c)
    lunit = a -> ThMonoidalCategory.left_unitor[m](a)
    lunit_inv = a -> ThMonoidalCategory.left_unitor_inv[m](a)
    runit = a -> ThMonoidalCategory.right_unitor[m](a)
    runit_inv = a -> ThMonoidalCategory.right_unitor_inv[m](a)
    otimes_mor = (f, g) -> ThMonoidalCategory.otimes[m](f, g)

    @testset "associator roundtrip" begin
        alpha = assoc(Int, Int, Int)
        alpha_inv = assoc_inv(Int, Int, Int)
        for val in [((1, 2), 3), ((10, 20), 30)]
            @test alpha_inv(alpha(val)) == val
        end
        for val in [(1, (2, 3)), (10, (20, 30))]
            @test alpha(alpha_inv(val)) == val
        end
    end

    @testset "left unitor roundtrip" begin
        lu = lunit(Int)
        lu_inv = lunit_inv(Int)
        for val in [((), 42), ((), 0)]
            @test lu_inv(lu(val)) == val
        end
        for val in [42, 0, -1]
            @test lu(lu_inv(val)) == val
        end
    end

    @testset "right unitor roundtrip" begin
        ru = runit(Int)
        ru_inv = runit_inv(Int)
        for val in [(42, ()), (0, ())]
            @test ru_inv(ru(val)) == val
        end
        for val in [42, 0, -1]
            @test ru(ru_inv(val)) == val
        end
    end

    @testset "tensor bifunctoriality: identity" begin
        # otimes(id, id) should act as identity on pairs
        tensor_id = otimes_mor(identity, identity)
        @test tensor_id((3, 5)) == (3, 5)
    end

    @testset "tensor bifunctoriality: composition" begin
        f1 = x -> x + 1
        f2 = x -> x * 3
        g1 = x -> x * 2
        g2 = x -> x - 1

        # compose(otimes(f1,g1), otimes(f2,g2)) == otimes(compose(f1,f2), compose(g1,g2))
        lhs = ThCategory.compose[m](otimes_mor(f1, g1), otimes_mor(f2, g2))
        rhs = otimes_mor(
            ThCategory.compose[m](f1, f2),
            ThCategory.compose[m](g1, g2)
        )
        for val in [(2, 5), (0, 10)]
            @test lhs(val) == rhs(val)
        end
    end

    @testset "pentagon axiom" begin
        # (id bimap alpha) . alpha . (alpha bimap id)
        # = alpha . alpha
        #
        # Test on concrete values (((a,b),c),d)
        alpha = assoc(Int, Int, Int)

        for val in [(((1, 2), 3), 4), (((10, 20), 30), 40)]
            # LHS: (id bimap alpha) . alpha_{A, B*C, D} . (alpha bimap id_D)
            step1 = otimes_mor(assoc(Int, Int, Int), identity)(val)
            step2 = assoc(Int, Tuple{Int,Int}, Int)(step1)
            lhs = otimes_mor(identity, assoc(Int, Int, Int))(step2)

            # RHS: alpha_{A,B,C*D} . alpha_{A*B,C,D}
            step1r = assoc(Tuple{Int,Int}, Int, Int)(val)
            rhs = assoc(Int, Int, Tuple{Int,Int})(step1r)

            @test lhs == rhs
        end
    end

    @testset "triangle axiom" begin
        # (id bimap lambda) . alpha_{A,I,B} = rho bimap id
        #
        # Test on concrete values ((a, ()), b)
        for val in [((1, ()), 2), ((10, ()), 20)]
            # LHS: (id bimap lambda) . alpha
            step1 = assoc(Int, Tuple{}, Int)(val)
            lhs = otimes_mor(identity, lunit(Int))(step1)

            # RHS: rho bimap id
            rhs = otimes_mor(runit(Int), identity)(val)

            @test lhs == rhs
        end
    end
end

# ---------------------------------------------------------------------------
# Braided monoidal: (SetCartesian)
# ---------------------------------------------------------------------------

@testset "Braided Monoidal (SetCartesian)" begin
    m = SetCartesian()

    br = (a, b) -> ThBraidedMonoidalCategory.braid[m](a, b)
    br_inv = (a, b) -> ThBraidedMonoidalCategory.braid_inv[m](a, b)
    assoc = (a, b, c) -> ThMonoidalCategory.associator[m](a, b, c)
    assoc_inv = (a, b, c) -> ThMonoidalCategory.associator_inv[m](a, b, c)
    otimes_mor = (f, g) -> ThMonoidalCategory.otimes[m](f, g)

    @testset "braiding roundtrip" begin
        sigma = br(Int, Int)
        sigma_inv = br_inv(Int, Int)
        for val in [(1, 2), (3, 5), (0, -1)]
            @test sigma_inv(sigma(val)) == val
            @test sigma(sigma_inv(val)) == val
        end
    end

    @testset "braiding naturality" begin
        f = x -> x + 1
        g = x -> x * 2

        for val in [(3, 5), (0, 10)]
            # sigma . otimes(f,g) = otimes(g,f) . sigma
            lhs = br(Int, Int)(otimes_mor(f, g)(val))
            rhs = otimes_mor(g, f)(br(Int, Int)(val))
            @test lhs == rhs
        end
    end

    @testset "hexagon 1" begin
        # alpha_{B,C,A} . sigma_{A,B*C} . alpha_{A,B,C}
        # = (id_B bimap sigma_{A,C}) . alpha_{B,A,C} . (sigma_{A,B} bimap id_C)
        for val in [((1, 2), 3), ((10, 20), 30)]
            # LHS
            s1 = assoc(Int, Int, Int)(val)              # (a, (b, c))
            s2 = br(Int, Tuple{Int,Int})(s1)            # ((b, c), a)
            lhs = assoc(Int, Int, Int)(s2)              # (b, (c, a))

            # RHS
            r1 = otimes_mor(br(Int, Int), identity)(val)  # ((b, a), c)
            r2 = assoc(Int, Int, Int)(r1)                  # (b, (a, c))
            rhs = otimes_mor(identity, br(Int, Int))(r2)  # (b, (c, a))

            @test lhs == rhs
        end
    end

    @testset "hexagon 2" begin
        # alpha^{-1}_{C,A,B} . sigma_{A*B,C} . alpha^{-1}_{A,B,C}
        # = (sigma_{A,C} bimap id_B) . alpha^{-1}_{A,C,B} . (id_A bimap sigma_{B,C})
        for val in [(1, (2, 3)), (10, (20, 30))]
            # LHS
            s1 = assoc_inv(Int, Int, Int)(val)            # ((a, b), c)
            s2 = br(Tuple{Int,Int}, Int)(s1)              # (c, (a, b))
            lhs = assoc_inv(Int, Int, Int)(s2)            # ((c, a), b)

            # RHS
            r1 = otimes_mor(identity, br(Int, Int))(val)  # (a, (c, b))
            r2 = assoc_inv(Int, Int, Int)(r1)              # ((a, c), b)
            rhs = otimes_mor(br(Int, Int), identity)(r2)  # ((c, a), b)

            @test lhs == rhs
        end
    end
end

# ---------------------------------------------------------------------------
# Symmetric monoidal: (SetCartesian)
# ---------------------------------------------------------------------------

@testset "Symmetric Monoidal (SetCartesian)" begin
    m = SetCartesian()
    br = (a, b) -> ThSymmetricMonoidalCategory.braid[m](a, b)

    @testset "braiding involution (symmetry)" begin
        # sigma_{B,A} . sigma_{A,B} = id
        sigma = br(Int, Int)
        for val in [(1, 2), (3, 5), (0, -1)]
            @test sigma(sigma(val)) == val
        end
    end
end

# ---------------------------------------------------------------------------
# Cocartesian monoidal structure: (SetCocartesian)
# ---------------------------------------------------------------------------

@testset "Cocartesian Monoidal (SetCocartesian)" begin
    m = SetCocartesian()

    assoc = (a, b, c) -> ThMonoidalCategory.associator[m](a, b, c)
    assoc_inv = (a, b, c) -> ThMonoidalCategory.associator_inv[m](a, b, c)
    lunit = a -> ThMonoidalCategory.left_unitor[m](a)
    lunit_inv = a -> ThMonoidalCategory.left_unitor_inv[m](a)
    runit = a -> ThMonoidalCategory.right_unitor[m](a)
    runit_inv = a -> ThMonoidalCategory.right_unitor_inv[m](a)

    @testset "associator roundtrip" begin
        alpha = assoc(Int, Int, Int)
        alpha_inv = assoc_inv(Int, Int, Int)

        # Left(Left(a))
        v1 = Left(Left(1))
        @test alpha_inv(alpha(v1)).val.val == 1

        # Left(Right(b))
        v2 = Left(Right(2))
        rt = alpha(v2)
        @test rt isa Right
        @test rt.val isa Left
        @test rt.val.val == 2

        # Right(c)
        v3 = Right(3)
        rt = alpha(v3)
        @test rt isa Right
        @test rt.val isa Right
        @test rt.val.val == 3
    end

    @testset "left unitor roundtrip" begin
        lu = lunit(Int)
        lu_inv = lunit_inv(Int)
        v = Right(42)
        @test lu(v) == 42
        @test lu(lu_inv(42)) == 42
    end

    @testset "right unitor roundtrip" begin
        ru = runit(Int)
        ru_inv = runit_inv(Int)
        v = Left(42)
        @test ru(v) == 42
        @test ru(ru_inv(42)) == 42
    end

    @testset "braiding roundtrip" begin
        br = ThBraidedMonoidalCategory.braid[m](Int, Int)
        v1 = Left(1)
        v2 = Right(2)

        r1 = br(v1)
        @test r1 isa Right
        @test r1.val == 1
        r2 = br(r1)
        @test r2 isa Left
        @test r2.val == 1
    end

    @testset "braiding involution (symmetry)" begin
        br = ThSymmetricMonoidalCategory.braid[m](Int, Int)
        for v in [Left(1), Right(2), Left(42), Right(0)]
            result = br(br(v))
            if v isa Left
                @test result isa Left
                @test result.val == v.val
            else
                @test result isa Right
                @test result.val == v.val
            end
        end
    end
end
