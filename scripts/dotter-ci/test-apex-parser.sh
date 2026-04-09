#!/bin/bash
# Test Apex tree-sitter parser compilation
# Usage: test-apex-parser.sh

set -e

PARSERS_LUA=$(mktemp)
trap 'rm -f "$PARSERS_LUA"' EXIT

curl -fsSL -o "$PARSERS_LUA" \
  https://raw.githubusercontent.com/nvim-treesitter/nvim-treesitter/main/lua/nvim-treesitter/parsers.lua

REVISION=$(awk '
  /^  apex = / { in_apex = 1 }
  in_apex && /revision = / {
    match($0, /[0-9a-f]{40}/)
    print substr($0, RSTART, RLENGTH)
    exit
  }
' "$PARSERS_LUA")

if [ -z "$REVISION" ]; then
  echo "ERROR: Could not extract apex revision from $PARSERS_LUA"
  exit 1
fi

echo "Building tree-sitter-sfapex apex parser at revision $REVISION"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR" "$PARSERS_LUA"' EXIT

git clone --quiet https://github.com/aheber/tree-sitter-sfapex "$WORKDIR/sfapex"
git -C "$WORKDIR/sfapex" checkout --quiet "$REVISION"

if ! tree-sitter build -o "$WORKDIR/apex.so" "$WORKDIR/sfapex/apex"; then
  echo "ERROR: Apex tree-sitter parser failed to compile"
  exit 1
fi

if [ ! -s "$WORKDIR/apex.so" ]; then
  echo "ERROR: tree-sitter build reported success but apex.so is missing or empty"
  exit 1
fi

echo "Apex parser compiled successfully ($(stat -c%s "$WORKDIR/apex.so" 2>/dev/null || stat -f%z "$WORKDIR/apex.so" 2>/dev/null) bytes)"
