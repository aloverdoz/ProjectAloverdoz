#!/bin/bash
# 1.1.15: сетевая «Стратегия»: хозяин создаёт комнату с режимом без героя, гость входит, выбирает профессию.
cd ${GAME_DIR:-/home/claude/game2}
timeout 120 godot --headless --path . -- --net_host --net_strategy --no_upnp --port=24711 --test=strat_host115 > /tmp/claude-0/strat_host.log 2>&1 &
H=$!
sleep 8
timeout 100 godot --headless --path . -- --net_join=192.0.2.2:24711 --net_strat_probe > /tmp/claude-0/strat_client.log 2>&1
wait $H
grep -hE "^TEST strat_|SCRIPT ERROR" /tmp/claude-0/strat_host.log /tmp/claude-0/strat_client.log | head
