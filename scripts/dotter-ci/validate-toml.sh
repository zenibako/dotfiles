#!/bin/bash
# Validate TOML files
# Usage: validate-toml.sh [file1] [file2] ...
# If no files specified, validates default list

set -e

# Check if we have toml support
# Returns: 0=valid, 1=invalid, 2=no toml module
check_toml() {
  python3 -c '
import sys
try:
    import tomllib
    with open(sys.argv[1], "rb") as f:
        tomllib.load(f)
except ImportError:
    try:
        import toml
        with open(sys.argv[1], "r") as f:
            toml.load(f)
    except ImportError:
        sys.exit(2)
sys.exit(0)
' "$1"
}

FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
  FILES=(
    '.dotter/global.toml'
    'atuin/config.toml'
    'iamb/config.toml'
    'jj/config.toml'
  )
fi

FAILED=0
for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "⚠ $file not found, skipping"
    continue
  fi
  
  check_toml "$file"
  rc=$?
  
  if [ $rc -eq 0 ]; then
    echo "✓ $file is valid TOML"
  elif [ $rc -eq 2 ]; then
    echo "⚠ Python toml module not available (install with: pip install toml)"
    exit 1
  else
    echo "✗ $file failed validation"
    python3 -c '
import sys
try:
    import tomllib
    with open(sys.argv[1], "rb") as f:
        tomllib.load(f)
except ImportError:
    import toml
    with open(sys.argv[1], "r") as f:
        toml.load(f)
' "$file" 2>&1 || true
    FAILED=1
  fi
done

exit $FAILED
