#!/usr/bin/env python3
"""Fake OpenAI-compatible endpoint that captures what OpenCode sends.

Measures each OpenCode agent's real context footprint without needing a model:
listens on 127.0.0.1:1234 (the configured LM Studio baseURL) and logs, per
/v1/chat/completions request: tool count, tools-JSON bytes, system prompt
chars, total request bytes, and a rough token estimate (bytes/4).

Usage (findings recorded in the Backlog doc "OpenCode agent context measurements"):

    python3 scripts/measure_opencode_context.py &          # occupy the LM Studio port
    opencode run -m lmstudio/qwen3.5-9b --agent local "Say ok"      # primary agent
    opencode run -m lmstudio/qwen3.5-9b --agent local "INVOKE:local-dev"  # subagent
    cat /tmp/opencode-capture.jsonl                        # one JSON row per request

If the conversation's first user message contains "INVOKE:<agent>" and the
request offers a `task` tool and no tool call has happened yet, it responds
with a task tool-call targeting that agent — so OpenCode spawns the real
subagent session, whose own request is then captured with its scoped toolset
(`opencode run --agent <subagent>` silently falls back to build, so subagents
MUST be measured via a task invocation). Otherwise it replies "ok" so sessions
finish cleanly. Caveat: a task-spawned subagent runs on its own configured
model — only agents whose model points at the lmstudio provider are captured.
"""
import json
import os
import re
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = os.environ.get("CAPTURE_LOG", "/tmp/opencode-capture.jsonl")

# Distinctive first-line markers from the deployed agent prompt files
AGENT_MARKERS = {
    "Local PM Subagent": "local-pm",
    "Local Dev Subagent": "local-dev",
    "Tester Subagent": "tester",
    "Reviewer Agent Responsibilities": "reviewer",
    "Local Orchestrator Agent": "local",
}


def sse(self, payloads):
    self.send_response(200)
    self.send_header("Content-Type", "text/event-stream")
    self.end_headers()
    for p in payloads:
        self.wfile.write(f"data: {json.dumps(p)}\n\n".encode())
    self.wfile.write(b"data: [DONE]\n\n")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        body = json.dumps({"object": "list", "data": [{"id": "qwen3.5-9b", "object": "model"}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(n)
        try:
            req = json.loads(raw)
        except Exception:
            req = {}
        tools = req.get("tools") or []
        msgs = req.get("messages") or []

        def text_of(m):
            c = m.get("content")
            return c if isinstance(c, str) else json.dumps(c or "")

        system_text = "\n".join(text_of(m) for m in msgs if m.get("role") == "system")
        user_texts = [text_of(m) for m in msgs if m.get("role") == "user"]
        agent_label = next((v for k, v in AGENT_MARKERS.items() if k in system_text), "?")
        tool_names = sorted(t.get("function", {}).get("name", "?") for t in tools)
        # Per-tool schema bytes. Tool schemas dominate a scoped agent's request,
        # but they are wildly uneven — a single MCP write tool can cost 20x a
        # builtin — so trimming a roster to fit a context window needs the
        # breakdown, not just the total.
        tool_bytes = {t.get("function", {}).get("name", "?"): len(json.dumps(t)) for t in tools}

        entry = {
            "ts": time.strftime("%H:%M:%S"),
            "agent": agent_label,
            "n_tools": len(tools),
            "tools_bytes": len(json.dumps(tools)),
            "system_chars": len(system_text),
            "request_bytes": len(raw),
            "est_prompt_tokens": len(raw) // 4,
            "tool_names": tool_names,
            "tool_bytes": tool_bytes,
        }
        with open(LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")

        invoke = None
        m = re.search(r"INVOKE:([\w-]+)", user_texts[0] if user_texts else "")
        if m:
            invoke = m.group(1)
        already_called = any(m.get("role") == "tool" or m.get("tool_calls") for m in msgs)
        base = {"id": "cap", "object": "chat.completion.chunk", "created": 0, "model": "qwen3.5-9b"}

        if invoke and "task" in tool_names and not already_called:
            args = json.dumps({"description": "measure subagent", "prompt": "Say ok", "subagent_type": invoke})
            sse(self, [
                {**base, "choices": [{"index": 0, "delta": {"role": "assistant", "tool_calls": [
                    {"index": 0, "id": "call_cap_1", "type": "function",
                     "function": {"name": "task", "arguments": args}}]}, "finish_reason": None}]},
                {**base, "choices": [{"index": 0, "delta": {}, "finish_reason": "tool_calls"}]},
            ])
        else:
            sse(self, [
                {**base, "choices": [{"index": 0, "delta": {"role": "assistant", "content": "ok"}, "finish_reason": None}]},
                {**base, "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
                 "usage": {"prompt_tokens": len(raw) // 4, "completion_tokens": 1, "total_tokens": len(raw) // 4 + 1}},
            ])


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 1234), Handler).serve_forever()
