#!/bin/bash
# Сборка Steam-версии: экспорт пресета «Steam (Windows)» (exe + pck отдельно),
# затем иконка и сведения о версии вписываются в exe (Godot 4.3 без rcedit этого не делает).
# usage: tools/steam/build_steam.sh OUT_DIR [VERSION]   (нужен node и npm-пакеты resedit, pe-library)
set -e
cd /home/claude/game2
OUT=${1:-export/Steam/windows}; VER=${2:-1.0.0.0}
rm -rf "$OUT"; mkdir -p "$OUT"
godot --headless --path . --export-release "Steam (Windows)" "$OUT/FrontierCorp.exe"
ND=/home/claude/steamwork/node
if [ ! -d $ND/node_modules/resedit ]; then mkdir -p $ND && (cd $ND && npm init -y >/dev/null && npm install resedit@2 pe-library >/dev/null); fi
cp tools/steam/patch_exe.mjs $ND/
node $ND/patch_exe.mjs "$OUT/FrontierCorp.exe" "$OUT/FrontierCorp.tmp.exe" game.ico "$VER"
mv "$OUT/FrontierCorp.tmp.exe" "$OUT/FrontierCorp.exe"
ls -la "$OUT"
