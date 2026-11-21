#!/bin/bash
# Прогон всех автотестов без окна. Каждый печатает TEST имя ... OK / FAIL.
cd ${GAME_DIR:-/home/claude/game2}
for t in chest120_115 pow120_115 strategy115 hearts115 oremix115 wiredrop115 fix117_115 dep118_115 drag119_115 curves noplace_player gather craft power console wrap save death jump pack roam_spawn attrs droprate unstuck take_put craft_queue power_partial drops_direct gate smart_split split3 merge blocks hotbar saveload2 waves0 ports item_models menus ui_items hero decor aim take_ready wires tiers terrain batch fluids tech batch2 events transport npcs orders economy flow hazards monsters rules mods sieges photo fog maze dungeons npcmem climate events2 glbhero mechstyle rework tutorial fusion fusion2 drones atom reactor bosses starworks steam s15 aimodel s16 winpos purity loot17 doc17 mech17 s18 s19 stations21 upgrade21 belts21 roofs21 physics21 sizes21 quantum21 v13 pad heroes13 hop13 fuse13 rocks13 trees14 ports13 tune13 rush13 lang13 demo13 mod13 pace15 furnace15 tut15 console16 v17 v18 v19 anim110 cardjit v111 admin111 netbld111 repair112 endgame112 autorep114 v1115 fix1115; do
  timeout 120 godot --headless --path . -- --test=$t 2>&1 | grep -E "^TEST $t |SCRIPT ERROR" | head -3
done
timeout 120 godot --headless --path . -- --menu-prefs-test 2>&1 | grep -E "^TEST menu_prefs19 |SCRIPT ERROR" | head -3
timeout 300 godot --headless --path . -- --test=bigmap --size=4352 2>&1 | grep -E "^TEST bigmap |SCRIPT ERROR" | head -3
bash tools/test_net.sh
bash tools/test_server.sh
bash tools/test_admin.sh
bash tools/test_chest_net.sh
timeout 200 godot --headless --path . -- --test=split 2>&1 | grep -E "^TEST split |SCRIPT ERROR" | head -3
