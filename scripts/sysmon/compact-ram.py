#!/usr/bin/env python3
import json, os, re

path = os.path.expanduser("~/.config/waybar/feeds/ram.json")
if not os.path.exists(path):
    print(json.dumps({"text": "", "class": "idle"}))
    exit(0)

with open(path) as f:
    data = json.load(f)

text = data.get("text", "")
cls = data.get("class", "good")

nums = re.findall(r'> ?([\d.]+)Gb<', text)
used = float(nums[0]) if len(nums) > 0 else 0
free = float(nums[1]) if len(nums) > 1 else 0
total = used + free

pct = int(used / total * 100) if total > 0 else 0

# 2 rows of icon bars
icon = ""
n = 5
fill = round(pct / 100 * n)

row1 = '<span fgcolor="#89b4fa">' + icon * fill + '</span><span fgcolor="#383838">' + icon * (n - fill) + '</span>'
row2 = '<span fgcolor="#383838">' + icon * fill + '</span><span fgcolor="#89b4fa">' + icon * (n - fill) + '</span>'

out = f"{row1}\n{row2}"
print(json.dumps({"text": out, "class": cls}))
