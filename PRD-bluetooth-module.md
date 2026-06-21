## Top bar bluetooth module 

#### Problem
BT module always shows same state, not enough actions

#### Goal
Obtain bluetooth module, that keeps base functionality such as BT-on/off, and icon gets updated respectively. Shortly - need waybar bluetooth module functionality, preserving current style.

#### Next actions
Check how native waybar module works, and offer solutions 

Expand this file with your thoughts

### Thoughts & Solutions

**How the Native Waybar Module Works:**
The native Waybar `bluetooth` module uses BlueZ and D-Bus to track the state of the Bluetooth controller and connected devices. It provides different formatting states (e.g., `format`, `format-connected`, `format-off`, `format-disabled`) and exposes variables like `{status}`, `{icon}`, and `{device_alias}`. However, it does not inherently provide quick actions to toggle Bluetooth on/off out of the box—you have to define click actions.

**Current Setup Observation:**
In `modules-hardware-group.json`, the `bluetooth` and `bluetooth#lite` modules currently only map `"on-click": "blueman-manager"`. This is why there are "not enough actions" and it might feel like it always shows the same state if the quick toggles are missing.

**Solutions to Achieve the Goal:**

1. **Enhance Native Module with `rfkill` Toggles:**
   Keep the native Waybar `bluetooth` module (to preserve style and native state tracking) but add additional click actions for toggling power and opening a menu.
   *Example config update:*
   ```jsonc
   "bluetooth": {
     // ... existing format config ...
     "on-click": "blueman-manager", // Left click opens full GUI
     "on-click-right": "rfkill toggle bluetooth" // Right click toggles BT on/off
   }
   ```

2. **Integrate a Lightweight Menu (e.g., `rofi-bluetooth`):**
   Instead of opening the heavy `blueman-manager` UI, bind `"on-click"` to a lightweight Rofi-based Bluetooth menu. This provides quick actions (connect/disconnect/toggle) directly in a quick-menu format without losing the native Waybar icon styling.

3. **Custom Module Fallback (`custom/bluetooth`):**
   If the native module's state updates are unreliable (sometimes D-Bus signals delay), we can pivot to a `custom/bluetooth` module using the existing `scripts/utils/bt-indicator.sh`. We can expand this script to handle `return-type: "json"` and map `on-click` to custom actions.

**Recommendation:** 
Proceed with **Solution 1** first, as it is the simplest and directly leverages the native module's ability to seamlessly update icons while adding the missing "BT-on/off" functionality via a right-click.
