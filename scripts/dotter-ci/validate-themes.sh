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
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for theme in "${THEMES[@]}"; do
  echo "Testing theme: $theme"
  
  DEPLOY_DIR=$(mktemp -d)
  DEPLOY_DIRS+=("$DEPLOY_DIR")
  
  # Copy the full repo so dotter can find global.toml, pre_deploy hook, and source files
  # Exclude .git and .dotter/cache.toml to keep it clean
  mkdir -p "$DEPLOY_DIR"
  cp -r "$REPO_DIR/"* "$DEPLOY_DIR/"
  cp -r "$REPO_DIR/.dotter" "$DEPLOY_DIR/"
  rm -rf "$DEPLOY_DIR/.git" "$DEPLOY_DIR/.dotter/cache.toml"
  
  # Write local.toml in the copied repo
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
  
  if HOME="$DEPLOY_DIR" dotter deploy --force --verbose --noconfirm 2>&1 | tee "/tmp/theme-$theme.log"; then
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