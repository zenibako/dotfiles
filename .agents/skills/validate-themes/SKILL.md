---
name: validate-themes
description: |
  Validates theme configurations by deploying with different themes (nightowl, tokyonight, monokai). Ensures all themes work correctly with dotter. Use when adding or modifying themes, or when theme-specific issues arise.
---

# Validate Themes

This skill validates that all themes (monokai, nightowl, tokyonight) deploy correctly.

## When to use

- When adding a new theme
- After modifying theme files
- When testing theme-specific configurations
- Before committing theme changes

## Quick Validation

Run the centralized theme validation script:

```bash
# Validate all default themes
./scripts/dotter-ci/validate-themes.sh

# Validate specific themes
./scripts/dotter-ci/validate-themes.sh nightowl tokyonight
```

## Supported Themes

- `monokai` - Default theme
- `nightowl` - Dark theme with high contrast
- `tokyonight` - Tokyo Night theme variant

## Validation Steps

### 1. Install dotter

```bash
./scripts/dotter-ci/install-dotter.sh
```

### 2. Test Each Theme

Deploy each theme and verify success:

```bash
./scripts/dotter-ci/validate-themes.sh

# Or test specific themes
./scripts/dotter-ci/validate-themes.sh nightowl monokai
```

This will:
1. Create a temporary deployment directory
2. Generate `local.toml` with the theme
3. Run `dotter deploy --force --verbose`
4. Report success or failure
5. Clean up temporary files

### 3. Manual Theme Testing

To manually test a theme:

```bash
# Create deployment directory
DEPLOY_DIR=$(mktemp -d)

# Create local.toml with theme
./scripts/dotter-ci/create-local-toml.sh default <theme> .dotter/local.toml

# Deploy
HOME="$DEPLOY_DIR" dotter deploy --force --verbose

# Verify files
echo "Deployed files:"
find "$DEPLOY_DIR" -type f | head -20

# Cleanup
rm -rf "$DEPLOY_DIR"
```

## Theme-Specific Variables

Some themes may define specific variables. Check the theme's TOML files in `.dotter/themes/`.

## Troubleshooting

### Theme Not Found
If a theme isn't found, check:
1. The theme package is defined in `.dotter/global.toml`
2. The theme files exist in the repository
3. The theme name is spelled correctly

### Variable Conflicts
Themes should not define conflicting variables. Use the default profile's variables as base.

## Available Scripts

All scripts are in `scripts/dotter-ci/`:

| Script | Purpose |
|--------|---------|
| `validate-themes.sh` | Validate all or specific themes |
| `install-dotter.sh` | Install dotter binary |
| `create-local-toml.sh` | Generate local.toml with theme |
