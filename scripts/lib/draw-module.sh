# draw-module.sh — Base template for two-row module info boxes
#
# Provides: draw_module <icon> <row1> <row2> <color_hex> [class]
#
#   icon      Glyph or emoji (e.g. "󰢮"). Rendered larger, on its own line.
#   row1      Primary stat line (rendered in accent color)
#   row2      Secondary stat line (default color)
#   color_hex Accent color e.g. "#fab387"
#   class     Waybar state class: good|medium|warning|critical  (default: good)
#
# Outputs Waybar JSON with Pango text and class.
#
# Usage:
#   source "$(dirname "$0")/lib/draw-module.sh"
#   draw_module "󰢮" "GPU 6%" "MEM 0.5G/15.7G" "#fab387" "good"

draw_module() {
  local icon="$1"
  local row1="$2"
  local row2="$3"
  local color="$4"
  local cls="${5:-good}"

  if [ -n "$icon" ]; then
    text=$(printf "<span fgcolor='%s'><span font_size='xx-large'>%s</span> <span>%s</span>\n<span>%s</span></span>" \
      "$color" "$icon" "$row1" "$row2")
  else
    text=$(printf "<span fgcolor='%s'>%s\n%s</span>" "$color" "$row1" "$row2")
  fi

  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
}
