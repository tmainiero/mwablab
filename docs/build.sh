#!/usr/bin/env bash
# Build the mwablab documentation site.
# Requires: pandoc
# Output: docs/site/
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$DOCS_DIR/.." && pwd)"
SITE_DIR="$DOCS_DIR/site"
CONTENT_DIR="$DOCS_DIR/content"
TEMPLATE="$DOCS_DIR/templates/default.html"

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR/foundations" "$SITE_DIR/css"

# Copy static assets
cp "$DOCS_DIR/css/style.css" "$SITE_DIR/css/"

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

echo "Building mwablab docs..."

# Top-level pages
build_page "$CONTENT_DIR/index.md"          "$SITE_DIR/index.html" ""
build_page "$CONTENT_DIR/getting-started.md" "$SITE_DIR/getting-started.html" ""

# Foundations
for f in "$CONTENT_DIR/foundations/"*.md; do
  name="$(basename "$f" .md)"
  build_page "$f" "$SITE_DIR/foundations/$name.html" "../"
done

echo "Done. Open docs/site/index.html"
