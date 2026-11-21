#!/bin/bash
# Сетевая игра: две копии без окна — хозяин и гость на этом же компьютере.
# 16: хозяин создаёт комнату с паролем; гость находит её в списке своей сети, получает отказ на неверный пароль и входит с верным.
# 18: свой сервер объявлений (tools/lobby_server.py) — гость находит комнату и в общем списке «в интернете»; хозяин хранит вещи гостя.
cd ${GAME_DIR:-/home/claude/game2}
python3 tools/lobby_server.py 8099 > /tmp/claude-0/lobby.log 2>&1 &
L=$!
sleep 1
timeout 560 godot --headless --path . -- --net_host --net_room_test --no_upnp --lobby_url=http://127.0.0.1:8099 --lobby_ip=127.0.0.1 --test=net_host > /tmp/claude-0/net_host.log 2>&1 &
H=$!
sleep 8
timeout 480 godot --headless --path . -- --net_find --net_test=client --net_dbg --lobby_url=http://127.0.0.1:8099 --lobby_ip=127.0.0.1 --net_punch --no_stun > /tmp/claude-0/net_client.log 2>&1
wait $H
kill $L 2>/dev/null
grep -E "^TEST net_|^NET find|^PUNCH|SCRIPT ERROR" /tmp/claude-0/net_host.log /tmp/claude-0/net_client.log | head -18
