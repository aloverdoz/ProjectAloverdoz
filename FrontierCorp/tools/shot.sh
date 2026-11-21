#!/bin/bash
# usage: shot.sh name frames args...
cd ${GAME:-/home/claude/game2}
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
n=$1; f=$2; shift 2
R=${RES:-1600x900}
timeout ${TO:-600} xvfb-run -a -s "-screen 0 ${R}x24" godot --path . --rendering-driver vulkan --resolution $R -- --frames=$f --shot=/tmp/claude-0/shots2/$n.png "$@" > /tmp/claude-0/shot_$n.log 2>&1
grep -vE "alsa|ALSA|audio|^$" /tmp/claude-0/shot_$n.log | grep -E "SHOT|ERROR|WARN|TEST" -A1 | sort | uniq -c | sort -rn | head -20
