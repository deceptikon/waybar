# draw-module.sh — Base template for two-row module info boxes
#
# Provides: draw_module <row1> <row2> <color_hex> [class]
#
#   row1      Primary stat line (rendered in accent color)
#   row2      Secondary stat line (default color)
#   color_hex Accent color e.g. "#fab387"
#   class     Waybar state class: good|medium|warning|critical  (default: good)
#
# Outputs Waybar JSON with Pango text and class.
#
# Usage:
#   source "$(dirname "$0")/lib/draw-module.sh"
#   draw_module "GPU 6%" "MEM 0.5G/15.7G" "#fab387" "good"

draw_module() {
  local row1="$1"
  local row2="$2"
  local color="$3"
  local cls="${4:-good}"

  text=$(printf "<span fgcolor='%s'>%s</span>\n%s" "$color" "$row1" "$row2")

  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
}
