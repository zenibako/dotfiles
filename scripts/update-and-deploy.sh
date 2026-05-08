#!/bin/bash
# Pull latest from origin/main and deploy dotfiles
# Usage: update-and-deploy.sh

set -eo pipefail

echo "Fetching latest changes..."
jj git fetch
echo ""

echo "Syncing to origin/main..."
# Rebase working copy onto the latest main at origin
jj rebase -s "@" -d "main"
echo ""

echo "Deploying dotfiles with dotter..."
dotter deploy
echo ""

echo "Status:"
jj status

echo ""
echo "Done. Restart your shell or source ~/.zshrc for all changes to take effect."
