#!/bin/bash
# Validate all themes
# Usage: validate-themes.sh [theme1] [theme2] ...
# If no themes specified, validates default list

set -e

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
  trap "rm -rf '$DEPLOY_DIR'" EXIT
  
  cat > .dotter/local.toml <<EOF
packages = ["default", "linux", "$theme"]

[variables]
email = "test@default.example.com"
github_personal_access_token = "ghp_test123456789"
shell_bin_path = "\$HOME/bin"
EOF
  
  if HOME="$DEPLOY_DIR" dotter deploy --force --verbose --noconfirm 2>&1 | tee /tmp/theme-$theme.log; then
    echo "✓ Theme $theme deployed successfully"
  else
    echo "✗ Theme $theme failed to deploy"
    cat /tmp/theme-$theme.log
    FAILED=1
  fi
  
  rm -rf "$DEPLOY_DIR"
  trap - EXIT
done

if [ $FAILED -eq 1 ]; then
  echo "ERROR: Some themes failed validation"
  exit 1
fi

echo "✓ All themes validated successfully!"
rm -f /tmp/theme-*.log
