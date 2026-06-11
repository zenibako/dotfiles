# ── Git config (raw text with Handlebars + shell variables) ───────────
# This is a raw text template because git alias bodies contain shell
# ${var} syntax that KCL would otherwise try to interpolate.

# Single-line shell functions are required because git config files
# do not support multi-line values correctly.

_gitconfig = r"""[user]
    name = {{name}}
    email = {{email}}
{{#if gpg_key}}
    signingkey = {{gpg_key}}
{{/if}}
[init]
    defaultBranch = main
[commit]
    gpgSign = {{#if gpg_key}}true{{else}}false{{/if}}
    template = ~/.git-commit-template
[core]
    hooksPath = ~/.config/git/hooks
[oh-my-zsh]
    git-commit-alias = 061f773dd356df52a8bccd5e73377c012f97ef14

[alias]
    build = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"build${_s:+(${_s})}${_a}:${_m}\"; }; a"
    chore = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"chore${_s:+(${_s})}${_a}:${_m}\"; }; a"
    ci = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"ci${_s:+(${_s})}${_a}:${_m}\"; }; a"
    docs = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"docs${_s:+(${_s})}${_a}:${_m}\"; }; a"
    feat = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"feat${_s:+(${_s})}${_a}:${_m}\"; }; a"
    fix = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"fix${_s:+(${_s})}${_a}:${_m}\"; }; a"
    perf = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"perf${_s:+(${_s})}${_a}:${_m}\"; }; a"
    refactor = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"refactor${_s:+(${_s})}${_a}:${_m}\"; }; a"
    rev = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"revert${_s:+(${_s})}${_a}:${_m}\"; }; a"
    style = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"style${_s:+(${_s})}${_a}:${_m}\"; }; a"
    test = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"test${_s:+(${_s})}${_a}:${_m}\"; }; a"
    wip = "!a() { local _s _a _m; while [ $# -ne 0 ]; do case $1 in -s|--scope) if [ -z \"$2\" ]; then echo \"Missing scope!\"; return 1; fi; _s=\"$2\"; shift 2;; -a|--attention) _a=\"!\"; shift 1;; *) _m=\"${_m} $1\"; shift 1;; esac; done; git commit -m \"wip${_s:+(${_s})}${_a}:${_m}\"; }; a"
"""

gitconfig = _gitconfig