#!/bin/bash
# Only run LWC LSP if .sf directory exists (Salesforce project)
if [ -d "$PWD/.sf" ]; then
  exec npx @salesforce/lwc-language-server --stdio
else
  # Exit cleanly - no LSP needed for non-Salesforce projects
  exit 0
fi
