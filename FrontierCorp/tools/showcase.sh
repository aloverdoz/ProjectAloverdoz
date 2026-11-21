#!/bin/bash
# usage: showcase.sh name "id1,id2,..." [extra args: --cols=5 --pitch=28 --zoom=1]
cd /home/claude/game2
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
n=$1; ids=$2; shift 2
R=${RES:-1280x720}
mkdir -p /tmp/claude-0/shots2
timeout 600 xvfb-run -a -s "-screen 0 ${R}x24" godot --path . --rendering-driver vulkan --resolution $R res://tools/showcase.tscn -- --ids=$ids --shot=/tmp/claude-0/shots2/$n.png "$@" > /tmp/claude-0/sc_$n.log 2>&1
grep -E "SHOWCASE|SCRIPT ERROR|ERROR" /tmp/claude-0/sc_$n.log | head -5
