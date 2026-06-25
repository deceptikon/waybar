#!/usr/bin/env python3
import json, os, re

path = os.path.expanduser("~/.config/waybar/feeds/ssd.json")
if not os.path.exists(path):
    print(json.dumps({"text": "󰋊", "class": "idle"}))
    exit(0)

with open(path) as f:
    data = json.load(f)

text = data.get("text", "")
cls = data.get("class", "good")

nums = re.findall(r'>([\d.]+)\s*([TGM])[bB]?<', text)
def to_gb(val, unit):
    if unit == "T": return val * 1024
    if unit == "M": return val / 1024
    return val

used_gb = to_gb(float(nums[0][0]), nums[0][1]) if len(nums) > 0 else 0
total_gb = to_gb(float(nums[1][0]), nums[1][1]) if len(nums) > 1 else 1000

pct = int(used_gb / total_gb * 100) if total_gb > 0 else 0

# Bar made of SSD icon
icon = "󰋊"
n = 4
fill = round(pct / 100 * n)
bar = '<span fgcolor="#a6e3a1">' + icon * fill + '</span><span fgcolor="#383838">' + icon * (n - fill) + '</span>'

print(json.dumps({"text": bar, "class": cls}))
