# Waybar Modules Structure

## Overview
This document describes the modular structure of Waybar configuration, organized by groups and individual modules.

```yaml
modules:
  - name: bar-horiz
    position: top
    height: 32px
    modules:
      left:
        - group/hardware
        - group/temp-group
        - group/audio
      center:
        - sway/window
        - group/title
      right:
        - group/music
        - group/bright
        - group/switches
        - group/bat-group
        - user
        - tray

  - name: bar-vert
    position: right
    width: 62px
    modules:
      center:
        - sway/workspaces
      left:
        - clock
        - group/title
        - power-profiles-daemon
      right:
        - custom/powerbtn
        - custom/vpn
        - custom/checkupdates
        - idle_inhibitor
        - custom/dunst
        - custom/recorder
        - custom/kbd-auto
        - custom/lang

groups:
  group/switches:
    orientation: horizontal
    modules:
      - bluetooth#lite
      - network#lite

  group/base-switches:
    orientation: horizontal
    modules:
      - bluetooth#lite
      - network#lite

  group/hardware:
    orientation: horizontal
    modules:
      - group/subcpu
      - memory
      - custom/disk-io
      - load

  group/temp-group:
    orientation: horizontal
    modules:
      - group/temperatura
      - custom/fan
      - custom/fan2
      - custom/temp-detailed

  group/temperatura:
    orientation: horizontal
    modules:
      - temperature
      - custom/fanlabel

  group/power:
    orientation: horizontal
    modules:
      - battery
      - custom/asus-profile

  group/bat-group:
    orientation: horizontal
    modules:
      - group/power
      - custom/battery-info
      - custom/acpi-detailed
      - custom/power-draw

  group/subcpu:
    orientation: horizontal
    modules:
      - cpu
      - custom/ram

  group/audio:
    orientation: horizontal
    modules:
      - pulseaudio
      - pulseaudio/slider

  group/bright:
    orientation: horizontal
    modules:
      - backlight
      - backlight/slider

  group/music:
    orientation: horizontal
    modules:
      - mpris#cassette
      - mpris

  tray:
    orientation: horizontal
    modules:
      - tray

  group/title:
    orientation: vertical
    modules:
      - sway/mode
      - privacy

  clock:
    format: " {:%H:%M\n%d.%m.%y}"

  user:
    format: "{user} (up {work_d} days ↑)"

  sway/window:
    format: " {}"

  sway/workspaces:
    orientation: horizontal
    modules:
      - sway/workspaces

  bluetooth:
    format: " {icon} {status}"

  bluetooth#lite:
    format: " {icon} "

  network:
    format: "󰈀 {ifname}"

  network#lite:
    format: " 󰈀 {ifname}"

  cpu:
    format: "  <sub>CPU</sub> {usage}% "

  custom/ram:
    format: "   {} "

  custom/fanlabel:
    format: "   "

   memory:
     format: "free:{avail:0.1f}G used:{used:0.1f}G"

   custom/disk-io:
     format: " 󰋊 <sub>SSD:</sub> {}"

   custom/cpu-indicator:
     format: "{}"
     exec: "~/.config/waybar/scripts/cpu-indicator.sh"
     interval: 2
     return-type: "json"

   custom/ram-indicator:
     format: "{}"
     exec: "~/.config/waybar/scripts/ram-indicator.sh"
     interval: 2
     return-type: "json"

   custom/io-indicator:
     format: "{}"
     exec: "~/.config/waybar/scripts/io-indicator.sh"
     interval: 2
     return-type: "json"

   custom/network-indicator:
     format: "{}"
     exec: "~/.config/waybar/scripts/network-indicator.sh"
     interval: 2
     return-type: "json"

  temperature:
    format: " {icon} {temperatureC}°C "

  custom/fan:
    format: "{}<sub>RPM</sub> "

  custom/fan2:
    format: ": 󰈐 {}<sub>RPM</sub> "

  custom/temp-detailed:
    format: " {} "

  battery:
    format: " {icon} "
    format-charging: "  {icon} "

  custom/battery-info:
    format: " {}"

  custom/acpi-detailed:
    format: "󰚥 {}"

  custom/power-draw:
    format: " {}"

  custom/asus-profile:
    format: " {} "

  pulseaudio:
    format: " {icon}"

  pulseaudio/slider:
    format: "SUSU {}"

  backlight:
    format: " 󰃟"

  backlight/slider:
    format: " {}"

  mpris:
    format: " {status_icon} {dynamic}♫  "

  mpris#cassette:
    format: " 󰧔 <small>{status_icon}</small> {position}"

  custom/powerbtn:
    format: "󰐥"

  custom/vpn:
    format: ""

  custom/checkupdates:
    format: " {}"

  idle_inhibitor:
    format: "{icon}"

  custom/dunst:
    format: " {}"

  custom/recorder:
    format: "{}"

  custom/kbd-auto:
    format: "{}"

  custom/fn_lock:
    exec: "cat /tmp/fn_lock_state"
    return-type: ""
    format: "{}"
    format-icons:
      "0": "󰘶 Fn"
      "1": "󰘶 Media"
    exec-if: "test -f /tmp/fn_lock_state"
    signal: 8
    on-click: "/usr/local/bin/toggle_fn_lock.sh"

  custom/ext-display:
    exec: "~/.config/waybar/scripts/toggle-ext-display.sh refresh"
    return-type: "json"
    format: "{}"
    on-click: "~/.config/waybar/scripts/toggle-ext-display.sh"
    signal: 11
    tooltip: "Toggles external HDMI-A-1 display on/off"

  custom/lang:
    format: "{}"

  custom/asus-profile:
    format: " {} "

  clock:
    format: " {:%H:%M\n%d.%m.%y}"
```