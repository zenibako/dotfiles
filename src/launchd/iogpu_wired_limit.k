# ── iogpu.wired_limit_mb launchd daemon ──────────────────────────────
#
# Raises the Apple Silicon cap on how much unified memory may be *wired*
# (locked resident, non-pageable) for GPU use. Metal reports the resulting
# budget as `recommendedMaxWorkingSetSize`, which is what MLX runtimes such as
# LM Studio read to decide how much model + KV cache they can hold. macOS's
# default is ~75% of physical RAM and there is no supported UI or API for it —
# a sysctl is the only lever, and it resets on every boot. Hence a daemon.
#
# Why this machine has one (24 GiB, 2026-07-22): the Qwen 3.6 27B 4-bit weights
# are 14.95 GiB against a default ceiling of 14.76 GiB — short by ~1%. LM Studio
# fitted 0 tokens of KV cache, clamped to its 4,096 floor, and then kept using
# the *configured* 32,768, so every prompt past ~4k failed with "the number of
# tokens to keep from the initial prompt is greater than the context length" or
# crashed the model outright. At 20480 the ceiling becomes 17.00 GiB and 11,776
# tokens fit. Keep this consistent with the model `limit` values in
# src/opencode/config.k — a wired limit and a limit.context that disagree
# reproduce exactly that failure.
#
# SAFETY: overshooting starves the kernel and panics the machine rather than
# merely slowing it down. scripts/post_deploy.sh refuses any value that leaves
# macOS less than 4 GiB and will not apply it.

label = "tech.chanderson.iogpu-wired-limit"

# Emit the plist only when a machine actually opts in (non-zero). Machines
# leaving the default render an empty file and post_deploy skips the step.
render = lambda limit_mb: int -> str {
    "" if limit_mb <= 0 else """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/sbin/sysctl</string>
        <string>-w</string>
        <string>iogpu.wired_limit_mb=${limit_mb}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/var/log/${label}.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/${label}.log</string>
</dict>
</plist>
"""
}
