#!/usr/bin/env python3
"""Validate Waybar module references and find unused definitions.

Scans active bar configs, resolves JSONC includes, and reports:
- undefined module references
- module definitions that are never referenced in any active bar
"""

import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Built-in Waybar modules that do not need an explicit definition.
BUILTIN_MODULES = {
    "sway/mode",
    "sway/window",
    "sway/scratchpad",
    "sway/workspaces",
    "sway/workspaces#bottom",
    "clock",
    "clock#date",
    "tray",
    "privacy",
    "network",
    "network#qwi",
    "idle_inhibitor",
    "power-profiles-daemon",
    "backlight",
    "backlight/slider",
    "pulseaudio",
    "pulseaudio/slider",
    "battery",
    "bluetooth",
    "ext/workspaces",
}

BAR_FILES = {
    "bar-top": ("config-top", "bar-top"),
    "bar-top-ext": ("config-top", "bar-top-ext"),
    "bar-vert": ("config-vertical", "bar-vert"),
    "bar-vert-lite": ("config-vertical-lite", "bar-vert-lite"),
    "bar-bottom": ("config-bottom", "bar-bottom"),
}


def strip_jsonc_comments(text: str) -> str:
    """Remove // and /* */ comments while preserving strings."""
    result = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            result.append(c)
            i += 1
            while i < n:
                ch = text[i]
                result.append(ch)
                if ch == "\\" and i + 1 < n:
                    result.append(text[i + 1])
                    i += 2
                    continue
                if ch == '"':
                    i += 1
                    break
                i += 1
        elif c == "/" and i + 1 < n:
            nxt = text[i + 1]
            if nxt == "/":
                while i < n and text[i] != "\n":
                    i += 1
            elif nxt == "*":
                i += 2
                while i < n - 1 and not (text[i] == "*" and text[i + 1] == "/"):
                    i += 1
                i += 2
            else:
                result.append(c)
                i += 1
        else:
            result.append(c)
            i += 1
    return "".join(result)


def load_jsonc(path: Path) -> dict | list:
    text = strip_jsonc_comments(path.read_text())
    return json.loads(text)


def is_module_ref(s) -> bool:
    return isinstance(s, str) and bool(re.match(r"^[A-Za-z0-9_/#:@\-]+$", s))


def collect_refs(obj, refs: set):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ("modules-left", "modules-center", "modules-right", "modules") and isinstance(v, list):
                for item in v:
                    if is_module_ref(item):
                        refs.add(item)
            else:
                collect_refs(v, refs)
    elif isinstance(obj, list):
        for item in obj:
            collect_refs(item, refs)


def resolve_includes_for_obj(obj: dict, base_path: Path, seen: set | None = None) -> dict:
    """Resolve includes for a single bar object and return merged definitions."""
    if seen is None:
        seen = set()
    if not isinstance(obj, dict):
        return {}
    includes = obj.get("include", [])
    if isinstance(includes, str):
        includes = [includes]
    merged = OrderedDict()
    for inc in includes:
        inc_path = base_path.parent / inc
        if not inc_path.exists():
            inc_path = ROOT / inc
        if inc_path.exists() and inc_path.resolve() not in seen:
            seen.add(inc_path.resolve())
            data = load_jsonc(inc_path)
            if isinstance(data, list):
                for item in data:
                    if isinstance(item, dict):
                        merged.update(item)
            elif isinstance(data, dict):
                merged.update(data)
            # Recursively resolve includes from the loaded file.
            merged.update(resolve_includes_for_obj(merged, inc_path, seen))
    merged.update(obj)
    return merged


def main() -> int:
    results = {}
    for bar_name, (path, name) in BAR_FILES.items():
        raw = load_jsonc(ROOT / path)
        if isinstance(raw, list):
            matches = [x for x in raw if x.get("name") == name]
            if not matches:
                print(f"ERROR: bar {bar_name} not found in {path}", file=sys.stderr)
                return 1
            bar_obj = matches[0]
        else:
            bar_obj = raw
        full = resolve_includes_for_obj(bar_obj, ROOT / path)
        refs = set()
        collect_refs(full, refs)
        # Resolve group refs recursively.
        changed = True
        while changed:
            changed = False
            for r in list(refs):
                if r in full and isinstance(full[r], dict):
                    group_refs = set()
                    collect_refs(full[r], group_refs)
                    for gr in group_refs:
                        if is_module_ref(gr) and gr not in refs:
                            refs.add(gr)
                            changed = True
        results[bar_name] = {"refs": refs, "defs": set(full.keys())}

    print("=== Module references per bar ===\n")
    ok = True
    for bar_name, info in results.items():
        undefined = sorted(info["refs"] - info["defs"] - BUILTIN_MODULES)
        print(f"{bar_name}: {len(info['refs'])} refs")
        if undefined:
            print(f"  undefined: {undefined}")
            ok = False
        else:
            print("  all defined")

    all_active_defs = set()
    all_active_refs = set()
    for info in results.values():
        all_active_defs |= info["defs"]
        all_active_refs |= info["refs"]

    module_defs = {k for k in all_active_defs if "/" in k or "#" in k or k.startswith("custom/")}
    unused_in_active = module_defs - all_active_refs - BUILTIN_MODULES
    print("\n=== Module-like definitions in active configs but never referenced ===")
    if unused_in_active:
        for name in sorted(unused_in_active):
            print(f"  {name}")
        ok = False
    else:
        print("  none")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
