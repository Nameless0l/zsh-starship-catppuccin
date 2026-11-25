"""Génère ~/.config/eza/theme.yml façon Material Icon Theme (VS Code).

Les couleurs sont lues dans les SVG de Material Icon Theme, les glyphes viennent
du jeu Material Design de Nerd Fonts (vérifiés dans la version 3.3.0).
Usage :
  python3 -I gen_theme.py icones <material_map.json>
      liste les icônes Material dont il faut télécharger le SVG
  python3 -I gen_theme.py theme <material_map.json> <dossier_svg> <glyphnames.json> <sortie>
      écrit le theme.yml
Le plus simple est de passer par build.sh, qui fait tout.
"""
import json
import os
import re
import sys
from collections import Counter

# ---------- Ce qu'on habille ----------
EXTENSIONS = """
rs c h cpp cc cxx hpp hh py pyi ipynb js mjs cjs ts jsx tsx php java jar kt kts go lua rb r swift cs
html htm css scss sass vue svelte md markdown rst json jsonc yaml yml toml xml ini conf cfg env
sql db sqlite sh bash zsh fish ps1 bat cmd tex bib cls sty pdf png jpg jpeg gif svg webp ico bmp
mp4 mkv mov avi webm mp3 wav flac ogg zip tar gz tgz xz bz2 7z rar zst deb rpm apk aab dex smali
csv tsv xlsx xls docx doc pptx ppt odt txt log lock key pem crt pub diff patch s asm ld elf bin hex
o so a dll exe iso img ttf otf woff woff2 bb bbappend bbclass dts dtsi proto gradle cmake mk
service nix http graphql
""".split()

FILENAMES = """
Dockerfile dockerfile docker-compose.yml docker-compose.yaml compose.yml compose.yaml .dockerignore
Makefile makefile GNUmakefile CMakeLists.txt Cargo.toml Cargo.lock package.json package-lock.json
composer.json composer.lock artisan README.md readme.md README README.txt LICENSE LICENSE.md
LICENSE.txt license CHANGELOG.md .gitignore .gitattributes .gitmodules .env .env.example
.editorconfig .zshrc .bashrc .profile .shell_common requirements.txt pyproject.toml setup.py
tsconfig.json build.gradle settings.gradle gradlew AndroidManifest.xml go.mod go.sum
local.conf bblayers.conf
""".split()

FOLDERS = """
src source lib include test tests spec docs doc build dist out target bin node_modules vendor
.git .github .vscode .idea config configs .config scripts assets images img public app components
android docker .cargo models data notebooks examples tools utils logs tmp temp downloads
Downloads Documents Desktop Pictures Music Videos Templates Téléchargements Bureau Images Musique
Vidéos Modèles Public .ssh keys secrets .local .cache migrations database resources routes views
storage api server client meta patches venv .venv env fonts themes plugins hooks
""".split()

# Noms français du dossier personnel, ramenés au nom Material équivalent
ALIAS_DOSSIER = {
    "téléchargements": "downloads", "bureau": "desktop", "images": "pictures",
    "musique": "music", "vidéos": "videos", "modèles": "templates", ".ssh": "keys",
    ".local": "home", ".venv": "venv",
}

# Sans icône Material : glyphe et couleur choisis à la main
MANUEL = {
    "ext:bb": ("md-cube_outline", "#ff9800"), "ext:bbappend": ("md-cube_outline", "#ffb74d"),
    "ext:bbclass": ("md-cube_outline", "#ff9800"), "ext:dts": ("md-chip", "#26a69a"),
    "ext:dtsi": ("md-chip", "#26a69a"), "ext:ld": ("md-memory", "#90a4ae"),
    "ext:elf": ("md-chip", "#8bc34a"), "ext:aab": ("md-android", "#8bc34a"),
    "ext:service": ("md-cog", "#42a5f5"), "ext:o": ("md-cube_outline", "#90a4ae"),
    "file:local.conf": ("md-cube_outline", "#ff9800"),
    "file:bblayers.conf": ("md-cube_outline", "#ff9800"),
    "file:.shell_common": ("md-console", "#ff7043"), "file:.zshrc": ("md-console", "#ff7043"),
    "file:.bashrc": ("md-console", "#ff7043"), "file:.profile": ("md-console", "#ff7043"),
}

# Icône Material vers glyphe Nerd Font
GLYPHE = {
    "rust": "md-language_rust", "python": "md-language_python", "c": "md-language_c",
    "h": "md-language_c", "cpp": "md-language_cpp", "hpp": "md-language_cpp",
    "javascript": "md-language_javascript", "typescript": "md-language_typescript",
    "react": "md-react", "react_ts": "md-react", "php": "md-language_php",
    "laravel": "md-laravel", "java": "md-language_java", "jar": "md-language_java",
    "kotlin": "md-language_kotlin", "go": "md-language_go", "go-mod": "md-language_go",
    "lua": "md-language_lua", "ruby": "md-language_ruby", "r": "md-language_r",
    "swift": "md-language_swift", "csharp": "md-language_csharp",
    "html": "md-language_html5", "css": "md-language_css3", "sass": "md-sass",
    "vue": "md-vuejs", "svelte": "seti-svelte", "markdown": "md-language_markdown",
    "readme": "md-information", "changelog": "md-history", "license": "md-license",
    "json": "md-code_json", "yaml": "seti-yml", "toml": "custom-toml", "xml": "md-xml",
    "settings": "md-cog", "tune": "md-tune", "database": "md-database",
    "console": "md-console", "powershell": "md-powershell", "tex": "seti-tex",
    "sty": "seti-tex", "bibliography": "md-book_open_page_variant",
    "pdf": "md-file_pdf_box", "image": "md-file_image", "svg": "md-svg",
    "video": "md-file_video", "audio": "md-music", "zip": "md-zip_box",
    "android": "md-android", "jupyter": "md-notebook", "table": "md-file_table",
    "word": "md-file_word_box", "powerpoint": "md-file_powerpoint_box",
    "document": "md-file_document", "log": "md-format_list_bulleted", "lock": "md-lock",
    "key": "md-key", "certificate": "md-certificate", "diff": "md-file_compare",
    "git": "md-git", "docker": "md-docker", "makefile": "md-hammer_wrench",
    "cmake": "dev-cmake", "assembly": "md-chip", "hex": "md-hexadecimal",
    "dll": "md-application_cog", "exe": "md-application", "lib": "md-library",
    "disc": "md-disc", "font": "md-format_font", "proto": "md-protocol", "nix": "md-nix",
    "http": "md-web", "graphql": "md-graphql", "gradle": "seti-gradle",
    "nodejs": "md-nodejs", "npm": "md-npm", "cargo": "md-language_rust",
    "editorconfig": "md-cog", "pip": "md-language_python", "tsconfig": "md-language_typescript",
    "composer": "md-language_php", "3d": "md-cube_outline",
    "python-misc": "md-language_python",
    # Dossiers
    "folder": "md-folder", "folder-src": "md-folder_pound", "folder-lib": "md-folder_multiple",
    "folder-include": "md-folder_information", "folder-test": "md-folder_check",
    "folder-docs": "md-folder_text", "folder-dist": "md-folder_zip",
    "folder-target": "md-folder_marker", "folder-node": "custom-folder_npm",
    "folder-git": "custom-folder_git", "folder-github": "custom-folder_github",
    "folder-vscode": "md-folder_cog", "folder-intellij": "md-folder_cog",
    "folder-config": "custom-folder_config", "folder-scripts": "md-folder_play",
    "folder-resource": "md-folder_star", "folder-images": "md-folder_image",
    "folder-public": "md-folder_upload", "folder-app": "md-folder_star",
    "folder-components": "md-folder_multiple", "folder-android": "md-folder_cog",
    "folder-docker": "md-folder_cog", "folder-rust": "md-folder_cog",
    "folder-class": "md-folder_star", "folder-database": "md-folder_table",
    "folder-jupyter": "md-folder_text", "folder-examples": "md-folder_search",
    "folder-tools": "md-folder_wrench", "folder-utils": "md-folder_wrench",
    "folder-log": "md-folder_alert", "folder-temp": "md-folder_clock",
    "folder-download": "md-folder_download", "folder-desktop": "md-folder_account",
    "folder-audio": "md-folder_music", "folder-video": "md-folder_play",
    "folder-template": "md-folder_file", "folder-home": "md-folder_home",
    "folder-keys": "md-folder_key", "folder-migrations": "md-folder_sync",
    "folder-routes": "md-folder_network", "folder-views": "md-folder_eye",
    "folder-api": "md-folder_network", "folder-server": "md-folder_network",
    "folder-client": "md-folder_account", "folder-meta": "md-folder_information",
    "folder-environment": "md-folder_cog", "folder-font": "md-folder_text",
    "folder-theme": "md-folder_star", "folder-plugin": "md-folder_cog",
    "folder-hook": "md-folder_sync",
}


def couleur_svg(path):
    """Couleur dominante d'une icône : la plus fréquente parmi les remplissages."""
    txt = open(path, encoding="utf-8").read()
    vals = re.findall(r'fill[=:]\s*"?(#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?)\b', txt)
    # Dégradés : on prend les couleurs des arrêts
    vals += re.findall(r'stop-color="(#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?)"', txt)
    vals = [norm(v) for v in vals]
    vals = [v for v in vals if v not in ("#ffffff", "#000000")]
    if not vals:
        return None
    # La plus fréquente ; à égalité, la plus saturée (l'accent plutôt que le gris)
    return max(Counter(vals).items(), key=lambda kv: (kv[1], saturation(kv[0])))[0]


def norm(c):
    c = c.lower()
    return "#" + "".join(ch * 2 for ch in c[1:]) if len(c) == 4 else c


def saturation(c):
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return max(r, g, b) - min(r, g, b)


def icone_fichier(m, f):
    low = f.lower()
    icone = m["files"].get(low) or m["files"].get(f) or m["ext"].get(low)
    if icone is None and "." in low:
        icone = m["ext"].get(low.rsplit(".", 1)[1])
    return icone


def icone_dossier(m, d):
    low = ALIAS_DOSSIER.get(d.lower(), d.lower())
    return m["folders"].get(low.lstrip("._")) or m["folders"].get(low)


def icones_necessaires(m):
    clones = {"sty": "tex"}
    besoin = {"folder"}
    besoin.update(m["ext"][e] for e in EXTENSIONS if e in m["ext"])
    besoin.update(i for i in (icone_fichier(m, f) for f in FILENAMES) if i)
    besoin.update(i for i in (icone_dossier(m, d) for d in FOLDERS) if i)
    return sorted(clones.get(i, i) for i in besoin)


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "icones":
        print("\n".join(icones_necessaires(json.load(open(sys.argv[2])))))
        return
    if len(sys.argv) != 6 or sys.argv[1] != "theme":
        raise SystemExit(__doc__)
    mapping, svgdir, glyphs_path, sortie = sys.argv[2:6]
    m = json.load(open(mapping))
    glyphs = json.load(open(glyphs_path))

    def glyphe(nom):
        if nom not in glyphs:
            raise SystemExit(f"glyphe absent de Nerd Fonts : {nom}")
        return chr(int(glyphs[nom]["code"], 16))

    # Icônes générées au build de Material (pas de SVG dans le dépôt) : couleur d'une voisine
    clones = {"sty": "tex"}

    def couleur(icone):
        p = os.path.join(svgdir, clones.get(icone, icone) + ".svg")
        return couleur_svg(p) if os.path.exists(p) else None

    manquants = []

    def entree(cle, icone):
        if cle in MANUEL:
            g, c = MANUEL[cle]
            return glyphe(g), c
        if icone is None:
            manquants.append(cle)
            return None
        c = couleur(icone)
        g = GLYPHE.get(icone)
        if c is None or g is None:
            manquants.append(f"{cle} ({icone}{'' if c else ', pas de SVG'}{'' if g else ', pas de glyphe'})")
            return None
        return glyphe(g), c

    exts, noms = {}, {}
    for e in EXTENSIONS:
        r = entree("ext:" + e, m["ext"].get(e))
        if r:
            exts[e] = r
    for f in FILENAMES:
        r = entree("file:" + f, icone_fichier(m, f))
        if r:
            noms[f] = r
    for d in FOLDERS:
        r = entree("dir:" + d, icone_dossier(m, d))
        if r:
            noms[d] = r

    dossier = couleur("folder") or "#90a4ae"

    def ligne(k, v):
        g, c = v
        cle = json.dumps(k, ensure_ascii=False)
        return f'  {cle}: {{icon: {{glyph: {json.dumps(g, ensure_ascii=False)}, style: {{foreground: "{c}"}}}}}}'

    out = [
        "# Thème eza façon Material Icon Theme (VS Code)",
        "# Couleurs reprises des icônes Material, glyphes du jeu Material Design de Nerd Fonts.",
        "# Généré automatiquement : relancer le générateur plutôt que d'éditer à la main.",
        "",
        "filekinds:",
        f'  directory: {{foreground: "{dossier}", is_bold: true}}',
        "",
        "filenames:",
    ]
    out += [ligne(k, v) for k, v in sorted(noms.items(), key=lambda x: x[0].lower())]
    out += ["", "extensions:"]
    out += [ligne(k, v) for k, v in sorted(exts.items())]
    open(sortie, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(f"{len(noms)} noms, {len(exts)} extensions, dossier par défaut {dossier}")
    if manquants:
        print("Sans icône :", ", ".join(manquants))


if __name__ == "__main__":
    main()
