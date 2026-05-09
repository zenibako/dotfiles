#!/usr/bin/env python3
"""Strip comments from JSONC and validate against OpenCode JSON schema."""
import json, re, sys, urllib.request

try:
    import jsonschema
except ImportError:
    jsonschema = None


def strip_jsonc(text):
    # Strip block comments
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    # Strip line comments, but be careful about strings
    lines = []
    for line in text.splitlines():
        result = []
        in_string = False
        escape_next = False
        for ch in line:
            if escape_next:
                result.append(ch)
                escape_next = False
                continue
            if ch == '\\':
                result.append(ch)
                escape_next = True
                continue
            if ch == '"':
                in_string = not in_string
                result.append(ch)
                continue
            if not in_string and ch == '/':
                # Look ahead for //
                if len(result) > 0 and result[-1] == '/':
                    # Remove the leading / and break
                    result.pop()
                    break
            result.append(ch)
        lines.append(''.join(result))
    text = '\n'.join(lines)
    # Strip trailing commas before } or ]
    text = re.sub(r',\s*([}\]])', r'\1', text)
    return text


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <jsonc-file> [schema-url]", file=sys.stderr)
        sys.exit(1)

    jsonc_path = sys.argv[1]
    schema_url = sys.argv[2] if len(sys.argv) > 2 else "https://opencode.ai/config.json"

    try:
        with open(jsonc_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"File not found: {jsonc_path}", file=sys.stderr)
        sys.exit(1)

    stripped = strip_jsonc(content)

    try:
        data = json.loads(stripped)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON (after stripping comments): {e}", file=sys.stderr)
        sys.exit(1)

    # Fetch schema
    req = urllib.request.Request(
        schema_url,
        headers={"User-Agent": "Mozilla/5.0 (dotfiles-validation)"}
    )
    try:
        with urllib.request.urlopen(req) as response:
            schema = json.loads(response.read().decode())
    except Exception as e:
        print(f"Failed to fetch schema from {schema_url}: {e}", file=sys.stderr)
        sys.exit(1)

    # Validate
    if jsonschema is None:
        print("WARNING: jsonschema module not available, skipping schema validation")
    else:
        try:
            jsonschema.validate(instance=data, schema=schema)
            print(f"Schema validation passed: {jsonc_path}")
        except jsonschema.ValidationError as e:
            print(f"Schema validation failed: {e.message} at {list(e.path)}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
