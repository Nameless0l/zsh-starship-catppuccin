"""Lit le mapping de Material Icon Theme (fichiers .ts traités comme données).

Usage : python3 -I parse_material.py <racine du dépôt Material> <sortie.json>
"""
import json
import re
import sys

# Motifs de noms de Material, réduits aux variantes courantes : le thème reste léger,
# et une variante rare garde l'icône de son extension
MOTIFS = {
    "ecmascript": ["{}.js", "{}.mjs", "{}.cjs", "{}.ts"],
    "configuration": ["{}.json", "{}.yaml", "{}.yml", "{}.toml"],
    "yaml": ["{}.yaml", "{}.yml"],
    "dotfile": [".{}", "{}"],
}
MOTIFS["nodeEcosystem"] = MOTIFS["ecmascript"] + MOTIFS["configuration"]
MOTIFS["cosmiconfig"] = (
    [".{}rc"] + [".{}rc." + e for e in ("json", "yaml", "yml", "js", "cjs")]
    + ["{}.config." + e for e in ("js", "mjs", "cjs", "ts")]
)


def chaines(texte):
    return re.findall(r"'([^']*)'", texte)


def tableau(corps, cle):
    m = re.search(r"\b" + cle + r"\s*:\s*\[(.*?)\]", corps, re.S)
    return chaines(m.group(1)) if m else []


def entrees(ts):
    # Chaque icône commence par "{ name: '...'" ; son corps va jusqu'à la suivante
    morceaux = re.split(r"\{\s*name:\s*'", ts)[1:]
    out = []
    for p in morceaux:
        nom, corps = p.split("'", 1)
        noms = tableau(corps, "fileNames")
        m = re.search(r"patterns\s*:\s*\{(.*?)\}", corps, re.S)
        if m:
            for cle, motif in re.findall(r"'?([\w.@/-]+)'?\s*:\s*FileNamePattern\.(\w+)", m.group(1)):
                noms += [g.format(cle) for g in MOTIFS[motif[0].lower() + motif[1:]]]
        clone = re.search(r"clone\s*:\s*\{\s*base\s*:\s*'([^']+)'\s*,\s*color\s*:\s*'([^']+)'", corps)
        out.append({
            "name": nom,
            "ext": tableau(corps, "fileExtensions"),
            "files": noms,
            "folders": tableau(corps, "folderNames"),
            "pack": "enabledFor" in corps,
            "clone": clone.groups() if clone else None,
        })
    return out


def main():
    racine, sortie = sys.argv[1], sys.argv[2]
    fi = entrees(open(f"{racine}/src/core/icons/fileIcons.ts", encoding="utf-8").read())
    dossiers = open(f"{racine}/src/core/icons/folderIcons.ts", encoding="utf-8").read()
    # Seul le thème de dossiers par défaut ("specific") nous intéresse
    dossiers = dossiers.split("name: 'classic'")[0]
    fo = entrees(dossiers)
    palette = dict(re.findall(r"'?([\w-]+)'?\s*:\s*'(#[0-9A-Fa-f]{6})'",
                              open(f"{racine}/src/core/generator/clones/utils/color/materialPalette.ts",
                                   encoding="utf-8").read()))

    ext, files, folders, clones = {}, {}, {}, {}
    for e in fi + fo:
        if e["pack"]:
            continue
        if e["clone"]:
            base, coul = e["clone"]
            clones[e["name"]] = {"base": base, "color": palette.get(coul, coul if coul.startswith("#") else None)}
        for x in e["ext"]:
            ext.setdefault(x.lower(), e["name"])
        for f in e["files"]:
            files.setdefault(f.lower(), e["name"])
        for f in e["folders"]:
            folders.setdefault(f.lower(), e["name"])
    json.dump({"ext": ext, "files": files, "folders": folders, "clones": clones},
              open(sortie, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(len(ext), "extensions,", len(files), "noms de fichiers,", len(folders), "dossiers,", len(clones), "clones")


if __name__ == "__main__":
    main()
