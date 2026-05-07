#!/usr/bin/env python3
"""Register new Claude Desktop skills from a skills directory into manifest.json.

Usage: deploy_skills.py <manifest_path> <skills_root>
"""
import datetime, json, os, sys

manifest_path, skills_root = sys.argv[1], sys.argv[2]
with open(manifest_path) as f:
    manifest = json.load(f)
existing = {s['skillId'] for s in manifest['skills']}
changed = False
for skill_name in sorted(os.listdir(skills_root)):
    skill_md = os.path.join(skills_root, skill_name, 'SKILL.md')
    if not os.path.isfile(skill_md) or skill_name in existing:
        continue
    desc = skill_name
    with open(skill_md) as f:
        content = f.read()
    if content.startswith('---'):
        for line in content.split('\n')[1:]:
            if line.startswith('---'):
                break
            if line.lower().startswith('description:'):
                desc = line.split(':', 1)[1].strip().strip('"\'')
    now = datetime.datetime.now(datetime.timezone.utc)
    manifest['skills'].append({
        'skillId': skill_name,
        'name': skill_name,
        'description': desc,
        'creatorType': 'user',
        'updatedAt': now.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z',
        'enabled': True,
    })
    manifest['lastUpdated'] = int(now.timestamp() * 1000)
    print(f'  Registered skill: {skill_name}')
    changed = True
if changed:
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)
