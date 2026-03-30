# mwablab development environment
# For use with devcontainers or standalone: docker build -t mwablab .
#
# Usage:
#   docker build -t mwablab .
#   docker run -it -v $(pwd):/workspace mwablab
#
# Or via VS Code devcontainer (recommended).

FROM debian:bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    build-essential \
    pkg-config \
    zlib1g-dev \
    libgmp-dev \
    libffi-dev \
    libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# --- GHCup (Haskell) ---------------------------------------------------------
ENV GHCUP_INSTALL_BASE_PREFIX=/opt
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | \
    BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_GHC_VERSION=9.8.4 \
    BOOTSTRAP_HASKELL_CABAL_VERSION=3.12.1.0 \
    BOOTSTRAP_HASKELL_INSTALL_HLS=1 \
    sh

ENV PATH="/root/.ghcup/bin:${PATH}"

# --- Agda ---------------------------------------------------------------------
RUN cabal update && cabal install Agda-2.8.0 --install-method=copy \
    && mkdir -p /root/.agda

# Agda standard library + agda-categories
RUN cd /tmp \
    && curl -L https://github.com/agda/agda-stdlib/archive/refs/tags/v2.3.tar.gz | tar xz \
    && mv agda-stdlib-2.3 /opt/agda-stdlib \
    && curl -L https://github.com/agda/agda-categories/archive/refs/tags/v0.3.0.tar.gz | tar xz \
    && mv agda-categories-0.3.0 /opt/agda-categories \
    && printf '/opt/agda-stdlib/standard-library.agda-lib\n/opt/agda-categories/agda-categories.agda-lib\n' \
       > /root/.agda/libraries

# --- SBCL (Common Lisp) ------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    sbcl \
    && rm -rf /var/lib/apt/lists/*

# --- TeX (minimal for specs) -------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    texlive-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-science \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# --- hlint --------------------------------------------------------------------
RUN cabal install hlint --install-method=copy

# --- Workspace ----------------------------------------------------------------
WORKDIR /workspace

# Verify tools are available
RUN ghc --version && cabal --version && agda --version && sbcl --version

CMD ["bash"]
