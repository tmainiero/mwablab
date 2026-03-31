{
  description = "mwablab — Categorical foundations as code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # --- Haskell -----------------------------------------------------------
        hsPkgs = pkgs.haskell.packages.ghc98;
        hsDeps = hp: with hp; [
          QuickCheck
          hedgehog
          tasty
          tasty-quickcheck
          tasty-hedgehog
          tasty-hunit
          containers
          mtl
          aeson
          megaparsec
          optparse-applicative
        ];
        hsShellPkgs = [
          (hsPkgs.ghcWithPackages hsDeps)
          hsPkgs.cabal-install
          hsPkgs.haskell-language-server
          pkgs.hlint
        ];

        # --- Semtex (TeX preprocessor) -------------------------------------------
        semtex = hsPkgs.callCabal2nix "semtex" ./tools/semtex-hs {};

        # --- Agda --------------------------------------------------------------
        agdaWithPkgs = pkgs.agda.withPackages (ap: [
          ap.standard-library
          ap.agda-categories
        ]);

        # --- Common Lisp -------------------------------------------------------
        lispPkgs = [
          pkgs.sbcl
        ];

        # --- Docs --------------------------------------------------------------
        docPkgs = [
          pkgs.texliveFull
          pkgs.pandoc
          pkgs.graphviz
        ];

        # --- Shared ------------------------------------------------------------
        sharedPkgs = [
          pkgs.git
        ];

      in {
        # Dev shells
        devShells = {
          default = pkgs.mkShell {
            name = "mwablab-full";
            buildInputs = hsShellPkgs ++ [ agdaWithPkgs ] ++ [ semtex ] ++ lispPkgs ++ docPkgs ++ sharedPkgs;
            shellHook = ''
              echo "mwablab — full dev shell (Haskell + Agda + CL + docs)"
            '';
          };

          haskell = pkgs.mkShell {
            name = "mwablab-haskell";
            buildInputs = hsShellPkgs ++ sharedPkgs;
            shellHook = ''
              echo "mwablab — Haskell dev shell (GHC ${hsPkgs.ghc.version})"
            '';
          };

          agda = pkgs.mkShell {
            name = "mwablab-agda";
            buildInputs = [ agdaWithPkgs ] ++ sharedPkgs;
            shellHook = ''
              echo "mwablab — Agda dev shell"
            '';
          };

          lisp = pkgs.mkShell {
            name = "mwablab-lisp";
            buildInputs = lispPkgs ++ sharedPkgs;
            shellHook = ''
              echo "mwablab — Common Lisp dev shell (SBCL)"
            '';
          };
        };

        # Checks — run via `nix flake check`
        checks = {
          agda-typecheck = pkgs.runCommand "agda-typecheck" {
            buildInputs = [ agdaWithPkgs ];
          } ''
            mkdir -p $out
            cp -r ${self}/src/agda/* $out/
            cd $out
            if [ -f Everything.agda ]; then
              agda --safe Everything.agda || exit 1
            fi
          '';

          hlint = pkgs.runCommand "hlint" {
            buildInputs = [ pkgs.hlint ];
          } ''
            cd ${self}/src/haskell
            if ls src/Cat/*.hs 1>/dev/null 2>&1; then
              hlint src/ || exit 1
            fi
            touch $out
          '';

          haskell-tests = pkgs.runCommand "haskell-tests" {
            buildInputs = hsShellPkgs;
            CABAL_CONFIG = "/dev/null";
          } ''
            export HOME=$(mktemp -d)
            cp -r ${self}/src/haskell $HOME/haskell
            chmod -R u+w $HOME/haskell
            cd $HOME/haskell
            cabal --config-file=/dev/null build all 2>&1
            cabal --config-file=/dev/null test all 2>&1
            touch $out
          '';

          semtex-registry = pkgs.runCommand "semtex-registry" {
            buildInputs = [ semtex pkgs.glibcLocales ];
            LANG = "en_US.UTF-8";
            LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          } ''
            cp -r ${self}/src/spec $TMPDIR/spec
            cp -r ${self}/src/haskell $TMPDIR/haskell
            cp -r ${self}/src/agda $TMPDIR/agda
            cp -r ${self}/src/lisp $TMPDIR/lisp
            chmod -R u+w $TMPDIR/spec
            mkdir -p $TMPDIR/src
            ln -s $TMPDIR/spec $TMPDIR/src/spec
            ln -s $TMPDIR/haskell $TMPDIR/src/haskell
            ln -s $TMPDIR/agda $TMPDIR/src/agda
            ln -s $TMPDIR/lisp $TMPDIR/src/lisp
            cd $TMPDIR
            semtex extract spec/foundations/*.tex
            semtex merge spec/
            semtex validate spec/registry.json .
            touch $out
          '';

          docs-build = pkgs.runCommand "docs-build" {
            buildInputs = [ pkgs.pandoc semtex pkgs.glibcLocales ];
            LANG = "en_US.UTF-8";
            LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          } ''
            cp -r ${self}/docs $TMPDIR/docs
            cp -r ${self}/src $TMPDIR/src
            chmod -R u+w $TMPDIR/docs $TMPDIR/src
            cd $TMPDIR/docs
            if [ -f build.sh ] && ls content/*.md 1>/dev/null 2>&1; then
              bash build.sh || exit 1
            fi
            touch $out
          '';

          lisp-load = pkgs.runCommand "lisp-load" {
            buildInputs = lispPkgs;
          } ''
            export HOME=$(mktemp -d)
            sbcl --noinform --non-interactive \
              --eval '(require :asdf)' \
              --eval "(push (pathname \"${self}/src/lisp/\") asdf:*central-registry*)" \
              --eval '(asdf:load-system :mwablab)' \
              --eval '(quit)'
            touch $out
          '';
        };

        # Apps
        apps.verify = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "verify" ''
            set -euo pipefail
            echo "=== mwablab verify ==="
            nix flake check "$@"
            echo "=== All checks passed ==="
          '';
        };
      });
}
