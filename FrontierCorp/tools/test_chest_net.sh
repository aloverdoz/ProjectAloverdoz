#!/bin/bash
# 1.1.20: сетевая игра — составное «конструктор + ящик»: гость видит ровный счёт и забирает готовое в рюкзак.
cd ${GAME_DIR:-/home/claude/game2}
P=${PORT:-24715}
timeout 140 godot --headless --path . -- --net_host --no_upnp --port=$P --test=chest_host120_115 --net_dbg > /tmp/claude-0/chest_host.log 2>&1 &
H=$!
sleep 8
timeout 130 godot --headless --path . -- --net_join=192.0.2.2:$P --net_chest_probe --net_dbg > /tmp/claude-0/chest_client.log 2>&1
wait $H
grep -hE "^TEST chest_|SCRIPT ERROR|HUNT" /tmp/claude-0/chest_host.log /tmp/claude-0/chest_client.log | head
