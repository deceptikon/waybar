#!/usr/bin/env python3
import json, os, sys

path = "/tmp/sysmon.json"
if not os.path.exists(path):
    print(json.dumps({"text": "󰾲", "class": "idle"}))
    sys.exit(0)

with open(path) as f:
    data = json.load(f)

pct = data.get("gpu", {}).get("busy_pct", 0)
n = 4
fill = round(pct / 100 * n)
bar = '<span fgcolor="#fab387">󰾲</span>' * fill + '<span fgcolor="#383838">󰾲</span>' * (n - fill)

cls = "good"
if pct >= 90: cls = "critical"
elif pct >= 70: cls = "warning"
elif pct >= 40: cls = "medium"

print(json.dumps({"text": bar, "class": cls}))
