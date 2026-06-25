#!/usr/bin/env python3
import json, os, re

path = os.path.expanduser("~/.config/waybar/feeds/gpu.json")
if not os.path.exists(path):
    print(json.dumps({"text": "󰾲", "class": "idle"}))
    exit(0)

with open(path) as f:
    data = json.load(f)

text = data.get("text", "")
cls = data.get("class", "good")

m = re.search(r'(\d+)%', text)
pct = int(m.group(1)) if m else 0

# Bar made of GPU icon
n = 4
fill = round(pct / 100 * n)
bar = '<span fgcolor="#fab387">󰾲</span>' * fill + '<span fgcolor="#383838">󰾲</span>' * (n - fill)

print(json.dumps({"text": bar, "class": cls}))
