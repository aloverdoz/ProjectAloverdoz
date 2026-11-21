#!/bin/bash
# usage: run.sh secs args...
cd /home/claude/game2
t=$1; shift
timeout $t godot --headless --path . -- "$@" > /tmp/claude-0/run.log 2>&1
grep -vE "alsa|ALSA|^$|Godot Engine" /tmp/claude-0/run.log | head -40
