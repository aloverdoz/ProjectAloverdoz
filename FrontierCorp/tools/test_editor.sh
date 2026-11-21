#!/bin/bash
# Автотесты редактора без окна. Пишут во временную игру projects/my_game, потом она удаляется.
cd /home/claude/game2
rm -rf projects/my_game
run() { timeout 200 godot --headless --path . -- --editor --frames=12 "$@" 2>&1 | grep -E "MAPTEST|RIGTEST|GLBTEST|SYNTH dir|UITEST|QATEST|CATTEST|TYPESTEST|FORMBOOL|ED call|SCRIPT ERROR" | head -4; }
run --ed-tab=2 --ed-model=miner --ed-call=sel:2,beautify,duplicate_sel,do_undo
run --ed-tab=2 --ed-call=_test_rig
run --ed-tab=2 --ed-call=_test_glb
rm -rf projects/my_game
run --ed-tab=2 --ed-call=_test_glb --glb=skin
rm -rf projects/my_game
run --ed-tab=3 --ed-call=_test_paint
run --ed-tab=4 --ed-call=_test_synth
run --ed-tab=5 --ed-call=_test_layout,_new_window
rm -rf projects/my_game
run --ed-tab=1 --ed-call=_test_qa
rm -rf projects/my_game
run --ed-tab=1 --ed-call=_test_catalog
rm -rf projects/my_game
run --ed-tab=1 --ed-call=_test_types
ls projects/my_game 2>/dev/null
rm -rf projects/my_game
