import _shared

# ── Package lists ───────────────────────────────────────────────────────
packages = _shared.PackageList {
    fedora = ["fzf", "fd-find", "ripgrep", "zsh", "tmux", "git", "gh", "jq", "curl", "wget", "snapd", "golang", "cargo", "pinentry", "pinentry-gnome3"]
    brew_taps = ["atlassian/acli", "borkdude/brew", "hashicorp/tap", "browsh-org/browsh", "clojure/tools", "gcenx/wine", "jichu4n/palm-os", "jonathanruiz/tap", "koekeishiya/formulae", "rsteube/tap", "sst/tap", "valkyrie00/bbrew", "zerotier/tap", "vladkens/tap"]
    brew_formulae = ["xz","autoconf","automake","openssl@3","readline","node","aws-cdk","acli","glib","bison","carapace","cmake","coreutils","cryptography","curl","docker","docker-buildx","docker-credential-helper","direnv","dotter","enchant","fastfetch","fd","gnutls","harfbuzz","pango","ffmpeg","fswatch","fzf","isl","gcc","gh","git","git-extras","glab","go","gopls","netpbm","graphviz","mermaid-cli","grep","homeassistant-cli","htop","hunspell","icu4c@76","imagemagick","openjdk","jdtls","jj","openjdk@21","jmeter","jq","libffi","libolm","libyaml","lua","lua-language-server","vscode-langservers-extracted","yaml-language-server","typescript-language-server","cue","starlark-rust","luarocks","make","maven","mosh","neovim","nghttp2","nushell","ollama","pandoc","pinentry-mac","pkl","pkl-lsp","pmd","pnpm","postgresql@14","prettier","protobuf","python-yq","python@3.13","uv","ripgrep","ruby","ruby-install","rust","sesh","sf","sonar-scanner","starship","stylua","termscp","terraform","hashicorp/tap/terraform-ls","tmux","tree-sitter","weechat","wget","xq","yarn","yt-dlp","zlib","zoxide","zsh","zsh-autosuggestions","zsh-completions","borkdude/brew/babashka","browsh-org/browsh/browsh","clojure/tools/clojure","jichu4n/palm-os/pilot-link","vladkens/tap/macmon","jonathanruiz/tap/wakey","rsteube/tap/carapace-spec","sst/tap/opencode","valkyrie00/bbrew/bbrew"]
    brew_casks = ["android-commandlinetools","android-platform-tools","font-hack-nerd-font","geekbench","ghostty","gpg-suite","mitmproxy","quakenotch","salesforce-cli","temurin","zap","zerotier-one"]
}

# ── VSIX-distributed language servers ───────────────────────────────────
# Apex (jorje), Visualforce, and SonarLint ship only inside VS Code
# extension VSIXes. scripts/lsp_vsix_sync.sh fetches these pins from Open
# VSX as plain zip archives — no VS Code involved. Bump versions here.
vsix_lsp_servers: [_shared.VsixLspServer] = [
    _shared.VsixLspServer {
        namespace = "salesforce"
        name = "salesforcedx-vscode-apex"
        version = "66.10.1"
        artifact_check = "dist/apex-jorje-lsp.jar"
    }
    _shared.VsixLspServer {
        namespace = "salesforce"
        name = "salesforcedx-vscode-visualforce"
        version = "66.10.1"
        artifact_check = "dist/visualforceServer.js"
    }
    _shared.VsixLspServer {
        namespace = "SonarSource"
        name = "sonarlint-vscode"
        version = "5.2.1"
        # Assumes Apple-silicon macOS; other platforms need a different
        # target_platform (embedded JRE/analyzers differ).
        target_platform = "darwin-arm64"
        artifact_check = "server/sonarlint-ls.jar"
    }
]

# ── String builders ───────────────────────────────────────────────────
packages_txt = "\n".join(packages.fedora)

_brew_lines = ['tap "' + tap + '"' for tap in packages.brew_taps]
_brew_lines += ['brew "' + formula + '"' for formula in packages.brew_formulae]
_brew_lines += ['cask "' + cask + '"' for cask in packages.brew_casks]

brewfile = "\n".join(_brew_lines)
