#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_root="$repo_root/build"
bundle_root="$build_root/web"
game_name="cgw2026_2"
love_path="$build_root/${game_name}.love"
zip_path="$build_root/${game_name}-itch-web.zip"

mkdir -p "$build_root"
rm -rf "$bundle_root"
mkdir -p "$bundle_root/11.5" "$bundle_root/lua"

export REPO_ROOT="$repo_root"
export LOVE_PATH="$love_path"
export BUNDLE_ROOT="$bundle_root"
export ZIP_PATH="$zip_path"

python3 - <<'PYTHON'
import os
import zipfile
from pathlib import Path

repo_root = Path(os.environ["REPO_ROOT"])
love_path = Path(os.environ["LOVE_PATH"])
game_files = [
    "assets",
    "battle.lua",
    "camera.lua",
    "character.lua",
    "conf.lua",
    "effects.lua",
    "lifebar.lua",
    "main.lua",
    "menu.lua",
    "obstacle.lua",
]

def add_path(archive, path):
    if path.is_dir():
        for child in sorted(path.rglob("*")):
            if child.is_file():
                archive.write(child, child.relative_to(repo_root).as_posix())
    else:
        archive.write(path, path.relative_to(repo_root).as_posix())

love_path.unlink(missing_ok=True)
with zipfile.ZipFile(love_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for rel in game_files:
        add_path(archive, repo_root / rel)
PYTHON

cp web/index.html "$bundle_root/index.html"
cp web/lovejs/.htaccess "$bundle_root/.htaccess"
cp web/lovejs/player.js "$bundle_root/player.js"
cp web/lovejs/style.css "$bundle_root/style.css"
cp web/lovejs/nogame.love "$bundle_root/nogame.love"
cp web/lovejs/license.txt "$bundle_root/lovejs-license.txt"
cp web/lovejs/lua/normalize1.lua "$bundle_root/lua/normalize1.lua"
cp web/lovejs/lua/normalize2.lua "$bundle_root/lua/normalize2.lua"
cp web/lovejs/11.5/license.txt "$bundle_root/11.5/license.txt"
cp web/lovejs/11.5/love.js "$bundle_root/11.5/love.js"
cp web/lovejs/11.5/love.wasm "$bundle_root/11.5/love.wasm"
cp "$love_path" "$bundle_root/${game_name}.love"

python3 - <<'PYTHON'
import os
import zipfile
from pathlib import Path

bundle_root = Path(os.environ["BUNDLE_ROOT"])
zip_path = Path(os.environ["ZIP_PATH"])
zip_path.unlink(missing_ok=True)
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(bundle_root.rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(bundle_root).as_posix())
PYTHON

echo "Built: $love_path"
echo "Built: $zip_path"
du -sh "$love_path" "$zip_path"
