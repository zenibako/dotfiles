import _shared

# ── Aerospace config (macOS specific) ──────────────────────────────────
_gap = 10

aerospace = _shared.AerospaceConfig {
    "config-version" = 2
    "after-startup-command" = []
    "start-at-login" = True
    "enable-normalization-flatten-containers" = True
    "enable-normalization-opposite-orientation-for-nested-containers" = True
    "accordion-padding" = 30
    "default-root-container-layout" = "tiles"
    "default-root-container-orientation" = "auto"
    "on-focused-monitor-changed" = ["move-mouse monitor-lazy-center"]
    "automatically-unhide-macos-hidden-apps" = True
    "persistent-workspaces" = ["1", "2", "3", "4", "5", "6"]
    "on-mode-changed" = []
    "key-mapping" = {
        preset = "qwerty"
    }
    gaps = {
        inner = {
            horizontal = _gap
            vertical = _gap
        }
        outer = {
            left = _gap
            bottom = _gap
            top = 0
            right = _gap
        }
    }
    "on-window-detected" = [
        { "if" = { "app-id" = "com.google.Chrome", "during-aerospace-startup" = True }, run = "move-node-to-workspace 1" }
        { "if" = { "app-id" = "app.zen-browser.zen", "during-aerospace-startup" = True }, run = "move-node-to-workspace 1" }
        { "if" = { "app-id" = "com.mitchellh.ghostty", "during-aerospace-startup" = True }, run = "move-node-to-workspace 1" }
        { "if" = { "app-id" = "com.tinyspeck.slackmacgap", "during-aerospace-startup" = True }, run = "move-node-to-workspace 2" }
        { "if" = { "app-id" = "com.hnc.Discord" }, run = "move-node-to-workspace 2" }
        { "if" = { "app-id" = "com.google.Chrome.app.fmgjjmmmlfnkbppncabfkddbjimcfncm" }, run = "move-node-to-workspace 2" }
        { "if" = { "app-id" = "com.automattic.beeper.desktop" }, run = "move-node-to-workspace 2" }
        { "if" = { "app-id" = "com.apple.iCal" }, run = "move-node-to-workspace 3" }
        { "if" = { "app-id" = "com.apple.finder" }, run = "move-node-to-workspace 3" }
        { "if" = { "app-id" = "io.robbie.HomeAssistant" }, run = "move-node-to-workspace 3" }
        { "if" = { "app-id" = "com.apple.Photos" }, run = "move-node-to-workspace 3" }
        { "if" = { "app-id" = "net.kovidgoyal.calibre" }, run = "move-node-to-workspace 3" }
        { "if" = { "app-id" = "com.valvesoftware.steam" }, run = "move-node-to-workspace 4" }
        { "if" = { "app-id" = "com.valvesoftware.steam.helper" }, run = "move-node-to-workspace 4" }
        { "if" = { "app-id" = "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan" }, run = "move-node-to-workspace 4" }
        { "if" = { "app-id" = "org.videolan.vlc" }, run = "move-node-to-workspace 4" }
    ]
    mode = {
        main = {
            binding = {
                "alt-slash" = "layout tiles horizontal vertical"
                "alt-comma" = "layout accordion horizontal vertical"
                # alt + hjkl shifts focus
                "alt-h" = "focus left"
                "alt-j" = "focus down"
                "alt-k" = "focus up"
                "alt-l" = "focus right"
                # alt + shift + hjkl moves the focused window
                "alt-shift-h" = "move left"
                "alt-shift-j" = "move down"
                "alt-shift-k" = "move up"
                "alt-shift-l" = "move right"
                "alt-minus" = "resize smart -50"
                "alt-equal" = "resize smart +50"
                "alt-1" = "workspace 1"
                "alt-2" = "workspace 2"
                "alt-3" = "workspace 3"
                "alt-4" = "workspace 4"
                "alt-5" = "workspace 5"
                "alt-6" = "workspace 6"
                "alt-7" = "workspace 7"
                "alt-8" = "workspace 8"
                "alt-9" = "workspace 9"
                "alt-q" = "workspace 1"
                "alt-w" = "workspace 2"
                "alt-e" = "workspace 3"
                "alt-r" = "workspace 4"
                "alt-t" = "workspace 5"
                "alt-y" = "workspace 6"
                "alt-shift-1" = "move-node-to-workspace 1"
                "alt-shift-2" = "move-node-to-workspace 2"
                "alt-shift-3" = "move-node-to-workspace 3"
                "alt-shift-4" = "move-node-to-workspace 4"
                "alt-shift-5" = "move-node-to-workspace 5"
                "alt-shift-6" = "move-node-to-workspace 6"
                "alt-shift-7" = "move-node-to-workspace 7"
                "alt-shift-8" = "move-node-to-workspace 8"
                "alt-shift-9" = "move-node-to-workspace 9"
                "alt-shift-q" = "move-node-to-workspace 1"
                "alt-shift-w" = "move-node-to-workspace 2"
                "alt-shift-e" = "move-node-to-workspace 3"
                "alt-shift-r" = "move-node-to-workspace 4"
                "alt-shift-t" = "move-node-to-workspace 5"
                "alt-shift-y" = "move-node-to-workspace 6"
                "alt-tab" = "workspace-back-and-forth"
                "alt-shift-tab" = "move-workspace-to-monitor --wrap-around next"
                "alt-shift-semicolon" = "mode service"
                "alt-shift-p" = "mode passthrough"
            }
        }
        service = {
            binding = {
                esc = ["reload-config", "mode main"]
                r = ["flatten-workspace-tree", "mode main"]
                f = ["layout floating tiling", "mode main"]
                backspace = ["close-all-windows-but-current", "mode main"]
                "alt-shift-h" = ["join-with left", "mode main"]
                "alt-shift-j" = ["join-with down", "mode main"]
                "alt-shift-k" = ["join-with up", "mode main"]
                "alt-shift-l" = ["join-with right", "mode main"]
            }
        }
        passthrough = {
            binding = {
                "alt-shift-p" = "mode main"
            }
        }
    }
    "workspace-to-monitor-force-assignment" = {
        "1" = "main"
        "2" = "main"
        "3" = "main"
        "4" = "main"
        "5" = "main"
        "6" = "secondary"
    }
}
