#!/usr/bin/env python3
"""Validate a JSONC file (strips // comments, /* */ blocks, and trailing commas)."""
import json, re, sys


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    result = []
    in_string = False
    i = 0
    while i < len(text):
        ch = text[i]
        if not in_string and ch == '"':
            in_string = True
            result.append(ch)
        elif in_string and ch == '"':
            slashes = 0
            j = len(result) - 1
            while j >= 0 and result[j] == '\\':
                slashes += 1
                j -= 1
            if slashes % 2 == 1:
                result.append(ch)
            else:
                in_string = False
                result.append(ch)
        elif not in_string and ch == '/' and i + 1 < len(text) and text[i + 1] == '/':
            while i < len(text) and text[i] not in '\r\n':
                i += 1
            continue
        else:
            result.append(ch)
        i += 1
    return ''.join(result)


path = sys.argv[1]
with open(path) as f:
    content = f.read()
content = strip_comments(content)
content = re.sub(r',(\s*[}\]])', r'\1', content)
try:
    json.loads(content)
except json.JSONDecodeError as e:
    print(f'Invalid JSONC in {path}: {e}', file=sys.stderr)
    sys.exit(1)
