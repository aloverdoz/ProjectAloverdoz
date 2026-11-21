#!/bin/bash
cd /home/claude/game2
timeout 200 godot --headless --editor --quit --path . 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A1 | grep -v "^--" | paste - - | sort -u | head -40
