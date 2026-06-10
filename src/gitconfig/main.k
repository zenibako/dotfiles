# ── Git config (raw text with Handlebars + shell variables) ───────────
# This is a raw text template because git alias bodies contain shell
# ${var} syntax that KCL would otherwise try to interpolate.

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
	build = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"build${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	chore = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"chore${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	ci = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"ci${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	docs = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"docs${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	feat = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"feat${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	fix = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"fix${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	perf = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"perf${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	refactor = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"refactor${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	rev = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"revert${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	style = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"style${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	test = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"test${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
	wip = "!a() {
local _scope _attention _message
while [ $# -ne 0 ]; do
case $1 in
  -s | --scope )
    if [ -z \"$2\" ]; then
      echo \"Missing scope!\"
      return 1
    fi
    _scope=\"$2\"
    shift 2
    ;;
  -a | --attention )
    _attention=\"!\"
    shift 1
    ;;
  * )
    _message=\"${_message} $1\"
    shift 1
    ;;
esac
done
git commit -m \"wip${_scope:+(${_scope})}${_attention}:${_message}\"
}; a"
"""

gitconfig = _gitconfig
