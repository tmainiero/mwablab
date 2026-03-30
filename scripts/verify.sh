#!/usr/bin/env bash
set -euo pipefail

echo "=== mwablab verify ==="
echo "Running nix flake check..."
nix flake check
echo "=== All checks passed ==="
