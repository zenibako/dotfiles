#!/usr/bin/env python3
"""Validate a TOML file. Exits 0 on success, 1 on parse error, 2 if no TOML module available."""
import sys

path = sys.argv[1]
try:
    import tomllib
    with open(path, 'rb') as f:
        tomllib.load(f)
except ImportError:
    try:
        import toml
        with open(path) as f:
            toml.load(f)
    except ImportError:
        sys.exit(2)
