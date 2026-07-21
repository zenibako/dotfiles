# AeroSpace configuration

Tiling window manager config for macOS, generated from KCL.

## Files & flow

| File | Role |
|---|---|
| `main.k` | Config source (KCL) → rendered to `out/aerospace.toml` → symlinked to `~/.aerospace.toml` |
| `display-profile.sh` | Per-monitor layout script → symlinked to `~/.local/bin/aerospace-display-profile` |
| `out/aerospace-display-profile.conf` | Monitor→layout policy, generated from `main.k` → `~/.config/aerospace/display-profile.conf` |

`main.k` is declarative: the `_workspaces` table (purpose, monitor, app routing
with human-readable names) is the single source of truth, and
`on-window-detected`, `workspace-to-monitor-force-assignment`,
`persistent-workspaces`, and the workspace keybindings are derived from it via
comprehensions. To route a new app, add one `AppRule` line to the table.

After editing, run `./deploy.sh` then `aerospace reload-config`.

## Display profiles (per-monitor layouts)

AeroSpace has no display-connected event and no config profiles, so
`display-profile.sh` bridges the gap: it fingerprints the connected monitor
set and applies a root layout to every workspace on each monitor.

| Monitor | Root layout |
|---|---|
| Built-in laptop display | `h_accordion` (stacking — small screen) |
| Any external monitor | `h_tiles` (side-by-side tiling) |

Triggered from `after-startup-command` (`--force`), `on-focused-monitor-changed`,
and `exec-on-workspace-change`. It no-ops until the monitor set changes
(fingerprint cached in `~/.cache/aerospace/`), so manual layout tweaks
(`alt-slash` / `alt-comma`) survive workspace switches — they reset only when
a display is plugged or unplugged. Policy is declared in `main.k`
(`_builtin_layout` / `_external_layout`) and rendered to
`~/.config/aerospace/display-profile.conf`; the script carries matching
defaults for when the conf hasn't been deployed. Which monitors count as
"built-in" is the `layout_for_monitor()` pattern match in the script.

## Workspace map

Source of truth: the `_workspaces` table in `main.k` (this table is a
snapshot). Workspaces 1–5 pin to the `main` monitor, 6 to `secondary` (falls
back to main when undocked). Marked `startup-only` = rule applies only while
AeroSpace launches; later windows open wherever you are. Marked `personal` =
app not installed on the work machine; the rule is inert there.

| WS | Purpose (inferred) | Assigned apps |
|---|---|---|
| 1 | Browser + terminal | Chrome (startup-only), Zen (startup-only, personal), Ghostty (startup-only) |
| 2 | Comms | Slack (startup-only), Discord (personal), Gmail PWA, Beeper (personal) |
| 3 | Organization | Apple Calendar, Finder, Home Assistant native app (personal), Photos, calibre (personal) |
| 4 | Media & calls | Steam + helper (personal), Google Meet PWA, VLC |
| 5 | — free | none |
| 6 | Secondary-monitor dashboard | none (used manually today) |

Chrome PWA bundle IDs decoded (`com.google.Chrome.app.<id>`):

| ID | App |
|---|---|
| `fmgjjmmmlfnkbppncabfkddbjimcfncm` | Gmail |
| `kjgfgldnnfoeklkmfkjfagphfepbbdan` | Google Meet |

To discover a PWA's ID: `defaults read ~/Applications/Chrome\ Apps.localized/<App>.app/Contents/Info CFBundleIdentifier`
or `aerospace list-windows --all --format '%{app-bundle-id} %{app-name}'`.

## Audit findings & suggestions (2026-07-21, work MBA)

Rules for apps that aren't installed are harmless — they simply never match —
so personal-machine rules can stay. The actionable gaps:

1. **Google Calendar PWA is unassigned.** The running Calendar PWA is
   `com.google.Chrome.app.kjbdgfilnfhdoflbpgamdcdgpehopbep`, which matches no
   rule. The `com.apple.iCal → 3` rule suggests calendars belong on 3 — add
   the PWA ID alongside it.
2. **cmux (the daily terminal) has no rule.** Ghostty is routed to 1, but
   cmux windows currently sit scattered on 2 and 3. Suggest
   `com.cmuxterm.app → 1` with `during-aerospace-startup = True`, mirroring
   Ghostty.
3. **Nothing routes to workspace 6** (the secondary-monitor workspace) — it's
   populated by hand today (a Jira sprint-board Chrome window). A **Jira
   Board PWA** exists (`fobmnckfepnjpmphjaclblfocgpddlfl`); assigning it to 6
   would rebuild the dashboard monitor automatically at startup.
4. **Home Assistant rule targets the native app** (`io.robbie.HomeAssistant`),
   which isn't installed on the work machine — but an HA PWA is
   (`olcjdeiehffeemcpimpehlefpeofdanf`). Add the PWA ID next to the native
   rule if HA belongs on 3 here too.
5. **Google Meet lives on 4 while every other comms app lives on 2.** If
   intentional, 4 reads as "media & calls" (zoom.us — installed, unassigned —
   would then also belong on 4). If not, move Meet to 2.
6. **Finder → 3 moves every Finder window**, including copy-progress dialogs
   and Get Info panels, which can yank them to another workspace mid-drag.
   Alternative: drop the workspace rule and use `run = "layout floating"`.
7. **Workspace 5 is a free slot** — no apps, no purpose yet. Candidates from
   installed-but-unassigned apps: VS Code, Claude Desktop, Postman, Safari,
   GitLab PWA, YouTube / YouTube Music PWAs.
8. `persistent-workspaces` covers 1–6 while keybindings reach 7–9; 7–9 act as
   ad-hoc scratch spaces that vanish when emptied. Intentional, just noted.

## Keybindings quick reference

| Binding | Action |
|---|---|
| `alt-hjkl` / `alt-shift-hjkl` | Focus / move window |
| `alt-1..9`, `alt-qwerty` | Switch workspace (q–y mirror 1–6) |
| `alt-shift-1..9` / `alt-shift-qwerty` | Move window to workspace |
| `alt-slash` / `alt-comma` | Tiles / accordion layout |
| `alt-minus` / `alt-equal` | Resize −50 / +50 |
| `alt-tab` | Previous workspace |
| `alt-shift-tab` | Move workspace to next monitor |
| `alt-shift-;` | Service mode (esc reload · r flatten · f float · backspace close others · alt-shift-hjkl join) |
| `alt-shift-p` | Passthrough mode (toggle) |
