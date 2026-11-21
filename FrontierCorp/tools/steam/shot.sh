#!/bin/bash
# usage: shot.sh name frames args...   (1920x1080 по умолчанию)
cd /home/claude/game2
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
n=$1; f=$2; shift 2
R=${RES:-1920x1080}
timeout 900 xvfb-run -a -s "-screen 0 ${R}x24" godot --path . --rendering-driver vulkan --resolution $R -- --frames=$f --shot=/home/claude/steamwork/shots/$n.png "$@" > /home/claude/steamwork/logs/$n.log 2>&1
echo "$n rc=$? $(ls -la /home/claude/steamwork/shots/$n.png 2>&1 | awk '{print $5}')"
