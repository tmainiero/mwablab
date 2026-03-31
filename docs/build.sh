#!/usr/bin/env bash
# Build the mwablab documentation site.
# Requires: pandoc, python3
# Usage: ./build.sh [theme]
#   theme: catppuccin (default), nord, gruvbox, dracula, tokyo-night
# Output: docs/site/
set -euo pipefail

THEME="${1:-catppuccin}"
DOCS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$DOCS_DIR/.." && pwd)"
SITE_DIR="$DOCS_DIR/site"
CONTENT_DIR="$DOCS_DIR/content"
TEMPLATE="$DOCS_DIR/templates/default.html"
THEME_FILE="$DOCS_DIR/css/themes/$THEME.css"
SEMTEX="semtex"

if [ ! -f "$THEME_FILE" ]; then
  echo "Unknown theme: $THEME"
  echo "Available: $(ls "$DOCS_DIR/css/themes/" | sed 's/\.css$//' | tr '\n' ' ')"
  exit 1
fi

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR/foundations" "$SITE_DIR/css"

# --- Pre-build: generate registry and MathJax macros ---
if command -v "$SEMTEX" >/dev/null 2>&1; then
  echo "Generating concept registry..."
  $SEMTEX extract "$PROJECT_ROOT/src/spec/foundations/"*.tex 2>/dev/null || true
  $SEMTEX merge "$PROJECT_ROOT/src/spec/" 2>/dev/null || true
  echo "Syncing MathJax macros from preamble..."
  $SEMTEX mathjax "$PROJECT_ROOT/src/spec/preamble.tex" \
    > "$SITE_DIR/mathjax_config.js"
  if command -v dot >/dev/null 2>&1; then
    echo "Generating concept graph..."
    $SEMTEX graph "$PROJECT_ROOT/src/spec/registry.json" \
      | dot -Tsvg > "$SITE_DIR/concepts.svg"
  fi
fi

# Copy static assets
cp "$DOCS_DIR/css/style.css" "$SITE_DIR/css/"
cp "$THEME_FILE" "$SITE_DIR/css/theme.css"

echo "Building mwablab docs (theme: $THEME)..."

# Build function: pandoc markdown -> HTML
build_page() {
  local src="$1"
  local dst="$2"
  local root="${3:-}"

  pandoc "$src" \
    --template="$TEMPLATE" \
    --from=markdown+tex_math_dollars+yaml_metadata_block \
    --to=html5 \
    --mathjax \
    --variable="root:$root" \
    --standalone \
    --output="$dst"

  echo "  built: $dst"
}

# Top-level pages
build_page "$CONTENT_DIR/index.md"          "$SITE_DIR/index.html" ""
build_page "$CONTENT_DIR/getting-started.md" "$SITE_DIR/getting-started.html" ""

# Foundations
for f in "$CONTENT_DIR/foundations/"*.md; do
  name="$(basename "$f" .md)"
  build_page "$f" "$SITE_DIR/foundations/$name.html" "../"
done

echo "Done. Open docs/site/index.html"
