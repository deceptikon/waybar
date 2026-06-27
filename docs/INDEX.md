# Module Index

## By Definition File

### modules-sysmon.json
| Module | Type | Shows | Click |
|---|---|---|---|
| `group/qwen-gpu` | monitor | GPU temp/util/VRAM | gpustat / nvtop |
| `group/qwen-cpu` | monitor | CPU load/freq | htop / gnome-system-monitor |
| `group/qwen-ram` | monitor | RAM usage | gnome-system-monitor / free -h |
| `group/qwen-ssd` | monitor | Disk usage/IO | gnome-disks / lsblk |
| `group/qwen-asus` | hybrid | Fan RPM + profile | cycle asusctl profile |
| `group/qwen-network` | hybrid | SSID + signal + traffic | nm-connection-editor |
| `network#qwi` | indicator | WiFi signal bars | — |
| `custom/qwen-wifi-info` | info | SSID + speeds | nm-connection-editor |
| `custom/qwen-*-icon` | icon | Static glyphs (6 metrics) | — |

### modules-vc.json
| Module | Type | Freq | Shows | Click |
|---|---|---|---|---|
| `power-profiles-daemon` | action | HIGH | icon + profile | cycle profile |
| `idle_inhibitor` | action | HIGH | icon pair | toggle idle inhibit |
| `custom/ext-display` | action | HIGH | icon | toggle external display |
| `custom/checkupdates` | action | MED | icon + count | yay update |
| `custom/ollama` | action | MED | icon + model names | toggle |
| `custom/llama` | action | MED | icon + status | toggle |
| `custom/dunst` | action | LOW | icon | pause/resume |
| `custom/recorder` | action | LOW | icon | toggle wf-recorder |
| `custom/fnlock` | action | LOW | icon | toggle fn-lock |
| `custom/toggle-vert-lite` | action | once | icon | toggle lite bar |

### modules-peripherals.json
| Module | Type | Action |
|---|---|---|
| `group/audio` | slider | mute/volume |
| `group/bright` | slider | brightness |
| `group/bright-external` | slider | DDC brightness |
| `custom/keylight` | action | toggle keyboard backlight |
| `custom/ddc` | slider | DDC brightness text |
| `battery` | indicator | shows charge |
| `bluetooth#lite` | indicator/action | toggle BT / blueman |
| `custom/powerbtn` | action | power menu |

### modules-top-shared.json
| Module | Type | Zone |
|---|---|---|
| `clock#date` | indicator | center |
| `sway/workspaces` | nav | left |
| `sway/window` | indicator | center |
| `sway/scratchpad` | indicator | center |
| `privacy` | indicator | center |
| `sway/mode` | indicator | center |
| `group/titlebox-row` | group | center |

## Bar Layouts

### bar-top (eDP-1)
| Zone | Modules |
|---|---|
| left | `custom/powerbtn`, `bluetooth#lite`, `group/audio` |
| center | `clock#date`, `sway/mode`, `group/titlebox-row` (sway/window + scratchpad + privacy) |
| right | `group/bright`, `custom/keylight`, `battery`, `custom/toggle-vert-lite`, `custom/powerbtn` |

### bar-top (HDMI-A-1)
| Zone | Modules |
|---|---|
| left | `custom/powerbtn`, `bluetooth#lite`, `group/audio` |
| center | (same as eDP-1) |
| right | `group/bright-external`, `custom/keylight`, `battery` |

### bar-vert (right, config-vertical)
| Zone | Modules |
|---|---|
| left | `group/qwen-gpu`, `group/qwen-cpu`, `group/qwen-ram`, `group/qwen-ssd`, `group/qwen-asus`, `group/qwen-network` |
| center | `custom/lang`, `power-profiles-daemon`, `custom/ext-display`, `idle_inhibitor` |
| right | `custom/ollama`, `custom/llama`, `custom/checkupdates`, `custom/dunst`, `custom/recorder`, `custom/fnlock` |

### bar-vert-lite (right, hidden, config-vertical-lite)
| Zone | Modules |
|---|---|
| left | `custom/compact-gpu`, `custom/compact-cpu`, `custom/compact-ram`, `custom/compact-ssd` |
| center | `custom/lang`, `idle_inhibitor` |
| right | `custom/dunst`, `custom/recorder`, `custom/fnlock` |

### bar-bottom
| Zone | Modules |
|---|---|
| left | `sway/workspaces#bottom` |
| center | `custom/powerbtn`, `custom/uptime` |
| right | `custom/ollama`, `tray` |
