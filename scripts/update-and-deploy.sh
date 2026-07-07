#!/bin/bash
# Pull latest from origin/main and deploy dotfiles
# Usage: update-and-deploy.sh

set -eo pipefail

# Shared ANSI colors + output helpers (_STEP/_CMD/_INFO/_ERR/_WARN/_OK).
# shellcheck source=dotter/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotter/lib.sh"

_STEP "Fetching latest changes"
_CMD "jj git fetch"
jj git fetch
echo ""

_STEP "Syncing to origin/main"
_INFO "Rebasing working copy onto the latest main"
_CMD 'jj rebase -s "@" -d "main"'
jj rebase -s "@" -d "main"
echo ""

_STEP "Deploying dotfiles with dotter"
_CMD "dotter deploy"
dotter deploy
echo ""

_STEP "Status"
_CMD "jj status"
jj status

echo ""
_OK "Done. Restart your shell or source ~/.zshrc for all changes to take effect."