#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

echo "=== Waybar/Sway Configuration Verification ==="
echo

echo "1. Checking Waybar config JSON..."
config_ok=1
for cfg in config-top config-vertical config-vertical-lite config-bottom; do
  if python3 -m json.tool "$WAYBAR_HOME/$cfg" > /dev/null 2>&1; then
    echo "   ✓ $cfg"
  else
    echo "   ✗ $cfg has errors:"
    python3 -m json.tool "$WAYBAR_HOME/$cfg" 2>&1 | tail -5
    config_ok=0
  fi
done
echo

echo "2. Checking scripts..."
for script in utils/checkupdates.sh utils/lang-monitor.sh utils/shutdown-dmenu.sh; do
  path="$WAYBAR_HOME/scripts/$script"
  if [ -x "$path" ]; then
    echo "   ✓ $script"
  else
    echo "   ✗ $script (missing or not executable)"
  fi
done
echo

echo "3. Checking removed files..."
for file in waybar-ddcutil.py config-right; do
  if [ -f "$WAYBAR_HOME/$file" ]; then
    echo "   ✗ $file still exists (should be removed)"
  else
    echo "   ✓ $file removed"
  fi
done
echo

echo "4. Checking Sway dependencies..."
missing=()
for cmd in nm-applet udiskie dunst wob swaylock swayidle; do
  if command -v "$cmd" >>"$ERRLOG" 2>&1; then
    echo "   ✓ $cmd"
  else
    echo "   ⚠ $cmd (not found)"
    missing+=("$cmd")
  fi
done
echo

echo "5. Optional programs (disabled in config)..."
for cmd in autotiling gammastep poweralertd libinput-gestures ydotoold polkit-gnome-authentication-agent-1; do
  if command -v "$cmd" >>"$ERRLOG" 2>&1; then
    echo "   ✓ $cmd (available, currently disabled)"
  else
    echo "   ✗ $cmd (not installed)"
  fi
done
echo

echo "=== Summary ==="
if [ ${#missing[@]} -eq 0 ]; then
  echo "✓ All required programs found"
else
  echo "⚠ Missing required programs: ${missing[*]}"
  echo "  Install with: yay -S ${missing[*]}"
fi
echo
