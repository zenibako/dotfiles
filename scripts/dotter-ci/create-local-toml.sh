#!/bin/bash
# Generate local.toml for a specific profile
# Usage: create-local-toml.sh [--force] [--ci] <profile> [theme] [output-file]
# Example: create-local-toml.sh work monokai /tmp/local.toml
#
# Safety: refuses to overwrite an existing output file unless --force is passed.
#         refuses to write to the repository's real .dotter/local.toml unless
#         --ci (or CI env var) is set, to prevent test data from overwriting
#         real secrets.

set -e

FORCE=0
CI_MODE=0

usage() {
  cat <<'EOF'
Usage: create-local-toml.sh [--force] [--ci] <profile> [theme] [output-file]

Generates a sample dotter local.toml for CI or temporary validation.
Refuses to overwrite an existing output file unless --force is passed.
Refuses to write to the repository's real .dotter/local.toml unless
--ci (or the CI environment variable) is set.

Examples:
  create-local-toml.sh work monokai /tmp/local.toml
  create-local-toml.sh --ci personal tokyonight .dotter/local.toml
  create-local-toml.sh --force --ci default monokai .dotter/local.toml
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --ci)
      CI_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

PROFILE="${1:-default}"
THEME="${2:-monokai}"
OUTPUT="${3:-.dotter/local.toml}"

# --- safety check: prevent test scripts from overwriting real local.toml ---
REAL_LOCAL=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT=""
if [ -n "$REPO_ROOT" ]; then
  REAL_LOCAL="$REPO_ROOT/.dotter/local.toml"
fi

# Resolve output to absolute path
OUTPUT_DIR=$(cd "$(dirname "$OUTPUT" 2>/dev/null || echo .)" && pwd) || OUTPUT_DIR=""
if [ -n "$OUTPUT_DIR" ]; then
  OUTPUT_ABS="$OUTPUT_DIR/$(basename "$OUTPUT")"
else
  OUTPUT_ABS="$OUTPUT"
fi

if [ -n "$REAL_LOCAL" ] && [ "$OUTPUT_ABS" = "$REAL_LOCAL" ]; then
  # Writing to the real local.toml — only allowed in CI/testing context
  if [ "$CI_MODE" -ne 1 ] && [ -z "${CI:-}" ] && [ -z "${DOTTER_TESTING:-}" ]; then
    echo "SAFETY BLOCKED: refusing to overwrite real .dotter/local.toml with test data." >&2
    echo "" >&2
    echo "Target: $OUTPUT_ABS" >&2
    echo "This script generates sample/test values that will destroy your secrets." >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. Run inside CI (CI env var set)" >&2
    echo "  2. Pass --ci flag explicitly: create-local-toml.sh --ci ..." >&2
    echo "  3. Set DOTTER_TESTING=1" >&2
    echo "  4. Use a temporary output path instead, e.g. /tmp/local.toml" >&2
    exit 2
  fi
fi

if [ -e "$OUTPUT" ] && [ "$FORCE" -ne 1 ]; then
  echo "Refusing to overwrite existing file: $OUTPUT" >&2
  echo "Use a temporary output path, or pass --force only when overwriting is intentional." >&2
  exit 1
fi

# Determine platform
PLATFORM_PKG=""
case "$OSTYPE" in
  linux-gnu*) PLATFORM_PKG="linux" ;;
  darwin*) PLATFORM_PKG="mac" ;;
  *)
    echo "Unknown platform: $OSTYPE"
    exit 1
    ;;
esac

cat > "$OUTPUT" <<EOF
packages = [
  "$PROFILE",
  "$PLATFORM_PKG",
  "$THEME"
]

[variables]
EOF

case "$PROFILE" in
  work)
    cat >> "$OUTPUT" <<'EOF'
name = "Test User"
email = "test@work.example.com"
username = "test.user"
shell_bin_path = "$HOME/bin"
gitlab_personal_access_token = "glpat-test123456789"
gitlab_api_url = "https://gitlab.example.com/api/v4"
gitlab_url = "https://gitlab.example.com"
mcp_atlassian_enabled = true
opencode_build_agent_model = "github-copilot/claude-sonnet-4.5"
opencode_plan_agent_model = "github-copilot/claude-opus-4.5"
node_extra_ca_certs = "/test/path/ca-bundle.crt"
p10k_root_dir = "$HOME/.p10k"
sonarqube_token = "test_sonar_token_123"
EOF
    ;;
  personal)
    cat >> "$OUTPUT" <<'EOF'
name = "Test User"
email = "test@personal.example.com"
github_personal_access_token = "ghp_test123456789"
shell_bin_path = "$HOME/bin"
home_assistant_url = "https://test.hass.example.com"
home_assistant_token = "test_token_123"
playdate_sdk_enabled = true
opencode_build_agent_model = "anthropic/claude-sonnet-4-5"
opencode_plan_agent_model = "anthropic/claude-opus-4-5"
bluesky_app_password = "test_bluesky_password"
bluesky_handle = "test.bsky.social"
plex_user_token = "test_plex_user_token"
plex_server_token = "test_plex_server_token"
plex_url = "https://test.plex.example.com"
tmdb_key = "test_tmdb_key"
youtube_api_key = "test_youtube_api_key"
google_places_api_key = "test_google_places_key"
slack_d_cookie = "test_slack_d_cookie"
slack_token = "xoxp-test-slack-token"
reddit_session = "test_reddit_session"
reddit_token_v2 = "test_reddit_token_v2"
brave_search_api_key = "test_brave_api_key"
proton_user = "test@proton.me"
proton_password = "test_proton_password"
telegram_bot_token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
EOF
    ;;
  default)
    cat >> "$OUTPUT" <<'EOF'
name = "Test User"
email = "test@default.example.com"
github_personal_access_token = "ghp_test123456789"
opencode_build_agent_model = "anthropic/claude-sonnet-4-5"
opencode_plan_agent_model = "anthropic/claude-opus-4-5"
shell_bin_path = "$HOME/bin"
username = "test.user"
gpg_key = ""
EOF
    ;;
esac

echo "Generated $OUTPUT for profile: $PROFILE, theme: $THEME"
