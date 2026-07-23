#!/bin/sh
# Reconcile LM Studio's loaded models with what opencode expects.
#
# opencode addresses a local model by identifier, and an identifier is assigned
# at load time — reload without `--identifier` and it reverts to the model key,
# which is a different string, and every agent pinned to it starts returning
# 400. See src/lmstudio/models.toml for the full mechanism.
#
# Two sources of truth, deliberately kept apart so they cannot silently agree
# on something wrong:
#   src/lmstudio/models.toml            identifier -> model key
#   ~/.config/opencode/opencode.json    identifier -> context length
#
# Usage:
#   scripts/lmstudio_sync.sh            report drift, exit 1 if any
#   scripts/lmstudio_sync.sh --fix      load/reload models to match
#
# --fix only touches identifiers named in models.toml. Anything else you have
# loaded is left alone.
set -eu

_REPO="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
_MAP="$_REPO/src/lmstudio/models.toml"
_CFG="${OPENCODE_CONFIG_LIVE:-$HOME/.config/opencode/opencode.json}"

_LMS="$HOME/.lmstudio/bin/lms"
[ -x "$_LMS" ] || _LMS="$(command -v lms 2>/dev/null || true)"

if [ -z "$_LMS" ] || [ ! -x "$_LMS" ]; then
  echo "lms CLI not found (expected ~/.lmstudio/bin/lms) — is LM Studio installed?" >&2
  exit 2
fi
[ -f "$_MAP" ] || { echo "missing $_MAP" >&2; exit 2; }
[ -f "$_CFG" ] || { echo "missing $_CFG — deploy first" >&2; exit 2; }

_FIX=0
[ "${1:-}" = "--fix" ] && _FIX=1

_PS="$("$_LMS" ps --json 2>/dev/null)" || {
  echo "could not query LM Studio — is the server running? (lms server status)" >&2
  exit 2
}

# Emit one tab-separated plan line per identifier:
#   OK|LOAD|RELOAD|RENAME <identifier> <model key> <want ctx> <have ctx> <unload first>
_PLAN="$(LMS_PS="$_PS" python3 - "$_MAP" "$_CFG" <<'PY'
import json, os, sys, tomllib

wanted = tomllib.load(open(sys.argv[1], "rb")).get("identifiers", {})
cfg = json.load(open(sys.argv[2]))
declared = cfg.get("provider", {}).get("lmstudio", {}).get("models", {})
loaded = {m["identifier"]: m for m in json.loads(os.environ["LMS_PS"]) if m.get("identifier")}

# Only reconcile identifiers an agent is actually pinned to. A mapping entry
# nothing references is inventory, not a fault, and loading it would burn
# memory for nothing.
used = {
    a["model"].split("/", 1)[1]
    for a in cfg.get("agent", {}).values()
    if isinstance(a.get("model"), str) and a["model"].startswith("lmstudio/")
}

for ident in sorted(used):
    if ident not in wanted:
        print(f"UNMAPPED\t{ident}\t-\t-\t-\t-")
        continue
    key = wanted[ident]
    want_ctx = declared.get(ident, {}).get("limit", {}).get("context") or 0
    cur = loaded.get(ident)

    if cur is None:
        # The usual drift: the model we want IS resident, just under the
        # identifier it defaulted to (its model key). Loading a second copy
        # would exceed memory and LM Studio refuses outright, so the stale one
        # has to go first. Never claim an identifier that is itself wanted.
        stale = next(
            (i for i, m in loaded.items()
             if m.get("modelKey") == key and i not in wanted),
            "-",
        )
        print(f"{'RENAME' if stale != '-' else 'LOAD'}\t{ident}\t{key}\t{want_ctx}\t-\t{stale}")
    elif want_ctx and cur.get("contextLength", 0) < want_ctx:
        print(f"RELOAD\t{ident}\t{key}\t{want_ctx}\t{cur.get('contextLength')}\t{ident}")
    else:
        print(f"OK\t{ident}\t{key}\t{want_ctx}\t{cur.get('contextLength')}\t-")
PY
)"

_drift=0
echo "$_PLAN" | while IFS="$(printf '\t')" read -r _act _id _key _want _have _stale; do
  case "$_act" in
    OK)       echo "  ok       $_id  (ctx $_have)" ;;
    UNMAPPED) echo "  UNMAPPED $_id  — pinned by an agent but absent from $(basename "$_MAP")" ;;
    LOAD)     echo "  MISSING  $_id  -> $_key (ctx $_want)" ;;
    RENAME)   echo "  DRIFTED  $_id  — loaded as '$_stale' instead" ;;
    RELOAD)   echo "  CONTEXT  $_id  loaded with $_have, need $_want" ;;
  esac
done

# The loop above runs in a subshell, so recompute the verdict here.
if ! echo "$_PLAN" | grep -qv '^OK'; then
  echo "LM Studio matches the opencode config."
  exit 0
fi

if [ "$_FIX" -eq 0 ]; then
  echo
  echo "Run 'scripts/lmstudio_sync.sh --fix' to reconcile."
  exit 1
fi

echo
echo "$_PLAN" | grep -v '^OK' | while IFS="$(printf '\t')" read -r _act _id _key _want _have _stale; do
  if [ "$_act" = "UNMAPPED" ]; then
    echo "  skipping $_id — add it to $(basename "$_MAP") first" >&2
    continue
  fi
  # `lms load` refuses an identifier that already exists, and refuses to load a
  # second copy of a model that is already resident ("insufficient system
  # resources"). Both cases are cleared by unloading the identifier we are
  # about to replace — never anything else.
  if [ "$_stale" != "-" ]; then
    echo "  unloading $_stale"
    "$_LMS" unload "$_stale" >/dev/null 2>&1 || true
  fi
  echo "  loading   $_id -> $_key (ctx $_want)"
  if [ "$_want" -gt 0 ] 2>/dev/null; then
    "$_LMS" load "$_key" --identifier "$_id" --context-length "$_want" -y >/dev/null
  else
    "$_LMS" load "$_key" --identifier "$_id" -y >/dev/null
  fi
done

echo
echo "Reconciled. Verifying:"
exec "$0"
