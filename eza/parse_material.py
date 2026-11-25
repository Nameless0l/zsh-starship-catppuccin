"""Lit le mapping de Material Icon Theme (fichiers .ts traités comme données).

Usage : python3 -I parse_material.py <dossier_des_.ts> <sortie.json>
"""
import json, re, sys

def entries(ts):
    # Découpe sur chaque "name: '...'" et lit les tableaux qui suivent jusqu'au prochain name
    parts = re.split(r"\{\s*name:\s*'", ts)[1:]
    out = []
    for p in parts:
        name = p.split("'", 1)[0]
        body = p.split("'", 1)[1]
        body = re.split(r"\{\s*name:\s*'", body)[0]
        def arr(key):
            m = re.search(key + r"\s*:\s*\[(.*?)\]", body, re.S)
            return re.findall(r"'([^']*)'", m.group(1)) if m else []
        out.append({"name": name, "ext": arr("fileExtensions"), "files": arr("fileNames"),
                    "folders": arr("folderNames"), "clone": "clone" in body})
    return out

ref, sortie = sys.argv[1], sys.argv[2]
fi = entries(open(f"{ref}/fileIcons.ts").read())
fo = entries(open(f"{ref}/folderIcons.ts").read())
ext, files, folders, clones = {}, {}, {}, set()
for e in fi:
    for x in e["ext"]:
        ext.setdefault(x.lower(), e["name"])
    for f in e["files"]:
        files.setdefault(f, e["name"])
    if e["clone"]:
        clones.add(e["name"])
for e in fo:
    for f in e["folders"]:
        folders.setdefault(f, e["name"])
    if e["clone"]:
        clones.add(e["name"])
json.dump({"ext": ext, "files": files, "folders": folders, "clones": sorted(clones)},
          open(sortie, "w"), indent=1)
print(len(ext), "extensions,", len(files), "noms de fichiers,", len(folders), "dossiers,", len(clones), "clones")
