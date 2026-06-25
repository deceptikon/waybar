#!/usr/bin/env python3
import json, os, sys

path = "/tmp/sysmon.json"
if not os.path.exists(path):
    print(json.dumps({"text": "", "class": "idle"}))
    sys.exit(0)

with open(path) as f:
    data = json.load(f)

ram = data.get("ram", {})
used_kb = ram.get("used_kb", 0)
total_kb = ram.get("total_kb", 1)
pct = int(used_kb / total_kb * 100) if total_kb > 0 else 0

icon = ""
n = 4
fill = round(pct / 100 * n)

row1 = '<span fgcolor="#89b4fa">' + icon * fill + '</span><span fgcolor="#383838">' + icon * (n - fill) + '</span>'
row2 = '<span fgcolor="#383838">' + icon * fill + '</span><span fgcolor="#89b4fa">' + icon * (n - fill) + '</span>'

out = '<span line_height="0.65">' + f"{row1}\n{row2}" + '</span>'

cls = "good"
if pct >= 90: cls = "critical"
elif pct >= 75: cls = "warning"
elif pct >= 50: cls = "medium"

print(json.dumps({"text": out, "class": cls}))
