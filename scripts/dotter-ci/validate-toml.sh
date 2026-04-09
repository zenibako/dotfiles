#!/bin/bash
# Validate TOML files
# Usage: validate-toml.sh [file1] [file2] ...
# If no files specified, validates default list

set -e

# Check if we have toml support
check_toml() {
  python3 -c "
try:
    import tomllib
    with open('$1', 'rb') as f:
        tomllib.load(f)
except ImportError:
    try:
        import toml
        with open('$1', 'r') as f:
            toml.load(f)
    except ImportError:
        exit(2)
exit(0)
" 2>/dev/null
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
  
  if check_toml "$file"; then
    echo "✓ $file is valid TOML"
  elif [ $? -eq 2 ]; then
    echo "⚠ Python toml module not available (install with: pip install toml)"
    exit 1
  else
    echo "✗ $file failed validation"
    python3 -c "
try:
    import tomllib
    with open('$file', 'rb') as f:
        tomllib.load(f)
except ImportError:
    import toml
    with open('$file', 'r') as f:
        toml.load(f)
" 2>&1
    FAILED=1
  fi
done

exit $FAILED
