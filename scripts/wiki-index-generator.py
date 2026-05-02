#!/usr/bin/env python3
"""
wiki-index-generator.py

Reads wiki/index.base (a Dataview YAML config), interprets the query,
and generates wiki/index.md by scanning all wiki pages and extracting
their frontmatter (especially `description:`).

Usage:
    python3 wiki-index-generator.py [vault_root]

If vault_root is omitted, defaults to the current working directory.
"""

import sys
import os
import yaml
from pathlib import Path
from datetime import datetime


def parse_frontmatter(filepath: Path) -> dict:
    """Extract YAML frontmatter from a markdown file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        return {}

    if not content.startswith('---'):
        return {}

    parts = content.split('---', 2)
    if len(parts) < 3:
        return {}

    try:
        return yaml.safe_load(parts[1]) or {}
    except Exception:
        return {}


def gather_pages(wiki_dir: Path) -> list:
    """Scan wiki/ for all markdown files and extract metadata."""
    pages = []
    for filepath in wiki_dir.rglob('*.md'):
        # Skip log.md and index.md themselves
        if filepath.name in ('index.md', 'log.md', 'index.base'):
            continue

        rel = filepath.relative_to(wiki_dir)
        fm = parse_frontmatter(filepath)
        if not fm:
            continue

        pages.append({
            'name': filepath.stem,
            'path': str(rel.with_suffix('')),
            'folder': str(rel.parent),
            'description': fm.get('description', ''),
            'title': fm.get('title', filepath.stem),
            'type': fm.get('type', 'page'),
        })
    return pages


def apply_filters(pages: list, filters_config: dict, wiki_dir: Path) -> list:
    """Apply Dataview-style filters. Currently supports file.folder.startsWith."""
    result = pages

    if not filters_config or 'and' not in filters_config:
        return result

    for condition in filters_config['and']:
        if isinstance(condition, dict):
            for key, value in condition.items():
                if key == 'file.folder.startsWith':
                    prefix = value
                    result = [p for p in result if p['folder'].startswith(prefix)]
    return result


def apply_groupby(pages: list, groupby_config: dict) -> dict:
    """Group pages by a property."""
    prop = groupby_config.get('property', 'file.folder')
    direction = groupby_config.get('direction', 'ASC')

    groups = {}
    for page in pages:
        key = page.get(prop.replace('file.', ''), '')
        groups.setdefault(key, []).append(page)

    # Sort within each group
    for key in groups:
        groups[key].sort(key=lambda p: p['name'].lower())

    return groups


def apply_order(pages: list, order_config: list) -> list:
    """Sort pages by specified properties."""
    def sort_key(page):
        keys = []
        for prop in order_config:
            val = page.get(prop.replace('file.', ''), '')
            if isinstance(val, str):
                val = val.lower()
            keys.append(val)
        return keys
    return sorted(pages, key=sort_key)


def generate_index_md(groups: dict, output_path: Path) -> str:
    """Generate the index markdown content."""
    lines = [
        '---',
        'title: Wiki Index',
        'description: Auto-generated catalog of all wiki pages',
        '---',
        '',
        '# Wiki Index',
        '',
        f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M")}',
        '',
    ]

    for section in sorted(groups.keys()):
        lines.append(f'## {section}')
        lines.append('')
        for page in groups[section]:
            desc = page['description'] or '(no description)'
            lines.append(f'- [[{page["path"]}]] — {desc}')
        lines.append('')

    return '\n'.join(lines)


def main():
    vault_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    wiki_dir = vault_root / 'wiki'
    index_base = wiki_dir / 'index.base'
    index_md = wiki_dir / 'index.md'

    if not wiki_dir.exists():
        print(f"Error: wiki/ directory not found at {wiki_dir}", file=sys.stderr)
        sys.exit(1)

    if not index_base.exists():
        print(f"Warning: {index_base} not found. Using default query parameters.", file=sys.stderr)
        config = {'views': [{'filters': {'and': [{'file.folder.startsWith': 'wiki/'}]}, 'groupBy': {'property': 'file.folder', 'direction': 'ASC'}, 'order': ['file.name', 'description']}]}
    else:
        with open(index_base, 'r') as f:
            config = yaml.safe_load(f)

    # Parse the first view (Dataview typically uses the first)
    view = config.get('views', [{}])[0]
    filters_cfg = view.get('filters', {})
    groupby_cfg = view.get('groupBy', {'property': 'file.folder', 'direction': 'ASC'})
    order_cfg = view.get('order', ['file.name', 'description'])

    # Gather and filter
    pages = gather_pages(wiki_dir)
    pages = apply_filters(pages, filters_cfg, wiki_dir)
    pages = apply_order(pages, order_cfg)

    # Group
    groups = apply_groupby(pages, groupby_cfg)

    # Generate output
    content = generate_index_md(groups, index_md)

    with open(index_md, 'w', encoding='utf-8') as f:
        f.write(content)

    total = sum(len(g) for g in groups.values())
    sections = len(groups)
    print(f"Generated {index_md} with {total} pages across {sections} sections.")


if __name__ == '__main__':
    main()
