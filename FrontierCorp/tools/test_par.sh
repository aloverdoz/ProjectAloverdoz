#!/bin/bash
# 1.5: те же проверки, что test_all.sh, но в 4 потока (весь набор по очереди не укладывается в 2 часа).
# Итог — в /tmp/claude-0/par/summary.txt; сетевые и серверные проверки идут после, по одной.
cd ${GAME_DIR:-/home/claude/game2}
D=/tmp/claude-0/par; rm -rf $D; mkdir -p $D
TESTS=$(grep -oP 'for t in \K[^;]+' tools/test_all.sh)
one() {
  t=$1
  timeout 240 godot --headless --path . -- --test=$t > /tmp/claude-0/par/$t.log 2>&1
  r=$(grep -E "^TEST $t " /tmp/claude-0/par/$t.log | head -1)
  e=$(grep -cE "SCRIPT ERROR|Parse Error" /tmp/claude-0/par/$t.log)
  if [ -z "$r" ]; then r="TEST $t NO RESULT (timeout or crash)"; fi
  echo "$r [script_errors=$e]"
}
export -f one
echo $TESTS | tr ' ' '\n' | xargs -P ${P:-4} -I{} bash -c 'one {}' > $D/summary.txt
timeout 120 godot --headless --path . -- --menu-prefs-test 2>&1 | grep -E "^TEST menu_prefs19 " | head -1 >> $D/summary.txt
timeout 300 godot --headless --path . -- --test=bigmap --size=4352 2>&1 | grep -E "^TEST bigmap " | head -1 >> $D/summary.txt
bash tools/test_net.sh 2>&1 | grep -E "TEST" >> $D/summary.txt
bash tools/test_server.sh 2>&1 | grep -E "TEST" >> $D/summary.txt
bash tools/test_admin.sh 2>&1 | grep -E "TEST" >> $D/summary.txt
timeout 200 godot --headless --path . -- --test=split 2>&1 | grep -E "^TEST split " | head -1 >> $D/summary.txt
echo "ALL $(grep -c ' OK' $D/summary.txt) OK / $(grep -vc ' OK' $D/summary.txt) other"
