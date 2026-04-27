---
name: validate-dotter
description: |
  Validates dotter configuration by deploying different profiles and themes, then testing Neovim startup and plugin installation. Use when running CI validation locally, before committing dotfile changes, or when troubleshooting deployment issues.
---

# Validate Dotter Configuration

This skill validates your dotfiles configuration by reproducing the GitHub CI workflow locally.

## When to use

- Before committing changes to dotfiles
- When adding new profiles or themes
- After modifying `.dotter/global.toml`
- When troubleshooting Neovim configuration issues

## Prerequisites

- `dotter` installed (will auto-install if missing)
- `nvim` for plugin testing
- `tree-sitter` for parser validation
- `luac` for Lua syntax checking

## Quick Validation

Run the centralized validation script for a complete validation:

```bash
# Validate a specific profile
./scripts/dotter-ci/validate-themes.sh

# Or run individual steps
```

## Validation Steps

### 1. Install Dependencies

```bash
# Install dotter
./scripts/dotter-ci/install-dotter.sh

# Install tree-sitter (for parser testing)
npm install -g tree-sitter-cli
```

### 2. Create Deployment Configuration

Generate `local.toml` for your desired profile and theme:

```bash
./scripts/dotter-ci/create-local-toml.sh <profile> [theme] [output-file]

# Examples:
./scripts/dotter-ci/create-local-toml.sh default monokai /tmp/local.toml
./scripts/dotter-ci/create-local-toml.sh personal tokyonight /tmp/local.toml
./scripts/dotter-ci/create-local-toml.sh work monokai /tmp/local.toml
```

Do not point this script at a real `.dotter/local.toml` unless you intend to replace it. The script refuses to overwrite an existing file unless `--force` is passed explicitly.

### 3. Deploy Configuration

Deploy to a temporary directory (to avoid affecting your actual config):

```bash
DEPLOY_DIR=$(./scripts/dotter-ci/deploy-config.sh <profile> [theme])
echo "$DEPLOY_DIR" > /tmp/dotter_deploy_dir
```

### 4. Install Plugins

Install Neovim plugins in the deployed environment:

```bash
./scripts/dotter-ci/install-nvim-plugins.sh "$DEPLOY_DIR"
```

### 5. Test Neovim Startup

Verify Neovim starts without errors:

```bash
./scripts/dotter-ci/test-nvim-startup.sh "$DEPLOY_DIR"
```

### 6. Test Apex Parser (Optional)

If you need to validate the Apex tree-sitter parser:

```bash
./scripts/dotter-ci/test-apex-parser.sh
```

### 7. Cleanup

Remove temporary files and directories:

```bash
./scripts/dotter-ci/cleanup.sh "$DEPLOY_DIR"
```

## Profile-Specific Variables

### Default Profile
- `email`
- `github_personal_access_token`

### Personal Profile
- All default variables
- `home_assistant_url`
- `home_assistant_token`
- `bluesky_app_password`
- `bluesky_handle`

### Work Profile
- All default variables
- `gitlab_personal_access_token`
- `gitlab_api_url`
- `apex_lsp_jar_path`
- `sonarqube_token`

## Common Issues

### Missing Variables
If dotter complains about missing variables, check `.dotter/local.toml` has all required variables for your profile.

### Neovim Plugin Timeouts
If plugin installation times out, you may need to increase the timeout or check your internet connection.

### Tree-sitter Parser Failures
The Apex parser requires a specific revision. Check the parser registry for the correct commit hash.

## Available Scripts

All scripts are in `scripts/dotter-ci/`:

| Script | Purpose |
|--------|---------|
| `install-dotter.sh` | Install dotter binary |
| `create-local-toml.sh` | Generate local.toml for a profile |
| `deploy-config.sh` | Deploy config to temp directory |
| `install-nvim-plugins.sh` | Install Neovim plugins |
| `test-nvim-startup.sh` | Test Neovim starts cleanly |
| `test-apex-parser.sh` | Compile Apex tree-sitter parser |
| `validate-toml.sh` | Validate TOML syntax |
| `validate-lua.sh` | Validate Lua syntax |
| `validate-themes.sh` | Validate all themes |
| `cleanup.sh` | Remove temporary files |
