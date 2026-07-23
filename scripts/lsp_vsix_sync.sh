#!/bin/sh
# Fetch the pinned VSIX-distributed language servers from Open VSX and unpack
# them into ~/.local/share/lsp-servers/<name>/ — replacing the old dependency
# on an editor's bundled extensions directory entirely.
#
# Pins live in src/packages.k (vsix_lsp_servers); KCL renders them to
# out/.lsp_vsix_meta.json at generation time. A .vsix is just a zip whose
# payload sits under extension/ — no VS Code, no `code` CLI, no marketplace
# client involved.
#
# Usage:
#   scripts/lsp_vsix_sync.sh          sync anything whose pin doesn't match
#   scripts/lsp_vsix_sync.sh --check  report drift only, exit 1 if any
set -eu

_REPO="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
_META="$_REPO/out/.lsp_vsix_meta.json"
_DEST="${LSP_SERVERS_DIR:-$HOME/.local/share/lsp-servers}"

[ -f "$_META" ] || { echo "missing $_META — run ./deploy.sh or scripts/pre_deploy.sh first" >&2; exit 2; }
command -v curl  >/dev/null 2>&1 || { echo "curl not found" >&2; exit 2; }
command -v unzip >/dev/null 2>&1 || { echo "unzip not found" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 2; }

_CHECK=0
[ "${1:-}" = "--check" ] && _CHECK=1

# One tab-separated row per server: name version target url artifact
_rows="$(mktemp)"
python3 - "$_META" > "$_rows" <<'PY'
import json, sys
meta = json.load(open(sys.argv[1]))
for s in meta.get("servers", []):
    ns, name, ver = s["namespace"], s["name"], s["version"]
    tp = s.get("target_platform") or ""
    if tp:
        url = f"https://open-vsx.org/api/{ns}/{name}/{tp}/{ver}/file/{ns}.{name}-{ver}@{tp}.vsix"
    else:
        url = f"https://open-vsx.org/api/{ns}/{name}/{ver}/file/{ns}.{name}-{ver}.vsix"
    print("\t".join([name, ver, tp or "-", url, s["artifact_check"]]))
PY

_drift=0
_fail=0
_TAB="$(printf '\t')"
while IFS="$_TAB" read -r _name _ver _tp _url _artifact; do
  [ "$_tp" = "-" ] && _tp=""
  _want="$_ver${_tp:+@$_tp}"
  _dir="$_DEST/$_name"
  _have="$(cat "$_dir/.vsix-version" 2>/dev/null || true)"

  if [ "$_have" = "$_want" ] && [ -e "$_dir/$_artifact" ]; then
    echo "  ok       $_name  ($_want)"
    continue
  fi

  _drift=1
  if [ "$_CHECK" -eq 1 ]; then
    echo "  STALE    $_name  have '${_have:-none}', want '$_want'"
    continue
  fi

  echo "  syncing  $_name -> $_want"
  _tmpd="$(mktemp -d)"
  if ! curl -fsSL --retry 2 --connect-timeout 15 --max-time 900 -o "$_tmpd/pkg.vsix" "$_url"; then
    echo "  FAILED   $_name — download error: $_url" >&2
    _fail=1; rm -rf "$_tmpd"; continue
  fi
  if ! unzip -q "$_tmpd/pkg.vsix" 'extension/*' -d "$_tmpd"; then
    echo "  FAILED   $_name — unzip error" >&2
    _fail=1; rm -rf "$_tmpd"; continue
  fi
  if [ ! -e "$_tmpd/extension/$_artifact" ]; then
    echo "  FAILED   $_name — $_artifact missing from VSIX" >&2
    _fail=1; rm -rf "$_tmpd"; continue
  fi
  mkdir -p "$_DEST"
  rm -rf "$_dir"
  mv "$_tmpd/extension" "$_dir"
  printf '%s\n' "$_want" > "$_dir/.vsix-version"
  rm -rf "$_tmpd"
  echo "  synced   $_name  ($_want)"
done < "$_rows"
rm -f "$_rows"

if [ "$_fail" -ne 0 ]; then
  exit 1
fi
if [ "$_CHECK" -eq 1 ] && [ "$_drift" -ne 0 ]; then
  echo
  echo "Run 'scripts/lsp_vsix_sync.sh' to sync."
  exit 1
fi
echo "LSP VSIX servers match the pinned versions."
