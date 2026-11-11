#!/usr/bin/env python3
"""Rigenera mods.json e mmc-pack.json dall'istanza PolyMC locale.

Uso: python3 export.py ~/.local/share/PolyMC/instances/<istanza>
Tutte le mod devono essere su Modrinth (i jar non vanno nel repo: licenze).
"""
import hashlib, json, shutil, sys, urllib.request
from pathlib import Path

inst = Path(sys.argv[1]).expanduser()
here = Path(__file__).parent
jars = sorted((inst / '.minecraft' / 'mods').glob('*.jar'))
sha1 = {hashlib.sha1(j.read_bytes()).hexdigest(): j.name for j in jars}

req = urllib.request.Request(
    'https://api.modrinth.com/v2/version_files',
    data=json.dumps({'hashes': list(sha1), 'algorithm': 'sha1'}).encode(),
    headers={'Content-Type': 'application/json', 'User-Agent': 'minecraft-setup-export'})
versions = json.load(urllib.request.urlopen(req))

mods, missing = [], []
for h, name in sha1.items():
    v = versions.get(h)
    f = v and next((f for f in v['files'] if f['hashes']['sha1'] == h), None)
    if f:
        mods.append({'name': name, 'sha1': h, 'url': f['url']})
    else:
        missing.append(name)
if missing:
    sys.exit('Non trovate su Modrinth: ' + ', '.join(missing))

mods.sort(key=lambda m: m['name'].lower())
(here / 'mods.json').write_text(json.dumps(mods, indent=2) + '\n')
shutil.copy(inst / 'mmc-pack.json', here / 'mmc-pack.json')
print(len(mods), 'mod esportate')
