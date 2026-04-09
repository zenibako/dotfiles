#!/bin/bash
# Install dotter if not already installed
# Usage: install-dotter.sh

set -e

if command -v dotter &> /dev/null; then
  echo "dotter already installed: $(dotter --version)"
  exit 0
fi

echo "Installing dotter..."

case "$OSTYPE" in
  linux-gnu*)
    wget -q https://github.com/SuperCuber/dotter/releases/latest/download/dotter-linux-x64-musl -O /tmp/dotter
    chmod +x /tmp/dotter
    sudo mv /tmp/dotter /usr/local/bin/
    ;;
  darwin*)
    brew install dotter
    ;;
  *)
    echo "Unknown platform: $OSTYPE"
    exit 1
    ;;
esac

echo "dotter installed: $(dotter --version)"
