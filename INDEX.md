# Module Index

## By Definition File

### modules-monitor-group.json
`network#qwi`, `custom/qwen-wifi-info`, `custom/qwen-ssd-icon`, `custom/qwen-ssd-info`, `custom/qwen-cpu-icon`, `custom/qwen-cpu-info`, `custom/qwen-ram-icon`, `custom/qwen-ram-info`, `custom/qwen-temp-icon`, `custom/qwen-temp-info`, `custom/qwen-asus-icon`, `custom/qwen-asus-info`, `group/qwen-network`, `group/qwen-ssd`, `group/qwen-cpu`, `group/qwen-ram`, `group/qwen-temp`, `group/qwen-asus`

### modules-hardware-group.json
`pulseaudio`, `pulseaudio/slider`, `backlight`, `backlight/slider`, `battery`, `network`, `network#lite`, `bluetooth`, `bluetooth#lite`, `group/audio`, `group/bright`

### modules-ux-group.json
`idle_inhibitor`, `power-profiles-daemon`, `custom/dunst`, `custom/recorder`, `custom/checkupdates`, `custom/fnlock`, `custom/backlight`, `custom/ext-display`, `custom/llama`

### Inline in config-top
`sway/workspaces`, `sway/window`, `custom/bt-indicator`, `custom/powerbtn`, `pulseaudio/slider`, `backlight/slider`

### Inline in config-bottom
`sway/workspaces#bottom`, `sway/mode`, `custom/uptime`, `tray`, `custom/ollama`

### Inline in config-vertical
`clock`, `custom/lang`, `privacy`

## Bar Usage

### bar-vert (config-vertical)
| Position | Modules |
|---|---|
| left | `group/qwen-temp`, `group/qwen-asus`, `group/qwen-cpu`, `group/qwen-ram`, `group/qwen-ssd`, `group/qwen-network` |
| center | `clock`, `tray`, `custom/lang`, `privacy` |
| right | `idle_inhibitor`, `power-profiles-daemon`, `custom/dunst`, `custom/recorder`, `custom/checkupdates`, `custom/fnlock`, `custom/backlight`, `custom/ext-display` |

### bar-top (config-top)
| Position | Modules |
|---|---|
| left | `sway/workspaces` |
| center | `sway/window` |
| right | `group/audio`, `group/bright`, `custom/bt-indicator`, `battery`, `custom/powerbtn` |

### bar-bottom (config-bottom)
| Position | Modules |
|---|---|
| left | `sway/workspaces#bottom` |
| center | `sway/mode`, `custom/uptime` |
| right | `tray`, `custom/ollama`, `custom/llama` |
