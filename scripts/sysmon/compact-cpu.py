#!/usr/bin/env python3
import json, os, re

path = os.path.expanduser("~/.config/waybar/feeds/cpu.json")
if not os.path.exists(path):
    print(json.dumps({"text": "󰍛", "class": "idle"}))
    exit(0)

with open(path) as f:
    data = json.load(f)

text = data.get("text", "")
cls = data.get("class", "good")

# Extract per-core colors
spans = re.findall(r'<span fgcolor="([^"]+)">([^<]+)</span>', text)
dots = [c for c, ch in spans if ch.strip()]

# 4 rows of 4 cores — icon-based with negative rise to tighten rows
icon = "󰍛"
rows = []
for r in range(4):
    cells = []
    for c in range(4):
        idx = r * 4 + c
        col = dots[idx] if idx < len(dots) else "#383838"
        cells.append(f'<span fgcolor="{col}">{icon}</span>')
    row = "".join(cells)
    rise = f' rise="-2500"' if r > 0 else ""
    rows.append(f'<span{rise}>' + row + '</span>')

out = "\n".join(rows)
print(json.dumps({"text": out, "class": cls}))
