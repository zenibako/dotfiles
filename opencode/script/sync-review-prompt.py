#!/usr/bin/env python3
"""Extract the native /review prompt from the OpenCode binary and sync it into opencode.jsonc."""

import json
import os
import re
import subprocess
import sys

BINARY = os.path.expanduser("~/.opencode/bin/opencode")
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSONC_TEMPLATE = os.path.join(REPO_ROOT, "opencode", "opencode.jsonc")


def extract_native_prompt(binary_path: str) -> str:
    """Pull the review prompt out of the compiled OpenCode binary."""
    # The prompt lives as a JS template literal in the binary. We find the
    # start marker and read until the closing backtick.
    data = open(binary_path, "rb").read()
    start_marker = b";var Us=`"
    start = data.find(start_marker)
    if start == -1:
        raise RuntimeError("Could not locate review prompt start marker in binary.")

    # Advance past the start marker
    pos = start + len(start_marker)
    end = data.find(b"`;var ", pos)
    if end == -1:
        raise RuntimeError("Could not locate review prompt end marker in binary.")

    raw = data[pos:end].decode("utf-8", errors="replace")
    # The binary contains actual newlines inside the template literal.
    return raw


def build_profile_aware_ending() -> str:
    """Append the tool / profile enrichment lines from the existing config."""
    lines = [
        "",
        "---",
        "",
        "## Additional Profile-Specific Tools",
        "",
    ]
    # We preserve the Handlebars conditionals so dotter can inject them.
    lines.append('{{#if opencode_profile_personal}}')
    lines.append("- **CodeRabbit review**: Run `coderabbit review --agent --type all` using bash to gather structured review findings, then incorporate those results.")
    lines.append('{{/if}}')
    lines.append('{{#if opencode_profile_work}}')
    lines.append("- **SonarQube analysis**: Use the SonarQube MCP tools to inspect the relevant project, pull request, issues, and security hotspots when that context is available.")
    lines.append('{{/if}}')
    lines.append("- **Explore agent** - Find how existing code handles similar problems. Check patterns, conventions, and prior art before claiming something doesn't fit.")
    lines.append("- **Exa Code Context** - Verify correct usage of libraries/APIs before flagging something as wrong.")
    lines.append("- **Exa Web Search** - Research best practices if you're unsure about a pattern.")
    lines.append("")
    lines.append("If you're uncertain about something and can't verify it with these tools, say \"I'm not sure about X\" rather than flagging it as a definite issue.")
    return "\n".join(lines)


def integrate_prompts(native: str) -> str:
    """Merge the native review prompt with profile-specific tooling."""
    # The native prompt already ends with the Output section. We append our tooling note.
    return native + "\n" + build_profile_aware_ending()


def update_jsonc_prompt(template_path: str, new_prompt: str) -> str:
    """Replace the code-review prompt inside the dotter Handlebars template."""
    original = open(template_path, "r", encoding="utf-8").read()

    # We must be careful because the prompt is inside a JSON string and the file
    # is also a Handlebars template. We match the exact key and replace the
    # quoted string value that follows it.
    # Our target looks like:
    #     "code-review": {
    #       ...
    #       "prompt": "...existing prompt..."
    #     }

    # Because the existing prompt is a single JSON string on the same line,
    # we can grab the whole "prompt" line and replace it.
    pattern = re.compile(
        r'("prompt"\s*:\s*")([^"]*)("\s*\n\s*\})',
        re.DOTALL,
    )

    # We'll replace only the prompt that belongs to the code-review block.
    # Because there might be other prompt fields, we restrict to the last
    # occurrence inside the agent block.
    match = None
    for m in pattern.finditer(original):
        # crude check: the surrounding context should contain "code-review"
        start_ctx = max(0, m.start() - 300)
        if '"code-review"' in original[start_ctx:m.start()]:
            match = m

    if match is None:
        raise RuntimeError("Could not locate code-review prompt in opencode.jsonc")

    # JSON-escape the new prompt (handles backslashes, quotes, newlines, etc.)
    escaped = json.dumps(new_prompt)[1:-1]  # strip outer quotes from json.dumps

    replacement = match.group(1) + escaped + match.group(3)
    updated = original[: match.start()] + replacement + original[match.end() :]
    return updated


def main() -> int:
    if not os.path.isfile(BINARY):
        print(f"OpenCode binary not found at {BINARY}", file=sys.stderr)
        return 1

    native = extract_native_prompt(BINARY)
    combined = integrate_prompts(native)

    # Also write the standalone canonical copy for reference / diffing
    standalone = os.path.join(REPO_ROOT, "opencode", "prompt", "review-prompt-native.txt")
    with open(standalone, "w", encoding="utf-8") as f:
        f.write(native)
    print(f"Updated canonical native prompt: {standalone}")

    updated = update_jsonc_prompt(JSONC_TEMPLATE, combined)
    with open(JSONC_TEMPLATE, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"Updated code-review agent prompt in: {JSONC_TEMPLATE}")

    # Run dotter deploy so the change is live
    subprocess.run(["dotter", "deploy"], cwd=REPO_ROOT, check=True)
    print("dotter deploy complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
