# My Waybar Configuration

This is a custom Waybar configuration for Sway WM on ASUS ZenBook laptops.

## Features

- Multi-bar setup (top, side bars)
- Custom modules for system monitoring
- Hardware-specific indicators (CPU, RAM, disk I/O, network)
- Battery and power management
- VPN toggle with status indicator
- Do Not Disturb toggle
- System update checker
- Audio and brightness controls
- Workspace and window title display
- Custom scripts for enhanced functionality

## Installation

1. Clone this repository to `~/.config/waybar`:
   ```bash
   git clone https://github.com/deceptikon/my-waybar-cfg.git ~/.config/waybar
   ```

2. Make sure all scripts are executable:
   ```bash
   chmod +x ~/.config/waybar/scripts/*.sh
   ```

3. Install required dependencies:
   - `waybar` (obviously)
   - `jq` (for JSON processing in scripts)
   - `iostat` (for disk I/O monitoring)
   - `sensors` (lm_sensors for temperature monitoring)
   - `acpi` (for battery information)
   - `upower` (for detailed battery info)
   - `asusctl` (for ASUS profile switching)
   - `wf-recorder` (for screen recording indicator)
   - `ollama` (optional, for AI model monitoring)

4. Reload Waybar to apply the configuration:
   ```bash
   pkill -SIGUSR2 waybar
   ```

## Configuration Files

- `config` - Main bar definitions (3 bars: bar-low, bar-horiz, bar-vert)
- `default-modules.json` - Primary module definitions
- `default-modules-v2.json` - Secondary module definitions
- `style.css` - GTK CSS styling
- `scripts/` - Custom module scripts
- `STRUCT.md` - Module hierarchy documentation

## Custom Scripts

All custom scripts are located in the `scripts/` directory and are self-contained within this repository. No external dependencies outside the repository are required.

## Signals

This configuration uses Waybar signals for dynamic updates:
- SIGRTMIN+3: VPN toggle
- SIGRTMIN+8: Recorder, checkupdates, keyboard backlight
- SIGRTMIN+9: Dunst toggle
- SIGRTMIN+10: ASUS profile switch

## Customization

To customize this configuration for your system:
1. Edit the JSON files to add/remove modules
2. Modify `style.css` for visual changes
3. Adjust script paths if needed (all scripts use relative paths within the config directory)
4. Reload Waybar after changes: `pkill -SIGUSR2 waybar`

## Troubleshooting

If Waybar fails to start:
1. Check for JSON syntax errors: `jq . config && jq . default-modules.json && jq . default-modules-v2.json`
2. Check CSS for errors: `gtk-launch waybar` (watch stderr for warnings)
3. Verify all scripts are executable and have proper dependencies installed