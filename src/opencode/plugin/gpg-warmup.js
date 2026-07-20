// Warms the GPG agent cache before jj/git operations that sign commits, so
// signing works non-interactively in agent sessions. jj is configured with
// signing.behavior = "own" (src/jj.k), which signs on commit AND re-signs on
// rewrites (describe/squash/rebase) — with a cold gpg-agent each of those
// blocks on pinentry, the command hangs or fails, and small local models loop
// retrying the same jj command (observed with qwen3.5-9b, 2026-07-20).
//
// Auto-discovered from ~/.config/opencode/plugin/ (symlinked by dotter).
const VCS_CMD = /\b(jj|git)\b/
const WRITE_OP = /\b(commit|describe|squash|split|rebase|amend|push|new)\b/
const TTL_MS = 10 * 60 * 1000 // re-preset at most every 10 minutes

export const GpgWarmup = async ({ $ }) => {
  let last = 0
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const cmd = String(output?.args?.command ?? "")
      if (!VCS_CMD.test(cmd) || !WRITE_OP.test(cmd)) return
      const now = Date.now()
      if (now - last < TTL_MS) return
      last = now
      // No-op on machines without the helper; never block the tool call.
      await $`sh -c "command -v gpg-preset-from-keychain >/dev/null 2>&1 && gpg-preset-from-keychain || true"`
        .quiet()
        .nothrow()
    },
  }
}
