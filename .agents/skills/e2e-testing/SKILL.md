---
name: e2e-testing
description: |
  End-to-end (E2E) browser testing and automation. Unified workflow across three backends:
  cmux (preferred interactive automation), Playwright (test script execution), and
  Chrome DevTools (debugging and manual browser control). Use when automating browser
  interactions, running E2E tests, verifying web UI behavior, or diagnosing frontend issues.
---

# E2E Testing Skill

This skill provides a **unified, tool-agnostic workflow** for end-to-end browser testing.
The same high-level steps apply regardless of backend. Choose the appropriate backend
based on availability and context.

## Backend Selection (choose one)

| Priority | Backend | When to use |
|----------|---------|-------------|
| 1 | **cmux** | Installed (`command -v cmux`). Interactive browser automation with native wait/snapshot support. |
| 2 | **Playwright** | E2E test scripts exist in the repo (e.g., `e2e/`, `tests/e2e/`, `playwright.config.*`). |
| 3 | **Chrome DevTools** | Fallback when neither cmux nor Playwright scripts are available. Direct CDP-based debugging. |

### How to choose

```bash
# Check if cmux is available
if command -v cmux &> /dev/null; then
  echo "→ Use cmux backend"
  exit 0
fi

# Check for Playwright tests
if ls e2e/**/*.spec.* playwright.config.* tests/e2e 2>/dev/null | grep -q .; then
  echo "→ Use Playwright backend"
  exit 0
fi

# Fallback
echo "→ Use Chrome DevTools backend"
```

---

## Unified Testing Workflow

All backends follow the same loop:

1. **Navigate** – open the target URL or page.
2. **Verify** – confirm the correct page loaded (URL, title, DOM ready).
3. **Inspect** – capture the current state (snapshot / screenshot / DOM tree).
4. **Act** – perform an interaction (click, fill, press, select).
5. **Wait** – allow the page to settle (for navigation, network, or DOM changes).
6. **Re-inspect** – capture the new state and assert expectations.
7. **Repeat** until acceptance criteria are met.

> **Rule of thumb**: Always verify before you act. Never act on stale state.

---

## Backend 1: cmux (Interactive Automation)

### When to use
- You need quick, ad-hoc browser automation.
- The page is complex (shadow DOM, iframes) and `cmux` handles them natively.
- You want built-in wait strategies (`--load-state`, `--selector`, `--text`).

### Quick Start

```bash
# 1. Open a browser surface
cmux --json browser open https://example.com
# → returns surface ref, e.g. surface:7

# 2. Verify navigation
cmux browser surface:7 get url
cmux browser surface:7 wait --load-state complete --timeout-ms 15000

# 3. Inspect (get interactive element refs)
cmux browser surface:7 snapshot --interactive

# 4. Act using refs
cmux browser surface:7 fill e1 "hello world"
cmux --json browser surface:7 click e2 --snapshot-after

# 5. Re-inspect after action
cmux browser surface:7 snapshot --interactive
```

### Common Commands Reference

| Action | cmux Command |
|--------|--------------|
| Open URL | `cmux --json browser open <url>` |
| Get URL | `cmux browser <surface> get url` |
| Get title | `cmux browser <surface> get title` |
| Snapshot | `cmux browser <surface> snapshot --interactive` |
| Compact snapshot | `cmux browser <surface> snapshot --interactive --compact --max-depth 3` |
| Click | `cmux browser <surface> click <ref>` |
| Double-click | `cmux browser <surface> dblclick <ref>` |
| Fill input | `cmux browser <surface> fill <ref> "text"` |
| Type text | `cmux browser <surface> type <ref> "text"` |
| Press key | `cmux browser <surface> press Enter` |
| Select option | `cmux browser <surface> select <ref> "value"` |
| Check/Uncheck | `cmux browser <surface> check <ref>` / `uncheck <ref>` |
| Scroll | `cmux browser <surface> scroll --dy 400` |
| Get text | `cmux browser <surface> get text <ref-or-selector>` |
| Get value | `cmux browser <surface> get value <ref-or-selector>` |
| Screenshot | `cmux browser <surface> screenshot` |
| Save state | `cmux browser <surface> state save <path>` |
| Restore state | `cmux browser <surface> state load <path>` |
| Wait for load | `cmux browser <surface> wait --load-state complete --timeout-ms 15000` |
| Wait for selector | `cmux browser <surface> wait --selector "#ready" --timeout-ms 10000` |
| Wait for text | `cmux browser <surface> wait --text "Success" --timeout-ms 10000` |
| Wait for URL | `cmux browser <surface> wait --url-contains "/dashboard" --timeout-ms 10000` |
| Wait for function | `cmux browser <surface> wait --function "document.readyState === 'complete'" --timeout-ms 10000` |
| Evaluate JS | `cmux browser <surface> eval '<js>'` |
| Console messages | `cmux browser <surface> console list` |
| Clear console | `cmux browser <surface> console clear` |
| List errors | `cmux browser <surface> errors list` |
| New tab | `cmux browser <surface> tab new <url>` |
| List tabs | `cmux browser <surface> tab list` |
| Close tab | `cmux browser <surface> tab close --index <n>` |
| Cookies | `cmux browser <surface> cookies get|set|clear ...` |
| Storage | `cmux browser <surface> storage local|session get|set|clear ...` |

### Key Points
- **Use `--snapshot-after`** on mutating actions to get a fresh post-action snapshot inline.
- **Re-snapshot after navigation**, modal open/close, or major DOM changes.
- **Short refs** (`surface:N`, `e1`, `e2`) are the default — no need for UUIDs.
- **Troubleshooting stale refs**: If `not_found` or stale ref errors occur, simply re-run `snapshot --interactive`.
- **Troubleshooting `js_error`**: Some complex pages break the JS snapshot engine. Fall back to `get text body` or `get html body`.

---

## Backend 2: Playwright (Test Script Execution)

### When to use
- There are existing E2E test scripts in the repo (e.g., `.spec.ts`, `.test.js`).
- You want to run, debug, or extend a test suite.
- The project has a `playwright.config.ts` or similar.

### Quick Start

```bash
# 1. Check for Playwright tests
glob "**/*.spec.*"         # or
glob "**/playwright.config.*"

# 2. Install dependencies (if needed)
npm install               # or yarn / pnpm

# 3. Run all E2E tests
npx playwright test

# 4. Run a specific test file
npx playwright test e2e/login.spec.ts

# 5. Run with UI mode for debugging
npx playwright test --ui

# 6. Run in headed mode (visible browser)
npx playwright test --headed

# 7. Run with trace for post-mortem debugging
npx playwright test --trace on
```

### Using Playwright MCP Tools

When working within an agent context (e.g., OpenCode, Cline), the Playwright MCP server
provides equivalent operations:

| Action | MCP Tool |
|--------|----------|
| Navigate | `Playwright_browser_navigate` |
| Get snapshot | `Playwright_browser_snapshot` |
| Click | `Playwright_browser_click` |
| Fill | `Playwright_browser_type` or `browser_fill_form` |
| Press key | `Playwright_browser_press_key` |
| Select | `Playwright_browser_select_option` |
| Hover | `Playwright_browser_hover` |
| Drag & drop | `Playwright_browser_drag` |
| Evaluate JS | `Playwright_browser_evaluate` |
| Wait for text | `Playwright_browser_wait_for` |
| Screenshot | `Playwright_browser_take_screenshot` |
| Upload file | `Playwright_browser_file_upload` |
| Close browser | `Playwright_browser_close` |

### Workflow

1. **Start the test server** (if needed):
   ```bash
   npm run dev      # or npm start
   ```

2. **Use the MCP tools** to navigate and interact:
   ```
   browser_navigate → https://localhost:3000
   browser_wait_for → load complete
   browser_snapshot → get element refs
   browser_click → <target>
   browser_wait_for → text "Success"
   browser_take_screenshot → save evidence
   ```

3. **For assertions**, use `browser_evaluate` to run JS and return values:
   ```
   browser_evaluate → "() => document.querySelector('#result').innerText"
   ```

### Key Points
- **Prefer `browser_snapshot`** over screenshots for reliable element targeting.
- **Use `browser_wait_for`** generously to avoid race conditions.
- **Screenshots** are best for final evidence or when a11y snapshots are insufficient.
- **Trace files** (`--trace on`) can be viewed with `npx playwright show-trace trace.zip`.

---

## Backend 3: Chrome DevTools (Manual Debugging)

### When to use
- Neither cmux nor Playwright are available.
- You need deep debugging (console logs, network requests, performance traces).
- The task requires DevTools-specific insights (Lighthouse, heap snapshots, performance timeline).

### Quick Start

```bash
# 1. List open pages
Chrome_DevTools_list_pages

# 2. Select a page to interact with
Chrome_DevTools_select_page → pageId: 1

# 3. Navigate
Chrome_DevTools_navigate_page → type: url, url: https://example.com

# 4. Take a snapshot for element inspection
Chrome_DevTools_take_snapshot

# 5. Interact using element uids
Chrome_DevTools_click → uid: "element-uid"
Chrome_DevTools_fill → uid: "input-uid", value: "hello"
Chrome_DevTools_press_key → key: "Enter"
```

### Chrome DevTools MCP Tools Reference

| Action | MCP Tool |
|--------|----------|
| List pages | `Chrome_DevTools_list_pages` |
| Select page | `Chrome_DevTools_select_page` |
| Navigate | `Chrome_DevTools_navigate_page` |
| Take snapshot | `Chrome_DevTools_take_snapshot` |
| Click | `Chrome_DevTools_click` |
| Fill | `Chrome_DevTools_fill` |
| Fill form | `Chrome_DevTools_fill_form` |
| Hover | `Chrome_DevTools_hover` |
| Press key | `Chrome_DevTools_press_key` |
| Drag | `Chrome_DevTools_drag` |
| Evaluate JS | `Chrome_DevTools_evaluate_script` |
| Resize | `Chrome_DevTools_resize_page` |
| Screenshot | `Chrome_DevTools_take_screenshot` |
| Full-page screenshot | `Chrome_DevTools_take_screenshot` with `fullPage: true` |
| List console messages | `Chrome_DevTools_list_console_messages` |
| Get console message | `Chrome_DevTools_get_console_message` |
| List network requests | `Chrome_DevTools_list_network_requests` |
| Get network request | `Chrome_DevTools_get_network_request` |
| Lighthouse audit | `Chrome_DevTools_lighthouse_audit` |
| Memory snapshot | `Chrome_DevTools_take_memory_snapshot` |
| Performance trace | `Chrome_DevTools_performance_start_trace` / `stop_trace` |
| Get performance insight | `Chrome_DevTools_performance_analyze_insight` |
| Wait for text | `Chrome_DevTools_wait_for` |
| Handle dialog | `Chrome_DevTools_handle_dialog` |
| Emulate viewport/device | `Chrome_DevTools_emulate` |

### Advanced: Performance & Debugging

```bash
# Run Lighthouse audit (accessibility, SEO, best practices)
Chrome_DevTools_lighthouse_audit → device: desktop, mode: navigation

# Start performance trace
Chrome_DevTools_performance_start_trace → reload: true
# ... interact ...
Chrome_DevTools_performance_stop_trace

# Get a specific insight
Chrome_DevTools_performance_analyze_insight → insightSetId: "...", insightName: "DocumentLatency"
```

### Key Points
- **Snapshot uids are page-specific** — they change when the page reloads.
- **Console/network messages** persist across navigations in the same session.
- **Use `list_pages`** before `select_page` to make sure you're targeting the right tab.
- **Lighthouse** is great for catching accessibility and SEO regressions.
- **Performance traces** require navigating TO the target URL BEFORE starting the trace.

---

## Asserting Results

After acting, you must verify the outcome.

| What to verify | cmux | Playwright | Chrome DevTools |
|----------------|------|------------|-----------------|
| Page navigated | `get url` | `browser_navigate` result | URL in snapshot |
| Element exists | `snapshot` / `get count` | `browser_snapshot` | `take_snapshot` |
| Text content | `get text <ref>` | `browser_evaluate` | `evaluate_script` |
| Input value | `get value <ref>` | `browser_evaluate` | `evaluate_script` |
| Error-free console | `console list` | N/A (use test runner) | `list_console_messages` |
| Visual regression | `screenshot` | `browser_take_screenshot` | `take_screenshot` |
| Accessibility | N/A | N/A | `lighthouse_audit` |

---

## Recording / Evidence

Always capture evidence for E2E tests, especially for failures.

| Evidence type | cmux | Playwright | Chrome DevTools |
|---------------|------|-----------|-----------------|
| Screenshot | `screenshot` | `browser_take_screenshot` | `take_screenshot` |
| Full-page screenshot | N/A | `browser_take_screenshot` with `fullPage: true` | `take_screenshot` with `fullPage: true` |
| Console logs | `console list` | `--trace on` then show trace | `list_console_messages` |
| Network logs | N/A | `--trace on` | `list_network_requests` |
| DOM dump | `get html body` | N/A | N/A |
| State save/load | `state save <path>` | N/A | N/A |

---

## Troubleshooting

| Problem | Likely cause | Fix |
|---------|-----------|-----|
| Stale ref / `not_found` | DOM changed since last snapshot | Re-run `snapshot --interactive` (cmux) or `take_snapshot` (DevTools) |
| Element not interactable | Hidden / disabled / off-screen | Scroll into view or wait for visibility |
| Timing flake | Action before page ready | Use explicit waits (`--load-state`, `--selector`, `wait_for`) |
| `js_error` on snapshot (cmux) | Complex page JS conflicts | Fall back to `get text body` or `get html body` |
| Auth required | Session missing | Use `state save/load` (cmux), or log in via script |
| CORS / iframe issues | Cross-origin restrictions | Use `evaluate_script` with JS that operates inside the target context |

---

## Tool Comparison Summary

| Feature | cmux | Playwright | Chrome DevTools |
|---------|------|------------|-----------------|
| **Ease of setup** | Binary install | `npm install` | Built into Chrome |
| **Best for** | Ad-hoc automation | CI/CD test suites | Deep debugging |
| **Native wait strategies** | Excellent | Excellent | Basic (manual) |
| **Screenshot** | Yes | Yes | Yes |
| **Trace / network recording** | No | Yes | Yes |
| **Console inspection** | Yes | Via trace | Yes |
| **Performance profiling** | No | No | Excellent (Lighthouse, traces) |
| **Headless mode** | Yes | Yes | Yes |
| **Shadow DOM / iframe** | Good | Excellent | Good |
| **Session persistence** | Yes (`state save/load`) | Via `storageState` | Limited |

---

## Integration with AGENTS.md

Reference this skill from `AGENTS.md` with a high-level pointer. Example:

```markdown
## E2E Testing
- **Preferred**: cmux (if installed). See `.agents/skills/e2e-testing/SKILL.md` → Backend 1.
- **Test scripts available**: Playwright. See `.agents/skills/e2e-testing/SKILL.md` → Backend 2.
- **Fallback**: Chrome DevTools MCP tools. See `.agents/skills/e2e-testing/SKILL.md` → Backend 3.
```

This keeps `AGENTS.md` concise while delegating tool-specific details to the skill.
