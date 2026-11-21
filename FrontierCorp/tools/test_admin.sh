#!/bin/bash
# 1.6: управление выделенным сервером из игры. Сервер стартует без мира (как после install_server.sh), игра задаёт пароль
# администратора, создаёт мир со своими настройками (сервер перезапускается по коду 75, как в start_server.sh), заходит в него,
# создаёт второй мир, загружает первый, удаляет второй и останавливает мир.
# SERVER_BIN=путь/к/FrontierCorp_Server.x86_64 — проверить собранный сервер.
cd ${GAME_DIR:-/home/claude/game2}
D=/tmp/claude-0/dadmin
rm -rf $D
mkdir -p $D/updates
printf 'version\t1.7\nnews\tОписание версии\nexe\tFrontierCorp.exe\n' > $D/updates/manifest.txt
cat > $D/server.cfg <<'EOF'
[server]
name="Сервер по умолчанию"
port=24697
lobby=false
public_ip="127.0.0.1"
upnp=false
EOF
if [ -n "$SERVER_BIN" ]; then SRV=("$SERVER_BIN" --headless --); else SRV=(godot --headless --path . --); fi
(
  for i in $(seq 12); do
    timeout 300 "${SRV[@]}" --server --server-config=$D/server.cfg --no_upnp --no_stdin --restart_loop >> $D/server_out.log 2>&1
    RC=$?
    echo "== exit $RC" >> $D/server_out.log
    [ $RC -eq 75 ] || break
  done
) &
S=$!
for i in $(seq 120); do grep -q "Мира пока нет" $D/server_out.log 2>/dev/null && break; sleep 1; done
timeout 600 godot --headless --path . -- --admin_test=127.0.0.1:24697 > $D/client.log 2>&1
echo "stop" > $D/server.cmd
for i in $(seq 60); do kill -0 $S 2>/dev/null || break; sleep 1; done
kill $S 2>/dev/null
R=$(grep -E "^TEST admin16" $D/client.log)
ok=1
echo "$R" | grep -q " OK$" || ok=0
grep -q "SCRIPT ERROR" $D/server_out.log $D/client.log && { grep -m5 -h -A2 "SCRIPT ERROR" $D/server_out.log $D/client.log; ok=0; }
[ -f $D/server_state.json ] || { echo "нет server_state.json"; ok=0; }
[ -f $D/updates/news.txt ] && { echo "news.txt не удалён при сбросе"; ok=0; }
grep -q "abcd1" $D/server_state.json && { echo "пароль хранится открыто"; ok=0; }
# 1.1.14: удалённый мир остаётся копией в saves/backup
ls $D/saves/backup 2>/dev/null | grep -q "_удалён_" || { echo "нет копии удалённого мира в saves/backup"; ls -R $D/saves | head; ok=0; }
N=$(grep -c "== exit 75" $D/server_out.log)
echo "${R:-TEST admin16 NO RESULT} restarts=$N $([ $ok = 1 ] && echo OK || echo FAIL)"
