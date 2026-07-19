[package]
# Establishes `src/` as a KCL package so `import local` from main.k resolves to
# `src/local.k` (a gitignored, per-machine overrides file), and the KCL
# language server can analyse src/main.k standalone without needing local.k
# passed as a second `kcl run` input.
name = "dotfiles"
edition = "v0.12.3"
version = "0.1.0"