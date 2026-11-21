#!/bin/bash
# Сборка всех архивов версии (1.5): игра для лаунчера и Steam, демо, редактор, серверы, исходники, лаунчер и обновления.
#   bash tools/build15.sh [ВЕРСИЯ] [ПРЕДЫДУЩИЙ_manifest.txt]
# Результат — в $OUT (по умолчанию /home/claude/out15). Нужны: godot 4.3 + шаблоны, mono (mcs), node (иконка exe), zip.
set -e
cd ${GAME_DIR:-/home/claude/game2}
V=${1:-1.5}
PREV=${2:-}
OUT=${OUT:-/home/claude/out15}
OLD=${OLD:-/mnt/project-files/game-godot/v2}   # прошлые архивы: картинки и тексты Steam, ЧИТАЙ_МЕНЯ редактора
L=/tmp/claude-0/build15
rm -rf "$OUT" $L; mkdir -p "$OUT" $L
step() { echo; echo "== $*"; }

step "Игра (Windows, exe + pck) — для лаунчера и Steam"
bash tools/steam/build_steam.sh export/Steam/windows "$V.0.0" > $L/steam.log 2>&1 || { tail -20 $L/steam.log; exit 1; }
ls -la export/Steam/windows

step "Лаунчер"
mkdir -p export/launcher
mcs -target:winexe -win32icon:game.ico -r:System.Windows.Forms -r:System.Drawing -r:System.IO.Compression \
  -out:export/launcher/FrontierLauncher.exe tools/launcher/FrontierLauncher.cs > $L/launcher.log 2>&1 || { cat $L/launcher.log; exit 1; }
mcs -out:$L/ilscan.exe tools/launcher/ilscan.cs > /dev/null 2>&1 && mono $L/ilscan.exe export/launcher/FrontierLauncher.exe || { echo "Лаунчер использует методы, которых нет на Windows (.NET Framework 4)"; exit 1; }
NEWS=$(cat tools/launcher/news.txt 2>/dev/null | sed ':a;N;$!ba;s/\n/\\n/g')
rm -rf export/updates
mono export/launcher/FrontierLauncher.exe --build "$(pwd)/export/Steam/windows" "$(pwd)/export/updates" "$V" "$NEWS" "$(pwd)/export/launcher/FrontierLauncher.exe" | tail -2
# обновление для сервера: список файлов и куски; если есть прошлый список — только новые куски
mkdir -p $L/upd/updates/chunks $L/upd/updates/launcher
cp export/updates/manifest.txt $L/upd/updates/
cp export/updates/launcher/FrontierLauncher.exe $L/upd/updates/launcher/
if [ -n "$PREV" ] && [ -f "$PREV" ]; then
  grep -P '^chunk\t' "$PREV" | cut -f2 | sort -u > $L/prev.txt
  for f in export/updates/chunks/*.gz; do h=$(basename $f .gz); grep -qx "$h" $L/prev.txt || cp $f $L/upd/updates/chunks/; done
else
  cp export/updates/chunks/*.gz $L/upd/updates/chunks/
fi
(cd $L/upd && zip -q -0 -r "$OUT/FrontierCorp_${V}_Launcher_Updates.zip" updates)
cp export/launcher/FrontierLauncher.exe "$OUT/FrontierLauncher.exe"
cp tools/server_pkg/install_server.sh "$OUT/install_server.sh"
cp tools/launcher/ЛАУНЧЕР_КАК_НАСТРОИТЬ.txt "$OUT/"

step "Steam"
rm -rf $L/steam && mkdir -p $L/steam
(cd $L/steam && unzip -q "$OLD/FrontierCorp_${BASE:-1.6}_Steam.zip")
rm -f $L/steam/steam/ContentBuilder/content/windows/*
cp export/Steam/windows/FrontierCorp.exe export/Steam/windows/FrontierCorp.pck $L/steam/steam/ContentBuilder/content/windows/
(cd $L/steam && zip -q -r "$OUT/FrontierCorp_${V}_Steam.zip" steam)
rm -rf $L/steam

step "Демо"
rm -rf export/Demo && mkdir -p export/Demo
godot --headless --path . --export-release "Демо (Windows)" export/Demo/ProjectAloverdoz_Demo.exe > $L/demo.log 2>&1 || true
[ -s export/Demo/ProjectAloverdoz_Demo.exe ] || { tail -20 $L/demo.log; exit 1; }
(cd export && zip -q -r "$OUT/FrontierCorp_${V}_Demo.zip" Demo)

step "Редактор и движок сборок"
rm -rf export/FrontierEditor && mkdir -p export/FrontierEditor/runtime
godot --headless --path . --export-release "Редактор" export/FrontierEditor/FrontierEditor.exe > $L/editor.log 2>&1 || true
godot --headless --path . --export-release "Игра (движок для сборок)" export/FrontierEditor/runtime/Game.exe > $L/runtime.log 2>&1 || true
[ -s export/FrontierEditor/FrontierEditor.exe ] && [ -s export/FrontierEditor/runtime/Game.exe ] || { tail -20 $L/editor.log $L/runtime.log; exit 1; }
unzip -q -o -j "$OLD/FrontierEditor_${BASE:-1.6}_часть1_редактор.zip" "FrontierEditor/ЧИТАЙ_МЕНЯ.txt" -d export/FrontierEditor/
(cd export && zip -q "$OUT/FrontierEditor_${V}_часть1_редактор.zip" FrontierEditor/FrontierEditor.exe FrontierEditor/ЧИТАЙ_МЕНЯ.txt)
(cd export && zip -q -r "$OUT/FrontierEditor_${V}_часть2_движок_сборок.zip" FrontierEditor/runtime)

step "Серверы"
bash tools/build_server.sh > $L/server.log 2>&1 || { tail -20 $L/server.log; exit 1; }
P=builds/FrontierCorp_Server
rm -rf $L/srv && mkdir -p $L/srv/lin/FrontierCorp_Server $L/srv/win/FrontierCorp_Server
cp $P/ЧИТАЙ_МЕНЯ.txt $P/start_server.sh $P/server.cfg $P/frontiercorp.service $P/FrontierCorp_Server.x86_64 tools/server_pkg/install_server.sh $L/srv/lin/FrontierCorp_Server/
cp $P/ЧИТАЙ_МЕНЯ.txt $P/server.cfg $P/FrontierCorp_Server*.exe $P/start_server.bat $L/srv/win/FrontierCorp_Server/
(cd $L/srv/lin && zip -q -r "$OUT/FrontierCorp_Server_${V}_Linux.zip" FrontierCorp_Server)
(cd $L/srv/win && zip -q -r "$OUT/FrontierCorp_Server_${V}_Windows.zip" FrontierCorp_Server)
rm -rf $L/srv

step "Исходники"
git -c core.quotepath=off ls-files > $L/src.txt
ls .godot/global_script_class_cache.cfg .godot/uid_cache.bin .godot/scene_groups_cache.cfg >> $L/src.txt 2>/dev/null || true
zip -q "$OUT/FrontierCorp_${V}_исходники_часть1_код.zip" -@ < $L/src.txt
ls -d models20/*/ | sort > $L/models.txt
H=$(( $(wc -l < $L/models.txt) / 2 ))
head -n $H $L/models.txt | sed 's#/$##' | xargs zip -q -r "$OUT/FrontierCorp_${V}_исходники_часть2_модели.zip"
tail -n +$((H + 1)) $L/models.txt | sed 's#/$##' | xargs zip -q -r "$OUT/FrontierCorp_${V}_исходники_часть3_модели.zip"
ls models20 | grep -v / | while read f; do [ -f "models20/$f" ] && echo "models20/$f"; done | zip -q "$OUT/FrontierCorp_${V}_исходники_часть2_модели.zip" -@ 2>/dev/null || true

echo
ls -la "$OUT"
du -sh "$OUT"
