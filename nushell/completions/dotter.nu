# Dotter completions for Nushell
# Dotter has no dynamic completion API, so we use static export extern definitions.
# See: dotter --help for the canonical command tree.

# Dotter global flags (present on all subcommands)
export extern "dotter" [
    --global-config(-g): path     # Location of the global configuration [default: .dotter/global.toml]
    --local-config(-l): path     # Location of the local configuration [default: .dotter/local.toml]
    --cache-file: path           # Location of cache file [default: .dotter/cache.toml]
    --cache-directory: path     # Directory to cache into [default: .dotter/cache]
    --pre-deploy: path          # Location of optional pre-deploy hook [default: .dotter/pre_deploy.sh]
    --post-deploy: path         # Location of optional post-deploy hook [default: .dotter/post_deploy.sh]
    --pre-undeploy: path        # Location of optional pre-undeploy hook [default: .dotter/pre_undeploy.sh]
    --post-undeploy: path       # Location of optional post-undeploy hook [default: .dotter/post_undeploy.sh]
    --diff-context-lines: int   # Amount of lines printed before/after a diff hunk [default: 3]
    --dry-run(-d)              # Dry run - don't do anything, only print information
    --verbose(-v)              # Verbosity level (repeat up to 3 times)
    --quiet(-q)                # Quiet - only print errors
    --force(-f)                # Force - overwrite target files if content is unexpected
    --noconfirm(-y)            # Assume "yes" instead of prompting
    --patch(-p)                # Take stdin as additional files/variables patch
    --help(-h)                 # Print help
    --version(-V)              # Print version
    command?: string           # Subcommand to run
]

export extern "dotter deploy" [
    --global-config(-g): path
    --local-config(-l): path
    --dry-run(-d)
    --verbose(-v)
    --quiet(-q)
    --force(-f)
    --noconfirm(-y)
    --patch(-p)
    --help(-h)
]

export extern "dotter undeploy" [
    --global-config(-g): path
    --local-config(-l): path
    --dry-run(-d)
    --verbose(-v)
    --quiet(-q)
    --force(-f)
    --noconfirm(-y)
    --patch(-p)
    --help(-h)
]

export extern "dotter init" [
    --global-config(-g): path
    --local-config(-l): path
    --dry-run(-d)
    --verbose(-v)
    --quiet(-q)
    --force(-f)
    --noconfirm(-y)
    --patch(-p)
    --help(-h)
]

export extern "dotter watch" [
    --global-config(-g): path
    --local-config(-l): path
    --dry-run(-d)
    --verbose(-v)
    --quiet(-q)
    --force(-f)
    --noconfirm(-y)
    --patch(-p)
    --help(-h)
]

export extern "dotter gen-completions" [
    --global-config(-g): path
    --local-config(-l): path
    --shell(-s): string        # Shell: bash, elvish, fish, powershell, zsh
    --to: path                 # Out directory for writing completions file
    --help(-h)
]
