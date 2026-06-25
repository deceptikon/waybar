#!/usr/bin/env python3
import json, os, sys

path = "/tmp/sysmon.json"
if not os.path.exists(path):
    print(json.dumps({"text": "󰍛", "class": "idle"}))
    sys.exit(0)

with open(path) as f:
    data = json.load(f)

avg = data.get("cpu", {}).get("avg", 0)
cores = data.get("cpu", {}).get("per_core", [])

def color(pct):
    if pct >= 90: return "#f38ba8"
    if pct >= 70: return "#fab387"
    if pct >= 40: return "#f9e2af"
    if pct >= 15: return "#89b4fa"
    if pct >= 1:  return "#484848"
    return "#383838"

icon = "󰘚"
rows = []
for r in range(4):
    cells = []
    for c in range(4):
        idx = r * 4 + c
        p = cores[idx] if idx < len(cores) else 0
        cells.append(f'<span fgcolor="{color(p)}">{icon}</span>')
    rows.append("".join(cells))

out = '<span line_height="0.65">' + "\n".join(rows) + '</span>'

cls = "good"
if avg >= 90: cls = "critical"
elif avg >= 70: cls = "warning"
elif avg >= 40: cls = "medium"

print(json.dumps({"text": out, "class": cls}))
