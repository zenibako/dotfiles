#!/bin/bash
# Validate all themes
# Usage: validate-themes.sh [theme1] [theme2] ...
# If no themes specified, validates default list

set -euo pipefail

# Array to track all temp directories for cleanup
DEPLOY_DIRS=()

cleanup() {
  for dir in "${DEPLOY_DIRS[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

# Ensure dotter is installed
if ! command -v dotter &> /dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "$SCRIPT_DIR/install-dotter.sh"
fi

THEMES=("$@")
if [ ${#THEMES[@]} -eq 0 ]; then
  THEMES=("nightowl" "tokyonight" "monokai")
fi

FAILED=0

for theme in "${THEMES[@]}"; do
  echo "Testing theme: $theme"
  
  DEPLOY_DIR=$(mktemp -d)
  DEPLOY_DIRS+=("$DEPLOY_DIR")
  
  # Create .dotter directory and local.toml inside temp deploy dir
  mkdir -p "$DEPLOY_DIR/.dotter"
  cat > "$DEPLOY_DIR/.dotter/local.toml" <<EOF
packages = ["default", "linux", "$theme"]

[variables]
name = "Test User"
email = "test@default.example.com"
github_personal_access_token = "ghp_test123456789"
shell_bin_path = "\$HOME/bin"
username = "test.user"
gpg_key = ""
EOF
  
  # Copy global.toml to temp deploy dir so dotter can find it
  cp .dotter/global.toml "$DEPLOY_DIR/.dotter/global.toml"
  
  if HOME="$DEPLOY_DIR" dotter --local-config "$DEPLOY_DIR/.dotter/local.toml" deploy --force --verbose --noconfirm 2>&1 | tee "/tmp/theme-$theme.log"; then
    echo "✓ Theme $theme deployed successfully"
  else
    echo "✗ Theme $theme failed to deploy"
    cat "/tmp/theme-$theme.log"
    FAILED=1
  fi
done

if [ $FAILED -eq 1 ]; then
  echo "ERROR: Some themes failed validation"
  exit 1
fi

echo "✓ All themes validated successfully!"
rm -f /tmp/theme-*.log