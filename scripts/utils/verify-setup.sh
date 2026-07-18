#!/bin/bash

echo "=== Waybar/Sway Configuration Verification ==="
echo

# Check JSON validity
echo "1. Checking Waybar config JSON..."
if python3 -m json.tool ~/.config/waybar/config > /dev/null 2>&1; then
  echo "   ✓ JSON is valid"
else
  echo "   ✗ JSON has errors:"
  python3 -m json.tool ~/.config/waybar/config 2>&1 | tail -5
fi
echo

# Check scripts
echo "2. Checking scripts..."
for script in checkupdates.sh fan-speed.sh lang-monitor.sh shutdown-dmenu.sh toggleDunst.sh toggle-vpn.sh; do
  path=~/.config/waybar/scripts/$script
  if [ -x "$path" ]; then
    echo "   ✓ $script"
  else
    echo "   ✗ $script (missing or not executable)"
  fi
done
echo

# Check for removed files
echo "3. Checking removed files..."
for file in waybar-ddcutil.py config-right; do
  if [ -f ~/.config/waybar/$file ]; then
    echo "   ✗ $file still exists (should be removed)"
  else
    echo "   ✓ $file removed"
  fi
done
echo

# Check Sway dependencies
echo "4. Checking Sway exec programs..."
missing=()
for cmd in nm-applet udiskie dunst wob swaylock swayidle; do
  if command -v $cmd >>/tmp/waybar_errors.log 2>&1; then
    echo "   ✓ $cmd"
  else
    echo "   ⚠ $cmd (not found)"
    missing+=("$cmd")
  fi
done
echo

# Check optional programs
echo "5. Optional programs (disabled in config)..."
for cmd in autotiling gammastep poweralertd libinput-gestures ydotoold polkit-gnome-authentication-agent-1; do
  if command -v $cmd >>/tmp/waybar_errors.log 2>&1; then
    echo "   ✓ $cmd (available, currently disabled)"
  else
    echo "   ✗ $cmd (not installed)"
  fi
done
echo

# Summary
echo "=== Summary ==="
if [ ${#missing[@]} -eq 0 ]; then
  echo "✓ All required programs found"
else
  echo "⚠ Missing required programs: ${missing[*]}"
  echo "  Install with: yay -S ${missing[*]}"
fi
echo
echo "Backup location: ~/.config/backup_20260108_162957/"
echo "Changes documented in: ~/.config/CHANGES_SUMMARY.md"
