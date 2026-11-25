"""Génère theme.yml pour eza façon Material Icon Theme (VS Code).

Couleurs lues dans les SVG de Material Icon Theme, glyphes du jeu Material Design
de Nerd Fonts (et des jeux Devicons et Seti quand Material Design n'a pas la marque).
Sans glyphe correspondant, seule la couleur est donnée : eza garde alors son icône.
Usage :
  python3 -I gen_theme.py <material_map.json> <dossier_svg> <glyphnames.json> <sortie>
Le plus simple est de passer par build.sh, qui fait tout.
"""
import json
import os
import re
import sys
from collections import Counter

# Noms français du dossier personnel, ramenés au nom Material équivalent
DOSSIERS_FR = {
    "Téléchargements": "downloads", "Bureau": "desktop", "Images": "pictures",
    "Musique": "music", "Vidéos": "videos", "Modèles": "templates",
    "Documents": "documents", "Public": "public",
}

# eza distingue la casse : ces noms courants ne s'obtiennent pas en mettant juste une majuscule
NOMS_CASSES = [
    "CMakeLists.txt", "AndroidManifest.xml", "GNUmakefile", "SConstruct", "SConscript",
    "BUILD.bazel", "WORKSPACE.bazel", "MODULE.bazel", "Package.swift", "Info.plist",
]

# Sans icône Material : glyphe et couleur choisis à la main
MANUEL = {
    "ext:bb": ("md-cube_outline", "#ff9800"), "ext:bbappend": ("md-cube_outline", "#ffb74d"),
    "ext:bbclass": ("md-cube_outline", "#ff9800"), "ext:inc": ("md-cube_outline", "#ffb74d"),
    "ext:dts": ("md-chip", "#26a69a"), "ext:dtsi": ("md-chip", "#26a69a"),
    "ext:dtb": ("md-chip", "#26a69a"), "ext:dtbo": ("md-chip", "#26a69a"),
    "ext:ld": ("md-memory", "#90a4ae"), "ext:elf": ("md-chip", "#8bc34a"),
    "ext:aab": ("md-android", "#8bc34a"), "ext:service": ("md-cog", "#42a5f5"),
    "ext:o": ("md-cube_outline", "#90a4ae"), "ext:ko": ("md-cube_outline", "#90a4ae"),
    "file:local.conf": ("md-cube_outline", "#ff9800"),
    "file:bblayers.conf": ("md-cube_outline", "#ff9800"),
    "file:.shell_common": ("md-console", "#ff7043"), "file:.zshrc.local": ("md-console", "#ff7043"),
    "file:.zshrc": ("md-console", "#ff7043"), "file:.bashrc": ("md-console", "#ff7043"),
    "file:.profile": ("md-console", "#ff7043"), "file:.zprofile": ("md-console", "#ff7043"),
    "file:.bash_profile": ("md-console", "#ff7043"), "file:.bash_aliases": ("md-console", "#ff7043"),
}

# Icône Material vers glyphe Nerd Font, quand le nom ne suffit pas à le trouver.
# Une liste donne plusieurs pistes, la première présente dans Nerd Fonts gagne.
GLYPHE = {
    "c": "md-language_c", "h": "md-language_c", "cpp": "md-language_cpp", "hpp": "md-language_cpp",
    "javascript": "md-language_javascript", "typescript": "md-language_typescript",
    "typescript-def": "md-language_typescript", "javascript-map": "md-language_javascript",
    "react": "md-react", "react_ts": "md-react", "html": "md-language_html5",
    "css": "md-language_css3", "css-map": "md-language_css3", "sass": "md-sass", "less": "dev-less",
    "vue": "md-vuejs", "vue-config": "md-vuejs", "svelte": "seti-svelte", "markdown": "md-language_markdown",
    "readme": "md-information", "changelog": "md-history", "license": "md-license",
    "json": "md-code_json", "yaml": "seti-yml", "toml": "custom-toml", "xml": "md-xml",
    "settings": "md-cog", "tune": "md-tune", "database": "md-database", "console": "md-console",
    "powershell": "md-powershell", "tex": "seti-tex", "bibliography": "md-book_open_page_variant",
    "pdf": "md-file_pdf_box", "image": "md-file_image", "svg": "md-svg", "video": "md-file_video",
    "audio": "md-music", "zip": "md-zip_box", "jupyter": "md-notebook", "table": "md-file_table",
    "word": "md-file_word_box", "powerpoint": "md-file_powerpoint_box", "excel": "md-file_excel_box",
    "document": "md-file_document", "log": "md-format_list_bulleted", "lock": "md-lock",
    "key": "md-key", "certificate": "md-certificate", "diff": "md-file_compare",
    "git": "md-git", "docker": "md-docker", "makefile": "md-hammer_wrench", "cmake": "dev-cmake",
    "assembly": "md-chip", "hex": "md-hexadecimal", "dll": "md-application_cog",
    "exe": "md-application", "lib": "md-library", "disc": "md-disc", "font": "md-format_font",
    "proto": "md-protocol", "http": "md-web", "gradle": "seti-gradle", "cargo": "md-language_rust",
    "editorconfig": "md-cog", "pip": "md-language_python", "python-misc": "md-language_python",
    "tsconfig": "md-language_typescript", "jsconfig": "md-language_javascript",
    "composer": "md-language_php", "3d": "md-cube_outline", "go-mod": "md-language_go",
    "go_gopher": "md-language_go", "kotlin": "md-language_kotlin", "laravel": "md-laravel",
    "java": "md-language_java", "jar": "md-language_java", "javaclass": "md-language_java",
    "csharp": "md-language_csharp", "fsharp": "dev-fsharp", "visualstudio": "md-microsoft_visual_studio",
    "vscode": "md-microsoft_visual_studio_code", "email": "md-email", "url": "md-link",
    "lighthouse": "md-lighthouse", "robots": "md-robot", "nodejs_alt": "md-nodejs",
    "tailwindcss": ["md-tailwind", "dev-tailwindcss"], "yarn": ["seti-yarn", "dev-yarn"],
    "pnpm": ["seti-pnpm", "dev-pnpm"], "vite": ["seti-vite", "dev-vitejs"], "vitest": ["seti-vitest", "dev-vitest"],
    "webpack": ["md-webpack", "seti-webpack"], "eslint": ["seti-eslint", "dev-eslint"],
    "prettier": ["custom-prettier", "seti-prettier", "dev-prettier"], "babel": ["seti-babel", "dev-babel"],
    "jest": ["seti-jest", "dev-jest"], "storybook": ["seti-storybook", "dev-storybook"],
    "kubernetes": "md-kubernetes", "helm": ["dev-helm", "md-ship_wheel"], "terraform": "md-terraform",
    "ansible": "md-ansible", "vagrant": ["md-vagrant", "dev-vagrant"], "prisma": ["seti-prisma", "dev-prisma"],
    "nginx": ["md-nginx", "dev-nginx"], "apache": "dev-apache", "github-actions-workflow": "md-github",
    "firebase": "md-firebase", "astro": ["seti-astro", "dev-astro"], "deno": ["seti-deno", "dev-denojs"],
    "bun": ["seti-bun", "dev-bun"], "elixir": ["seti-elixir", "dev-elixir"], "erlang": "dev-erlang",
    "clojure": "dev-clojure", "scala": "dev-scala", "perl": "dev-perl", "julia": ["seti-julia", "dev-julia"],
    "nim": ["seti-nim", "dev-nim"], "crystal": ["seti-crystal", "dev-crystal"], "dart": "dev-dart",
    "zig": ["seti-zig", "dev-zig"], "ocaml": ["seti-ocaml", "dev-ocaml"], "vim": ["custom-vim", "dev-vim"],
    "emacs": ["custom-emacs", "dev-emacs"], "arduino": ["md-arduino", "dev-arduino"],
    "matlab": ["dev-matlab", "md-math_integral_box"], "unity": "md-unity", "godot": ["seti-godot", "dev-godot"],
    "godot-assets": ["seti-godot", "dev-godot"], "blender": "md-blender", "figma": ["md-figma", "dev-figma"],
    "haskell": "md-language_haskell", "fortran": "md-language_fortran", "lua": "md-language_lua",
    "ruby": "md-language_ruby", "gemfile": "md-language_ruby", "rubocop": "md-language_ruby",
    "r": "md-language_r", "swift": "md-language_swift", "go": "md-language_go", "rust": "md-language_rust",
    "python": "md-language_python", "php": "md-language_php", "nix": "md-nix", "graphql": "md-graphql",
    "android": "md-android", "nodejs": "md-nodejs", "npm": "md-npm", "gitlab": "md-gitlab",
    "bitbucket": "md-bitbucket", "angular": "md-angular", "nuxt": "md-nuxt", "next": ["seti-next", "dev-nextjs"],
    "qt": ["md-qt", "dev-qt"], "cuda": ["md-expansion_card", "md-chip"], "verilog": "md-chip", "vhdl": "md-chip",
    "systemd": ["linux-systemd", "md-cog"], "linux": "md-linux", "apple": "md-apple", "windows": "md-microsoft_windows",
    "raspberry_pi": "md-raspberry_pi", "ubuntu": "md-ubuntu", "debian": "md-debian",
    "virtual": "md-monitor", "command": "md-apple_keyboard_command", "search": "md-magnify",
    "todo": "md-checkbox_marked_outline", "authors": "md-account_group", "contributing": "md-account_multiple_plus",
    "conduct": "md-handshake", "security": "md-shield_lock", "citation": "md-format_quote_close",
    "sublime": "md-text_box_edit", "huff": "md-cube_outline", "webassembly": ["seti-wasm", "dev-wasm"],
    "renovate": "md-update", "dependabot": "md-robot", "travis": "dev-travis", "jenkins": "dev-jenkins",
    "circleci": "dev-circleci", "azure": "md-microsoft_azure", "azure-pipelines": "md-microsoft_azure",
    "aws": "md-aws", "google": "md-google", "gcp": "md-google_cloud", "heroku": "dev-heroku",
    "netlify": "dev-netlify", "vercel": ["dev-vercel", "md-triangle"], "postgresql": ["dev-postgresql", "md-elephant"],
    "mysql": "dev-mysql", "mongodb": "dev-mongodb", "redis": "dev-redis", "sqlite": "dev-sqlite",
    "drawio": "md-chart_box", "mermaid": "md-graph", "plantuml": "md-graph", "postcss": ["seti-postcss", "dev-postcss"],
    "stylelint": ["seti-stylelint", "dev-stylelint"], "husky": "md-dog", "commitlint": "md-check_all",
    "browserlist": "md-web", "nodemon": "md-nodejs", "turborepo": "md-lightning_bolt", "nx": "md-hexagon_multiple",
    "lerna": "md-dragon", "rollup": "md-rollupjs", "swc": "md-lightning_bolt", "esbuild": "md-lightning_bolt",
    "parcel": "md-package_variant", "gulp": "dev-gulp", "grunt": "dev-grunt", "bower": "seti-bower",
    "pug": "seti-pug", "handlebars": "seti-mustache", "ejs": "md-code_braces", "twig": "seti-twig",
    "liquid": "seti-liquid", "coffee": "md-language_coffeescript", "livescript": "seti-livescript",
    "elm": "seti-elm", "purescript": "seti-purescript", "reason": "seti-reasonml", "rescript": "seti-rescript",
    "solidity": ["seti-solidity", "dev-solidity"], "groovy": "dev-groovy", "puppet": "seti-puppet",
    "salt": "md-shaker", "chef": "md-chef_hat", "pulumi": "md-cloud", "bicep": "md-arm_flex",
    "hcl": "md-terraform", "earthly": "md-earth", "just": "md-format_list_checks", "taskfile": "md-format_list_checks",
    "bazel": "dev-bazel", "meson": "md-hammer_wrench", "ninja": "md-ninja", "conan": "md-package_variant",
    "vcpkg": "md-package_variant", "nuget": "md-nuget", "maven": "dev-maven", "sbt": "dev-scala",
    "cabal": "md-language_haskell", "stack": "md-language_haskell", "opam": "seti-ocaml",
    "poetry": "md-language_python", "uv": "md-language_python", "pdm": "md-language_python",
    "conda": "md-language_python", "ruff": "md-language_python", "mypy": "md-language_python",
    "pytest": "md-test_tube", "tox": "md-test_tube", "test-js": "md-test_tube", "test-ts": "md-test_tube",
    "test-jsx": "md-test_tube", "cypress": "md-test_tube", "playwright": "md-test_tube",
    "kivy": "md-language_python", "django": "dev-django", "flask": "dev-flask", "fastapi": "md-lightning_bolt",
    "ipython": "md-language_python", "stan": "md-sigma", "jinja": "seti-jinja", "mojo": "md-fire",
    "gleam": "md-star_four_points", "odin": "md-alpha_o_box", "v": "md-alpha_v_box", "d": "dev-dlang",
    "vala": "md-alpha_v_box", "ada": "md-alpha_a_box", "cobol": "dev-cobol", "lisp": "md-alpha_l_box",
    "racket": "md-alpha_r_box", "scheme": "md-lambda", "prolog": "md-alpha_p_box", "tcl": "md-alpha_t_box",
    "smarty": "md-code_braces", "hack": "md-code_braces", "haxe": "seti-haxe", "applescript": "md-apple",
    "autohotkey": "md-keyboard", "batch": "md-console", "shell": "md-console", "makefile-alt": "md-hammer_wrench",
    "procfile": "md-format_list_numbered", "heroku-procfile": "md-format_list_numbered",
    "graphcool": "md-graphql", "apollo": "md-graphql", "grpc": "md-protocol", "openapi": "md-api",
    "swagger": "md-api", "postman": "md-send", "insomnia": "md-send", "hurl": "md-send", "bruno": "md-send",
    "ollama": "md-robot", "gemini-ai": "md-robot", "claude": "md-robot", "copilot": "md-robot",
    "cursor": "md-cursor_default", "windsurf": "md-surfing", "tabnine": "md-robot",
    "subtitles": "md-subtitles", "stylus": "seti-stylus", "wolframlanguage": "md-math_compass",
    "mathematica": "md-math_compass", "maple": "md-math_compass", "sas": "md-chart_bar",
    "spss": "md-chart_bar", "stata": "md-chart_bar", "rproj": "md-language_r", "quarto": "md-file_document",
    "typst": "md-alpha_t_box", "asciidoc": "md-file_document", "restructuredtext": "md-file_document",
    "org": "md-file_tree", "kdl": "md-code_braces", "nunjucks": "seti-nunjucks", "edge": "md-code_braces",
    "lerna": "md-hexagon_multiple", "coffee": ["dev-coffeescript", "md-coffee"], "bazel": "md-leaf",
    "nuget": "md-package_variant", "cobol": "md-alpha_c_box", "nano-staged": "md-format_list_checks",
    "mdx": "md-language_markdown", "markdownlint": "md-language_markdown", "markdoc": "md-language_markdown",
    "objective-c": "md-language_c", "objective-cpp": "md-language_cpp", "i18n": "md-translate",
    "codeowners": "md-account_group", "pre-commit": "md-check_all", "lintstaged": "md-format_list_checks",
    "lefthook": "md-check_all", "commitizen": "md-check_all", "semantic-release": "md-tag",
    "biome": "md-code_braces", "opentofu": "md-terraform", "shellcheck": "md-console", "hadolint": "md-docker",
    "snakemake": "md-language_python", "snapcraft": "md-ubuntu", "unlicense": "md-license",
    "template": "md-file_document_outline", "hosts": "md-server", "regedit": "md-microsoft_windows",
    "shader": "md-shape", "onnx": "md-brain", "gemini": "md-star_four_points", "fastlane": "md-rocket_launch",
    "mjml": "md-email", "epub": "md-book_open_variant", "excalidraw": "md-draw", "tldraw": "md-draw",
    "lottie": "md-animation", "gnuplot": "md-chart_line", "lilypond": "md-music_clef_treble",
    "chess": "md-chess_knight", "credits": "md-file_document_outline", "installation": "md-file_document_outline",
    "caddy": "md-server", "varnish": "md-cached", "serverless": "md-cloud", "wrangler": "md-cloud",
    "tilt": "md-cloud", "werf": "md-cloud", "xmake": "md-hammer_wrench", "scons": "md-hammer_wrench",
    "buck": "md-hammer_wrench", "tobimake": "md-hammer_wrench", "cue": "md-code_braces",
    "dhall": "md-code_braces", "kcl": "md-code_braces", "pkl": "md-code_braces", "hjson": "md-code_json",
    "pascal": "md-alpha_p_box", "razor": "md-language_csharp", "mercurial": "md-source_branch",
    "architecture": "md-sitemap", "dependencies-update": "md-update", "agent": "md-robot",
    "prompt": "md-robot", "skill": "md-robot", "cline": "md-robot", "opencode": "md-robot",
    "coderabbit-ai": "md-robot", "trigger": "md-lightning_bolt", "rolldown": "md-rollupjs",
    "tsdown": "md-language_typescript", "tsdoc": "md-language_typescript", "typedoc": "md-language_typescript",
    "phpunit": "md-test_tube", "phpstan": "md-language_php", "stryker": "md-test_tube", "wallaby": "md-test_tube",
    "bench-js": "md-timer_outline", "bench-ts": "md-timer_outline", "bench-jsx": "md-timer_outline",
    "pm2-ecosystem": "md-nodejs", "verdaccio": "md-npm", "metro": "md-react", "craco": "md-react",
    "expo": "md-react", "remix": "md-react", "nest": "md-alpha_n_box", "unocss": "md-language_css3",
    "windicss": "md-language_css3", "stitches": "md-language_css3", "vanilla-extract": "md-language_css3",
    "svgo": "md-svg", "svgr": "md-svg", "mint": "md-leaf", "lean": "md-alpha_l_box", "idris": "md-alpha_i_box",
}

# Dossier Material vers glyphe, quand md-folder_<nom> n'existe pas
GLYPHE_DOSSIER = {
    "folder-src": "md-folder_pound", "folder-lib": "md-folder_multiple", "folder-include": "md-folder_information",
    "folder-test": "md-folder_check", "folder-docs": "md-folder_text", "folder-dist": "md-folder_zip",
    "folder-target": "md-folder_marker", "folder-node": "custom-folder_npm", "folder-git": "custom-folder_git",
    "folder-github": "custom-folder_github", "folder-gitlab": "custom-folder_git", "folder-vscode": "md-folder_cog",
    "folder-intellij": "md-folder_cog", "folder-config": "custom-folder_config", "folder-scripts": "md-folder_play",
    "folder-resource": "md-folder_star", "folder-images": "md-folder_image", "folder-public": "md-folder_upload",
    "folder-app": "md-folder_star", "folder-components": "md-folder_multiple", "folder-class": "md-folder_star",
    "folder-database": "md-folder_table", "folder-jupyter": "md-folder_text", "folder-examples": "md-folder_search",
    "folder-tools": "md-folder_wrench", "folder-utils": "md-folder_wrench", "folder-helper": "md-folder_wrench",
    "folder-log": "md-folder_alert", "folder-temp": "md-folder_clock", "folder-desktop": "md-folder_account",
    "folder-audio": "md-folder_music", "folder-video": "md-folder_play", "folder-template": "md-folder_file",
    "folder-migrations": "md-folder_sync", "folder-routes": "md-folder_network", "folder-views": "md-folder_eye",
    "folder-api": "md-folder_network", "folder-server": "md-folder_network", "folder-client": "md-folder_account",
    "folder-meta": "md-folder_information", "folder-font": "md-folder_text", "folder-theme": "md-folder_star",
    "folder-hook": "md-folder_sync", "folder-secure": "md-folder_lock", "folder-private": "md-folder_lock",
    "folder-environment": "md-folder_cog", "folder-plugin": "md-folder_cog", "folder-other": "md-folder_question",
    "folder-archive": "md-folder_zip", "folder-backup": "md-folder_refresh", "folder-update": "md-folder_refresh",
    "folder-upload": "md-folder_upload", "folder-mock": "md-folder_check", "folder-coverage": "md-folder_check",
    "folder-benchmark": "md-folder_clock", "folder-tasks": "md-folder_check", "folder-content": "md-folder_text",
    "folder-markdown": "md-folder_text", "folder-i18n": "md-folder_text", "folder-messages": "md-folder_text",
    "folder-contract": "md-folder_text", "folder-shared": "md-folder_multiple", "folder-packages": "md-folder_multiple",
    "folder-layout": "md-folder_table", "folder-css": "md-folder_star", "folder-sass": "md-folder_star",
    "folder-ci": "md-folder_sync", "folder-gh-workflows": "md-folder_sync", "folder-circleci": "md-folder_sync",
    "folder-pipe": "md-folder_sync", "folder-event": "md-folder_sync", "folder-queue": "md-folder_sync",
    "folder-controller": "md-folder_cog", "folder-middleware": "md-folder_cog", "folder-interceptor": "md-folder_cog",
    "folder-firmware": "md-folder_cog", "folder-kernel": "md-folder_cog", "folder-linux": "md-folder_cog",
    "folder-rust": "md-folder_cog", "folder-python": "md-folder_cog", "folder-docker": "md-folder_cog",
    "folder-android": "md-folder_cog", "folder-ios": "md-folder_cog", "folder-cmake": "md-folder_cog",
    "folder-attachment": "md-folder_file", "folder-dump": "md-folder_zip", "folder-trash": "md-folder_remove",
}

PISTES_AUTO = ("md-language_{}", "md-{}", "dev-{}", "seti-{}", "custom-{}")


def couleur_svg(path):
    """Couleur dominante d'une icône : la plus fréquente parmi les remplissages."""
    txt = open(path, encoding="utf-8").read()
    vals = re.findall(r'fill[=:]\s*"?(#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?)\b', txt)
    vals += re.findall(r'stop-color="(#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?)"', txt)
    vals = [norm(v) for v in vals]
    vals = [v for v in vals if v not in ("#ffffff", "#000000")]
    if not vals:
        return None
    return max(Counter(vals).items(), key=lambda kv: (kv[1], saturation(kv[0])))[0]


def norm(c):
    c = c.lower()
    return "#" + "".join(ch * 2 for ch in c[1:]) if len(c) == 4 else c


def saturation(c):
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return max(r, g, b) - min(r, g, b)


def lisible(c):
    """Éclaircit une couleur trop sombre pour un fond sombre (Catppuccin Mocha)."""
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    if lum >= 0.35:
        return c
    t = min(1.0, (0.35 - lum) / 0.35 + 0.25)
    r, g, b = (round(v + (255 - v) * t * 0.6) for v in (r, g, b))
    return f"#{r:02x}{g:02x}{b:02x}"


# eza distingue la casse, VS Code non : on ajoute seulement les casses qu'on croise vraiment
EXT_DOC = {"", "md", "txt", "rst", "markdown", "adoc", "org"}
TIGES_MAJ = {"cargo", "gemfile", "pipfile", "podfile", "brewfile", "kconfig", "kbuild", "pkgbuild"}


def variantes_fichier(nom):
    if nom.startswith(".") or not nom[0].isalpha():
        return [nom]
    tige, point, ext = nom.partition(".")
    out = [nom]
    if tige.endswith("file") or tige in TIGES_MAJ or not point:
        out.append(nom[0].upper() + nom[1:])
    if ext in EXT_DOC:
        out.append(tige.upper() + point + ext)
    return list(dict.fromkeys(out))


# Dossiers qu'on rencontre vraiment avec un point devant : les autres variantes en "."
# alourdiraient le thème pour rien
DOSSIERS_CACHES = set("""
github gitlab gitea forgejo vscode idea fleet zed husky devcontainer circleci storybook vercel netlify
next nuxt svelte-kit angular expo turbo vitepress vuepress docusaurus changeset changesets cargo rustup
venv virtualenv tox nox pytest_cache mypy_cache ruff_cache ipynb_checkpoints cache config local ssh gnupg
docker aws azure kube terraform vagrant gradle m2 mvn yarn npm pnpm-store nvm bundle rbenv pyenv dart_tool
pub-cache vim nvim emacs.d history trash cursor claude gemini copilot windsurf continue github-actions
""".split())


def variantes_dossier(nom):
    out = [nom]
    if nom in DOSSIERS_CACHES:
        out.append("." + nom)
    if nom[0].isalpha():
        out.append(nom[0].upper() + nom[1:])
    return out


def glyphe(icone, clones, glyphs):
    """Nom du glyphe Nerd Font pour une icône Material, ou None."""
    def premier(pistes):
        return next((p for p in pistes if p in glyphs), None)

    base = clones.get(icone, {}).get("base", icone)
    for n in dict.fromkeys([icone, base]):
        if n in GLYPHE:
            v = GLYPHE[n]
            p = premier(v if isinstance(v, list) else [v])
            if p:
                return p
    if base.startswith("folder-"):
        nom = base[len("folder-"):].replace("-", "_")
        return premier([GLYPHE_DOSSIER.get(base, ""), "md-folder_" + nom, "md-folder"])
    nom = base.replace("-", "_")
    pistes = [p.format(nom) for p in PISTES_AUTO]
    tete = re.split(r"[-_]", base)[0]
    if tete != base and len(tete) > 2:
        pistes += [p.format(tete) for p in ("md-language_{}", "dev-{}", "seti-{}")]
    return premier(pistes)


def main():
    if len(sys.argv) != 5:
        raise SystemExit(__doc__)
    mapping, svgdir, glyphs_path, sortie = sys.argv[1:5]
    m = json.load(open(mapping, encoding="utf-8"))
    glyphs = json.load(open(glyphs_path, encoding="utf-8"))
    clones = m["clones"]

    def car(nom):
        return chr(int(glyphs[nom]["code"], 16))

    def couleur(icone):
        c = clones.get(icone, {}).get("color")
        if c:
            return lisible(norm(c))
        for n in (icone, clones.get(icone, {}).get("base")):
            if n:
                p = os.path.join(svgdir, n + ".svg")
                if os.path.exists(p):
                    c = couleur_svg(p)
                    if c:
                        return lisible(c)
        return None

    cache = {}

    def style(icone):
        if icone not in cache:
            g = glyphe(icone, clones, glyphs)
            cache[icone] = (car(g) if g else None, couleur(icone))
        return cache[icone]

    exts, noms = {}, {}
    sans_couleur = set()

    def poser(cible, cle, icone, cle_manuel):
        if cle_manuel in MANUEL:
            g, c = MANUEL[cle_manuel]
            cible[cle] = (car(g), c)
            return
        g, c = style(icone)
        if c is None:
            sans_couleur.add(icone)
            return
        cible[cle] = (g, c)

    for e, icone in m["ext"].items():
        if "." not in e and e.isprintable():
            poser(exts, e, icone, "ext:" + e)
    for k in MANUEL:
        if k.startswith("ext:") and k[4:] not in exts:
            poser(exts, k[4:], None, k)

    # Dossiers d'abord, puis fichiers : un nom sans point est plutôt un dossier
    for d, icone in m["folders"].items():
        for v in variantes_dossier(d):
            if v not in noms:
                poser(noms, v, icone, "dir:" + v)
    for fr, mat in DOSSIERS_FR.items():
        if mat in m["folders"]:
            poser(noms, fr, m["folders"][mat], "dir:" + fr)
    for f, icone in m["files"].items():
        if "/" in f:
            continue
        for v in variantes_fichier(f):
            if v not in noms or "." in v:
                poser(noms, v, icone, "file:" + v)
    for f in NOMS_CASSES:
        if f.lower() in m["files"]:
            poser(noms, f, m["files"][f.lower()], "file:" + f)
    for k in MANUEL:
        if k.startswith("file:"):
            poser(noms, k[5:], None, k)

    dossier = couleur("folder") or "#90a4ae"

    # Chaque style n'est écrit qu'une fois (ancre &), puis repris par alias * : eza lit le
    # fichier à chaque appel, et moins de texte à analyser le garde rapide
    ancres = {}

    def ligne(k, v):
        g, c = v
        cle = json.dumps(k, ensure_ascii=False)
        if g is None:
            val = f'{{style: {{foreground: "{c}"}}}}'
        else:
            val = f'{{glyph: {json.dumps(g, ensure_ascii=False)}, style: {{foreground: "{c}"}}}}'
        if val in ancres:
            return f"  {cle}: {{icon: *{ancres[val]}}}"
        ancres[val] = f"s{len(ancres)}"
        return f"  {cle}: {{icon: &{ancres[val]} {val}}}"

    out = [
        "# Thème eza façon Material Icon Theme (VS Code)",
        "# Couleurs reprises des icônes Material, glyphes Nerd Fonts (Material Design en priorité).",
        "# Généré automatiquement par eza/build.sh : relancer le générateur plutôt que d'éditer à la main.",
        "",
        "filekinds:",
        f'  directory: {{foreground: "{dossier}", is_bold: true}}',
        "",
        "filenames:",
    ]
    out += [ligne(k, v) for k, v in sorted(noms.items(), key=lambda x: (x[0].lower(), x[0]))]
    out += ["", "extensions:"]
    out += [ligne(k, v) for k, v in sorted(exts.items())]
    open(sortie, "w", encoding="utf-8").write("\n".join(out) + "\n")

    icones = [i for i in cache if i]
    avec = sum(1 for i in icones if cache[i][0])
    print(f"{len(noms)} noms, {len(exts)} extensions ; {len(icones)} icônes Material, "
          f"{avec} avec glyphe, {len(icones) - avec} en couleur seule")
    if sans_couleur:
        print("Ignorées (pas de SVG) :", ", ".join(sorted(sans_couleur)))


if __name__ == "__main__":
    main()
