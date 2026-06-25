#!/usr/bin/env python3
import json, os, sys, subprocess

try:
    result = subprocess.run(["df", "/"], capture_output=True, text=True, check=True)
    lines = result.stdout.strip().split("\n")
    parts = lines[-1].split()
    pct = int(parts[4].rstrip("%"))
except Exception:
    print(json.dumps({"text": "󰋊", "class": "idle"}))
    sys.exit(0)

icon = "󰋊"
n = 4
fill = round(pct / 100 * n)
bar = '<span fgcolor="#a6e3a1">' + icon * fill + '</span><span fgcolor="#383838">' + icon * (n - fill) + '</span>'

cls = "good"
if pct >= 95: cls = "critical"
elif pct >= 85: cls = "warning"
elif pct >= 70: cls = "medium"

print(json.dumps({"text": bar, "class": cls}))
