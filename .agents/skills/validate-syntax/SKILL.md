---
name: validate-syntax
description: |
  Validates configuration file syntax including TOML and Lua files. Checks for duplicate variables and ensures all configs parse correctly. Use before committing changes to config files or when troubleshooting syntax errors.
---

# Validate Configuration Syntax

This skill validates the syntax of all configuration files in the dotfiles repository.

## When to use

- Before committing config changes
- When adding new TOML files
- After editing `.dotter/global.toml`
- When troubleshooting parse errors

## Quick Validation

Run the centralized validation scripts:

```bash
# Validate TOML files
./scripts/dotter-ci/validate-toml.sh

# Validate Lua files (after deployment)
./scripts/dotter-ci/validate-lua.sh [deploy-dir]
```

## Validation Steps

### 1. Validate TOML Files

Check that all TOML files parse correctly:

```bash
./scripts/dotter-ci/validate-toml.sh [file1] [file2] ...

# Validate default files
./scripts/dotter-ci/validate-toml.sh

# Validate specific files
./scripts/dotter-ci/validate-toml.sh .dotter/global.toml jj/config.toml
```

This validates:
- `.dotter/global.toml` - Main dotter configuration
- `atuin/config.toml` - Atuin shell history config
- `iamb/config.toml` - Iamb Matrix client config
- `jj/config.toml` - Jujutsu version control config

### 2. Install dotter

```bash
./scripts/dotter-ci/install-dotter.sh
```

### 3. Test Dotter Dry Run

Run dotter in dry-run mode for each profile to catch variable conflicts:

```bash
for profile in default personal work; do
  echo "Testing $profile profile..."
  ./scripts/dotter-ci/create-local-toml.sh "$profile" monokai .dotter/local.toml

  if ! dotter deploy --dry-run --force 2>&1 | tee /tmp/dotter-$profile.log; then
    echo "✗ Failed to deploy $profile profile"
    exit 1
  fi
  echo "✓ $profile profile deploys successfully"
done
```

### 4. Deploy and Validate Lua

Deploy configs and validate Lua syntax:

```bash
# Deploy
./scripts/dotter-ci/create-local-toml.sh default monokai .dotter/local.toml
dotter deploy --force --verbose

# Validate Lua
./scripts/dotter-ci/validate-lua.sh "$HOME/.config/nvim"
```

## Common Issues

### Duplicate Variables
If dotter reports duplicate variables, check that profiles don't define the same variables. Use `depends` inheritance properly.

### Malformed TOML
Common TOML errors include:
- Missing quotes around string values
- Trailing commas in arrays
- Incorrect table syntax (`[table]` vs `[[array-of-tables]]`)

### Lua Syntax Errors
After dotter processes templates, check for:
- Unclosed brackets or parentheses
- Missing `end` statements
- Invalid escape sequences

## Available Scripts

All scripts are in `scripts/dotter-ci/`:

| Script | Purpose |
|--------|---------|
| `validate-toml.sh` | Validate TOML file syntax |
| `validate-lua.sh` | Validate Lua file syntax |
| `install-dotter.sh` | Install dotter binary |
| `create-local-toml.sh` | Generate local.toml |
